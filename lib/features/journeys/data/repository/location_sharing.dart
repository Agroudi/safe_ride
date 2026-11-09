import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:safe_ride/core/security/bearer_token.dart';
import 'package:safe_ride/core/account/account_data.dart';
import 'package:safe_ride/core/account/sign_out_step.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/location_share.dart';
import 'package:safe_ride/features/journeys/data/models/route_math.dart';
import 'package:safe_ride/features/journeys/data/models/shared_view.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/data/models/tracking_snapshot.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/data/repository/share_link_check.dart';
import 'package:safe_ride/features/journeys/data/repository/share_repository.dart';

/// Publishes the one active share (docs/location-sharing.md), app-wide, so it
/// outlives any screen.
///
/// - **No GPS of its own.** It reads [JourneyTracker.trustedFixes]; for a
///   location share with no journey it asks the tracker to keep its single
///   subscription open ([JourneyTracker.watch]).
/// - **It only listens.** Nothing in recording, detection or the safety check
///   knows it exists, or waits for it, and a failure here stays here.
/// - **Controlled publishing.** At most one position per [minInterval], only
///   after moving [minMove]; standing still, a confirmation per [heartbeat].
///   One send at a time, and offline only the latest position is kept: nothing
///   is queued, so nothing old can arrive looking new.
/// - **It ends** when stopped, when it expires, when its journey ends, or when
///   the account signs out or goes.
class LocationSharing implements AccountData, SignOutStep {
  LocationSharing({
    required JourneyTracker tracker,
    required ShareRepository shares,
    required JourneyRepository journeys,
    required SessionReader session,
    required ShareLinkCheck links,
    DateTime Function()? clock,
    String Function()? newToken,
    this.tickEvery = const Duration(seconds: 5),
  }) : _tracker = tracker,
       _shares = shares,
       _journeys = journeys,
       _session = session,
       _links = links,
       _clock = clock ?? DateTime.now,
       _newToken = newToken ?? BearerToken.generate {
    _accountChanges = session.changes.listen((_) => _checkAccount());
    _journeyChanges = journeys.changes.listen((_) => _checkJourney());
  }

  /// The shortest time between two positions.
  static const Duration minInterval = Duration(seconds: 15);

  /// Closer than this (metres) to the last position sent is no movement.
  static const double minMove = 10;

  /// Standing still, how often the phone says it still is there.
  static const Duration heartbeat = Duration(seconds: 60);

  /// How often the route is extended.
  static const Duration routeEvery = Duration(seconds: 60);

  /// After a failed send, how long before the next try.
  static const Duration retryAfter = Duration(seconds: 30);

  /// How long a finished journey's link keeps saying so, before it goes.
  static const Duration finishedFor = Duration(minutes: 10);

  /// Points closer together than this (metres) add nothing to a shared route.
  static const double routeSpacing = 25;

  static const int chunkSize = 200;
  static const int maxChunks = 40;

  final JourneyTracker _tracker;
  final ShareRepository _shares;
  final JourneyRepository _journeys;
  final SessionReader _session;
  final ShareLinkCheck _links;
  final DateTime Function() _clock;
  final String Function() _newToken;
  final Duration tickEvery;

  final StreamController<ShareStatus?> _changes =
      StreamController<ShareStatus?>.broadcast();
  late final StreamSubscription<void> _accountChanges;
  late final StreamSubscription<void> _journeyChanges;

  ShareRecord? _share;
  String? _uid;
  StreamSubscription<LocationFix>? _fixes;
  StreamSubscription<TrackingSnapshot?>? _snapshots;
  Timer? _ticker;
  Timer? _finished;
  bool _watching = false;
  bool _busy = false;
  bool _ending = false;
  Future<void>? _recovering;

  LocationFix? _latest;
  TrackPoint? _anchor;
  DateTime? _freshAt;
  SharePosition? _sent;
  DateTime? _sentAt;
  String _tracking = 'waiting';
  DateTime? _retryAt;
  bool _failing = false;
  DateTime? _deliveredAt;

  final List<SharedRoutePoint> _route = <SharedRoutePoint>[];
  int _routeVersion = 0;
  int _firstDirtyChunk = 0;
  bool _routeDirty = false;
  DateTime? _routeAt;
  double? _distance;

  ShareStatus? _status;

  /// The active share; null when nothing is being shared.
  ShareStatus? get current => _status;

  Stream<ShareStatus?> get changes => _changes.stream;

  /// Starts a share. Throws [ShareFailure]. The link it returns has been
  /// proved to work; on any doubt no share is left behind.
  Future<ShareRecord> start({
    required ShareDuration duration,
    JourneyModel? journey,
  }) async {
    final String? uid = (await _session.signedInUser())?.id;
    if (uid == null) throw const ShareFailure(ShareFailureCode.signedOut);
    if (_share != null) {
      throw const ShareFailure(ShareFailureCode.alreadySharing);
    }
    if (journey != null && journey.status != JourneyStatus.active) {
      throw const ShareFailure(ShareFailureCode.notActive);
    }
    if (await _tracker.access() != LocationAccess.granted) {
      throw const ShareFailure(ShareFailureCode.noAccess);
    }
    if (!await _links.viewerReady()) {
      throw const ShareFailure(ShareFailureCode.unavailable);
    }
    final String token = _newToken();
    final ShareRecord record;
    try {
      record = await _shares.create(
        uid: uid,
        token: token,
        kind: journey == null ? ShareKind.location : ShareKind.journey,
        expiresAt: _clock().toUtc().add(duration.length),
        journeyId: journey?.id,
        origin: journey == null ? null : _end(journey, origin: true),
        destination: journey == null ? null : _end(journey, origin: false),
      );
    } on ShareGone {
      throw const ShareFailure(ShareFailureCode.refused);
    }
    if (!await _links.readable(token)) {
      await _quietly(() => _shares.stop(uid, token));
      throw const ShareFailure(ShareFailureCode.unavailable);
    }
    await _attach(record, uid);
    return record;
  }

  static SharedPlace _end(JourneyModel j, {required bool origin}) {
    final String name = origin ? j.origin : j.destination;
    final place = origin ? j.originPlace : j.destinationPlace;
    return SharedPlace(name: name, lat: place?.lat, lng: place?.lng);
  }

  /// The user stopped it. Publishing ends at once; true once the server has
  /// ended the link too, false when that waits for a connection.
  Future<bool> stop() async {
    final ShareRecord? share = _share;
    final String? uid = _uid;
    await _detach();
    if (share == null || uid == null) return true;
    return _shares.stop(uid, share.token);
  }

  /// Picks up this account's share after a restart, and clears what is over.
  /// Signed-in screens start here, as they do for the recording.
  Future<void> recover() =>
      _recovering ??= _recover().whenComplete(() => _recovering = null);

  Future<void> _recover() async {
    final String? uid = (await _session.signedInUser())?.id;
    if (uid == null || _share != null) return;
    final List<ShareRecord> all;
    try {
      all = await _shares.records(uid);
    } on Object catch (e) {
      debugPrint('Sharing: not recovered (${e.runtimeType})');
      return;
    }
    final DateTime now = _clock().toUtc();
    for (final ShareRecord r in all) {
      if (!now.isBefore(r.expiresAt)) {
        await _quietly(() => _shares.stop(uid, r.token));
      } else if (r.kind == ShareKind.journey && !await _active(r.journeyId)) {
        // Finished while the app was closed, or still saying so: it goes.
        final bool saying = r.expiresAt.difference(now) <= finishedFor;
        if (saying) {
          _clearLater(uid, r);
        } else {
          await _quietly(() => _shares.stop(uid, r.token));
        }
      } else if (_share == null) {
        await _attach(r, uid);
      }
    }
  }

  Future<bool> _active(String? journeyId) async {
    if (journeyId == null) return false;
    try {
      return (await _journeys.journey(journeyId))?.status ==
          JourneyStatus.active;
    } on JourneyFailure {
      return true; // Unknown: the recording's own check will tell.
    }
  }

  Future<void> _attach(ShareRecord record, String uid) async {
    _reset();
    _share = record;
    _uid = uid;
    _fixes = _tracker.trustedFixes.listen(_onFix);
    if (record.kind == ShareKind.location) {
      _watching = await _tracker.watch();
    } else {
      _snapshots = _tracker.snapshots.listen(_onSnapshot);
      final String? id = record.journeyId;
      if (id != null) await _seedRoute(id);
    }
    _ticker = Timer.periodic(tickEvery, (_) => tick());
    _emit();
  }

  /// The route so far: the recipient sees the journey, not just its tail.
  Future<void> _seedRoute(String journeyId) async {
    await _tracker.start(journeyId);
    final List<TrackPoint> points = await _tracker.points(journeyId);
    points.forEach(_addPoint);
    final TrackingSnapshot? now = _tracker.current;
    if (now?.journeyId == journeyId) _distance = now?.distanceMeters;
  }

  void _addPoint(TrackPoint p) {
    final SharedRoutePoint? last = _route.isEmpty ? null : _route.last;
    final bool gap = last != null && last.segment != p.segment;
    if (last != null &&
        !gap &&
        RouteMath.distance(last.lat, last.lng, p.lat, p.lng) < routeSpacing) {
      return;
    }
    if (_route.length >= chunkSize * maxChunks) return;
    _firstDirtyChunk = _routeDirty
        ? _firstDirtyChunk
        : _route.length ~/ chunkSize;
    _route.add(
      SharedRoutePoint(
        lat: _rounded(p.lat),
        lng: _rounded(p.lng),
        segment: p.segment,
      ),
    );
    _routeDirty = true;
  }

  /// Five decimals, about a metre: more than a phone's GPS can tell.
  static double _rounded(double v) => (v * 100000).roundToDouble() / 100000;

  void _onSnapshot(TrackingSnapshot? snapshot) {
    if (snapshot == null || snapshot.journeyId != _share?.journeyId) return;
    final TrackPoint? last = snapshot.last;
    if (last != null) _addPoint(last);
    _distance = snapshot.distanceMeters;
  }

  void _onFix(LocationFix fix) {
    final DateTime now = _clock().toUtc();
    switch (RouteFilter.judge(fix, _anchor, now)) {
      case FixVerdict.accepted:
        _anchor = TrackPoint(
          lat: fix.latitude,
          lng: fix.longitude,
          at: fix.at,
          accuracy: fix.accuracy,
        );
        _latest = fix;
        _freshAt = now;
      case FixVerdict.duplicate:
        _freshAt = now;
      case FixVerdict.invalid ||
          FixVerdict.inaccurate ||
          FixVerdict.stale ||
          FixVerdict.jump:
        return;
    }
    tick();
  }

  /// Decides what, if anything, to send now. Runs on every fix and every
  /// [tickEvery].
  void tick() {
    final ShareRecord? share = _share;
    if (share == null || _ending) return;
    final DateTime now = _clock().toUtc();
    if (!now.isBefore(share.expiresAt)) {
      unawaited(_expire(share));
      return;
    }
    _emit();
    if (_busy) return;
    final DateTime? retry = _retryAt;
    if (retry != null && now.isBefore(retry)) return;
    final ShareUpdate? update = _nextUpdate(now);
    if (update != null) unawaited(_send(share, update, now));
  }

  bool _fresh(DateTime now) {
    final DateTime? at = _freshAt;
    return at != null && now.difference(at) <= JourneyTracker.signalLost;
  }

  ShareUpdate? _nextUpdate(DateTime now) {
    final bool routeDue = _routeDirty && _elapsed(_routeAt, now, routeEvery);
    final Map<int, List<SharedRoutePoint>> chunks = routeDue
        ? _dirtyChunks()
        : const <int, List<SharedRoutePoint>>{};
    final int? routeChunks = routeDue ? _chunkCount : null;
    final int? routeVersion = routeDue ? _routeVersion + 1 : null;
    final double? distance = routeDue ? _distance : null;

    if (!_fresh(now)) {
      if (_tracking != 'live' && !routeDue) return null;
      return ShareUpdate(
        tracking: _tracking == 'waiting' ? 'waiting' : 'paused',
        distanceMeters: distance,
        routeChunks: routeChunks,
        routeVersion: routeVersion,
        chunks: chunks,
      );
    }
    final LocationFix? fix = _latest;
    if (fix == null) return null;
    final SharePosition? sent = _sent;
    final bool moved =
        sent == null ||
        RouteMath.distance(sent.lat, sent.lng, fix.latitude, fix.longitude) >=
            minMove;
    final bool due =
        _elapsed(_sentAt, now, minInterval) && (moved || _tracking != 'live');
    final bool stillThere = _elapsed(_sentAt, now, heartbeat);
    if (!due && !stillThere && !routeDue) return null;
    final bool newPosition = (due || stillThere) && moved;
    return ShareUpdate(
      tracking: 'live',
      position: newPosition
          ? SharePosition(
              lat: _rounded(fix.latitude),
              lng: _rounded(fix.longitude),
              accuracy: fix.accuracy,
              fixAt: fix.at,
            )
          : null,
      confirmed: !newPosition && (due || stillThere),
      distanceMeters: _distance,
      routeChunks: routeChunks,
      routeVersion: routeVersion,
      chunks: chunks,
    );
  }

  static bool _elapsed(DateTime? since, DateTime now, Duration wait) =>
      since == null || now.difference(since) >= wait;

  int get _chunkCount => (_route.length + chunkSize - 1) ~/ chunkSize;

  Map<int, List<SharedRoutePoint>> _dirtyChunks() =>
      <int, List<SharedRoutePoint>>{
        for (int c = _firstDirtyChunk; c < _chunkCount; c++)
          c: _route.sublist(
            c * chunkSize,
            (c + 1) * chunkSize > _route.length
                ? _route.length
                : (c + 1) * chunkSize,
          ),
      };

  Future<void> _send(ShareRecord share, ShareUpdate update, DateTime at) async {
    _busy = true;
    try {
      // The account can change between a fix and its send.
      if ((await _session.signedInUser())?.id != _uid) return;
      await _shares.publish(share.token, update);
      if (!identical(_share, share)) return;
      final SharePosition? p = update.position;
      if (p != null) _sent = p;
      if (p != null || update.confirmed) _sentAt = at;
      _tracking = update.tracking;
      if (update.routeVersion != null) {
        _routeVersion = update.routeVersion!;
        _routeAt = at;
        _routeDirty = false;
      }
      _failing = false;
      _retryAt = null;
      if (p != null || update.confirmed) _deliveredAt = _clock().toUtc();
    } on ShareGone {
      if (identical(_share, share)) await _gone(share);
    } on ShareFailure {
      if (identical(_share, share)) {
        _failing = true;
        _retryAt = at.add(retryAfter);
      }
    } on Object catch (e) {
      debugPrint('Sharing: not sent (${e.runtimeType})');
      _failing = true;
      _retryAt = at.add(retryAfter);
    } finally {
      _busy = false;
      if (identical(_share, share)) _emit();
    }
  }

  /// The server says it is over: stopped elsewhere, or expired.
  Future<void> _gone(ShareRecord share) async {
    final String? uid = _uid;
    await _detach();
    if (uid != null) await _quietly(() => _shares.stop(uid, share.token));
  }

  Future<void> _expire(ShareRecord share) async {
    _ending = true;
    await _gone(share);
  }

  /// Its journey ended: the link says so for a little while, without the
  /// final position, then goes.
  Future<void> _checkJourney() async {
    final ShareRecord? share = _share;
    final String? uid = _uid;
    if (share == null || uid == null || share.kind != ShareKind.journey) return;
    if (_ending || await _active(share.journeyId)) return;
    _ending = true;
    final DateTime until = _clock().toUtc().add(finishedFor);
    final DateTime expires = until.isBefore(share.expiresAt)
        ? until
        : share.expiresAt;
    final ShareUpdate last = ShareUpdate(
      tracking: 'ended',
      distanceMeters: _distance,
      routeChunks: _routeDirty ? _chunkCount : null,
      routeVersion: _routeDirty ? _routeVersion + 1 : null,
      chunks: _routeDirty ? _dirtyChunks() : const {},
    );
    await _detach();
    try {
      await _shares.finish(uid, share.token, expiresAt: expires, last: last);
      _clearLater(uid, share.copyWith(expiresAt: expires));
    } on Object {
      // Unreachable or already gone: ending it outright is the safe side.
      await _quietly(() => _shares.stop(uid, share.token));
    }
  }

  void _clearLater(String uid, ShareRecord share) {
    _finished?.cancel();
    final Duration left = share.expiresAt.difference(_clock().toUtc());
    _finished = Timer(left.isNegative ? Duration.zero : left, () {
      unawaited(_quietly(() => _shares.stop(uid, share.token)));
    });
  }

  /// Another account, or none: nothing more is sent, and nothing is touched.
  Future<void> _checkAccount() async {
    final String? owner = _uid;
    if (owner == null) return;
    if ((await _session.signedInUser())?.id != owner) await _detach();
  }

  /// Before signing out, while the account can still end its link.
  @override
  Future<void> beforeSignOut() async {
    final ShareRecord? share = _share;
    final String? uid = _uid;
    await _detach();
    if (share != null && uid != null) {
      await _quietly(() => _shares.stop(uid, share.token));
    }
  }

  /// The account is going: nothing more is sent. Its shares are deleted with
  /// the rest of its data (`FirestoreAccountData`).
  @override
  Future<void> erase(String uid) async {
    _finished?.cancel();
    await _detach();
  }

  Future<void> _detach() async {
    _ticker?.cancel();
    _ticker = null;
    await _fixes?.cancel();
    _fixes = null;
    await _snapshots?.cancel();
    _snapshots = null;
    if (_watching) _tracker.unwatch();
    _watching = false;
    _reset();
    _status = null;
    _changes.add(null);
  }

  void _reset() {
    _share = null;
    _uid = null;
    _ending = false;
    _latest = null;
    _anchor = null;
    _freshAt = null;
    _sent = null;
    _sentAt = null;
    _tracking = 'waiting';
    _retryAt = null;
    _failing = false;
    _deliveredAt = null;
    _route.clear();
    _routeVersion = 0;
    _firstDirtyChunk = 0;
    _routeDirty = false;
    _routeAt = null;
    _distance = null;
  }

  void _emit() {
    final ShareRecord? share = _share;
    if (share == null) return;
    final DateTime now = _clock().toUtc();
    final ShareStatus next = ShareStatus(
      record: share,
      delivery: _failing
          ? ShareDelivery.notReaching
          : !_fresh(now) && _sent != null
          ? ShareDelivery.paused
          : _sent == null
          ? ShareDelivery.waiting
          : ShareDelivery.reaching,
      lastDeliveredAt: _deliveredAt,
    );
    if (next == _status) return;
    _status = next;
    _changes.add(next);
  }

  /// A clean-up that may fail: nothing depends on it, and the rules end the
  /// share at `expiresAt` regardless.
  Future<void> _quietly(Future<void> Function() step) async {
    try {
      await step();
    } on Object catch (e) {
      debugPrint('Sharing: not cleared (${e.runtimeType})');
    }
  }

  /// Stops listening (tests; the app keeps one for its lifetime).
  Future<void> dispose() async {
    _finished?.cancel();
    await _detach();
    await _accountChanges.cancel();
    await _journeyChanges.cancel();
    await _changes.close();
  }
}
