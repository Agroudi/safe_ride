import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:safe_ride/core/firebase/firestore_write.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/route_math.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/data/models/track_session.dart';
import 'package:safe_ride/features/journeys/data/models/tracking_snapshot.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/location_source.dart';
import 'package:safe_ride/features/journeys/data/repository/route_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/track_store.dart';
import 'package:safe_ride/features/journeys/data/repository/tracking_observer.dart';

/// Why [JourneyTracker.start] did or did not record.
enum TrackStart {
  recording,

  /// Not signed in.
  signedOut,

  /// The journey is not in progress (planned, closed, missing).
  notActive,

  /// Location access is missing; nothing was asked.
  noAccess,

  /// Another journey is being recorded — one at a time.
  otherJourney,
}

/// Records the route of the journey in progress — the one service the app
/// keeps for it, so the recording outlives any screen.
///
/// - **Only an active journey**, one at a time, once: a second `start` for
///   the same journey continues the same recording. It stops by itself when
///   the journey is completed or cancelled (anywhere — it follows the
///   journeys' live query) or the account signs out, and never changes a
///   journey's status itself.
/// - **Every trusted fix is written to the phone first** ([TrackStore]);
///   the account gets them in chunks ([RouteRepository]) every [syncEvery],
///   when a chunk fills, and when the recording stops. Offline, the chunk
///   waits in Firestore's queue and counts as sent once the server has it.
/// - **Recovery:** [recover] resumes a recording the app was closed in the
///   middle of (a new segment: no distance is counted across the gap), and
///   finishes sending recordings of journeys that ended meanwhile.
/// - **One observer** (the potential-incident monitor) is handed every fix,
///   tick and interruption of the recording — the location is subscribed
///   to once, here.
class JourneyTracker {
  JourneyTracker({
    required LocationSource location,
    required TrackStore store,
    required RouteRepository route,
    required JourneyRepository journeys,
    required SessionReader session,
    TrackingObserver? observer,
    String Function(String key)? translate,
    DateTime Function()? clock,
    this.tickEvery = const Duration(seconds: 5),
    this.syncEvery = const Duration(minutes: 2),
  }) : _location = location,
       _observer = observer,
       _store = store,
       _route = route,
       _journeys = journeys,
       _sessionReader = session,
       _translate = translate ?? ((String key) => key.tr()),
       _clock = clock ?? DateTime.now {
    _journeyChanges = journeys.changes.listen((_) => _checkJourney());
    _accountChanges = session.changes.listen((_) => _checkAccount());
  }

  /// No fix for this long means no signal.
  static const Duration signalLost = Duration(seconds: 20);

  /// A speed older than this is shown as the last known one.
  static const Duration speedFresh = Duration(seconds: 10);

  /// No fix for this long starts a new segment.
  static const Duration segmentGap = Duration(minutes: 2);

  /// A fix that adds no point (standing still) saves the session at most
  /// this often: it only moves `lastFixAt`, and fixes come every 2 s.
  static const Duration idleSave = Duration(seconds: 30);

  final LocationSource _location;
  final TrackStore _store;
  final RouteRepository _route;
  final JourneyRepository _journeys;
  final SessionReader _sessionReader;
  final TrackingObserver? _observer;
  final String Function(String key) _translate;
  final DateTime Function() _clock;
  final Duration tickEvery;
  final Duration syncEvery;

  final StreamController<TrackingSnapshot?> _snapshots =
      StreamController<TrackingSnapshot?>.broadcast();
  final SpeedSmoother _smoother = SpeedSmoother();
  late final StreamSubscription<void> _journeyChanges;
  late final StreamSubscription<void> _accountChanges;

  TrackSession? _session;
  StreamSubscription<LocationFix>? _fixes;
  StreamSubscription<bool>? _services;
  Timer? _ticker;
  Future<TrackStart>? _starting;
  String? _startingId;
  Future<void>? _stopping;
  Future<void>? _recovering;
  Future<LocationAccess>? _asking;
  Future<void> _queue = Future<void>.value();
  TrackingSnapshot? _current;
  LocationFix? _lastFix;
  DateTime? _subscribedAt;
  double? _speed;
  DateTime? _speedAt;
  TrackingStatus? _blocked;
  RouteSync _sync = RouteSync.none;
  DateTime? _syncedAt;
  Future<void>? _syncRun;
  bool _inFlight = false;
  DateTime? _savedAt;

  /// Resumed after the app was closed: the next point starts a new segment,
  /// whatever kept arriving before it.
  bool _resumed = false;

  /// The journey being recorded, if any.
  String? get journeyId => _session?.journeyId;

  /// The recording now; null when nothing is recorded.
  TrackingSnapshot? get current => _current;

  Stream<TrackingSnapshot?> get snapshots => _snapshots.stream;

  Future<LocationAccess> access() => _location.access();

  /// The system prompt for location (when the system still shows one) and,
  /// once location is allowed, the one for the recording's notice. A start
  /// waits for both: answering the first resumes the app, and a recording
  /// started then would post its notice before it is allowed — Android
  /// drops it and does not post it again.
  Future<LocationAccess> requestAccess() =>
      _asking ??= _ask().whenComplete(() => _asking = null);

  Future<LocationAccess> _ask() async {
    final LocationAccess access = await _location.requestAccess();
    if (access == LocationAccess.granted) await _location.requestNotices();
    return access;
  }

  Future<void> openAppSettings() => _location.openAppSettings();

  Future<void> openLocationSettings() => _location.openLocationSettings();

  /// Starts — or continues — recording [journeyId]. Never asks for
  /// permission: without it, it returns [TrackStart.noAccess].
  Future<TrackStart> start(String journeyId) async {
    // One at a time; a start for another journey gets its own answer.
    while (_starting != null && _startingId != journeyId) {
      await _starting;
    }
    _startingId = journeyId;
    return _starting ??= _start(journeyId).whenComplete(() => _starting = null);
  }

  Future<TrackStart> _start(String journeyId) async {
    final Future<LocationAccess>? asking = _asking;
    if (asking != null) await asking;
    final TrackSession? now = _session;
    if (now != null && now.journeyId != journeyId) {
      return TrackStart.otherJourney;
    }
    final String? uid = await _uid();
    if (uid == null) return TrackStart.signedOut;
    if (!await _isActive(journeyId)) return TrackStart.notActive;
    if (await _location.access() != LocationAccess.granted) {
      return TrackStart.noAccess;
    }
    if (now != null && _fixes != null) return TrackStart.recording;
    final TrackSession session =
        now ??
        (await _store.session(uid, journeyId))?.copyWith(recording: true) ??
        TrackSession(
          journeyId: journeyId,
          uid: uid,
          recording: true,
          startedAt: _clock().toUtc(),
        );
    await _store.saveSession(session);
    _session = session;
    _resumed = now == null && session.last != null;
    _blocked = null;
    _lastFix = null;
    _smoother.clear();
    _syncedAt ??= _clock();
    _sync = session.pointCount == 0
        ? RouteSync.none
        : session.settled
        ? RouteSync.synced
        : RouteSync.queued;
    _subscribe();
    _ticker ??= Timer.periodic(tickEvery, (_) => tick());
    _observer?.started(
      uid,
      journeyId,
      _clock().toUtc(),
      // Resumed after the app was closed: when tracking last saw a fix.
      lastFixBefore: now == null ? session.lastFixAt : null,
    );
    _emit();
    if (!session.settled) unawaited(sync());
    return TrackStart.recording;
  }

  /// Ends the recording of [journeyId] (the journey ended) and sends what
  /// is left. Its points stay in the account.
  ///
  /// Both the phone's write and the server's confirmation of a closed journey
  /// reach here, so it runs once at a time. A failure here never leaves the
  /// recording looking alive: the file stays, and [recover] finishes it.
  Future<void> stop(String journeyId) =>
      _stopping ??= _stop(journeyId).whenComplete(() => _stopping = null);

  Future<void> _stop(String journeyId) async {
    final TrackSession? now = _session;
    if (now == null || now.journeyId != journeyId) {
      final String? uid = await _uid();
      if (uid == null) return;
      final TrackSession? stored = await _store.session(uid, journeyId);
      if (stored != null) await _finish(stored);
      return;
    }
    await _halt();
    await _queue;
    await _syncRun;
    _observer?.ended(now.uid, journeyId, _clock().toUtc());
    try {
      final TrackSession ended = (_session ?? now).copyWith(
        recording: false,
        stoppedAt: _clock().toUtc(),
      );
      await _store.saveSession(ended);
      _session = ended;
      await sync();
      final TrackSession? last = _session;
      if (last != null && last.settled) {
        await _store.delete(last.uid, last.journeyId);
      }
    } on Object catch (e) {
      debugPrint('Tracking: stop not finished (${e.runtimeType})');
    } finally {
      _clear();
    }
  }

  void _clear() {
    _session = null;
    _resumed = false;
    _speed = null;
    _speedAt = null;
    _current = null;
    _snapshots.add(null);
  }

  /// Resumes the signed-in account's interrupted recording, if its journey
  /// is still in progress; finishes the others.
  Future<void> recover() =>
      _recovering ??= _recover().whenComplete(() => _recovering = null);

  Future<void> _recover() async {
    final String? uid = await _uid();
    if (uid == null) return;
    for (final TrackSession s in await _store.sessions(uid)) {
      if (s.journeyId == _session?.journeyId) continue;
      if (!s.recording) {
        await _finish(s);
        continue;
      }
      final bool? active = await _activeOrUnknown(s.journeyId);
      if (active == null) continue;
      if (active) {
        if (_session == null) await start(s.journeyId);
      } else {
        await _finish(s);
      }
    }
  }

  /// What was recorded for [journeyId]: the phone's copy when it has one,
  /// else the account's.
  Future<RouteSummary?> recorded(String journeyId) async {
    final TrackSession? live = _session;
    if (live != null && live.journeyId == journeyId) return _summary(live);
    final String? uid = await _uid();
    if (uid == null) return null;
    final TrackSession? stored = await _store.session(uid, journeyId);
    if (stored != null) return _summary(stored);
    try {
      return await _route.summary(journeyId);
    } on Object {
      return null;
    }
  }

  /// Refreshes the status (signal lost?) and sends a chunk when it is time.
  /// Runs every [tickEvery] while recording.
  void tick() {
    final TrackSession? s = _session;
    if (s == null) return;
    _observer?.ticked(s.journeyId, _clock().toUtc());
    _emit();
    final DateTime? last = _syncedAt;
    if (last == null || _clock().difference(last) >= syncEvery) {
      unawaited(sync());
    }
  }

  /// Sends what the account does not have yet, one chunk after another.
  /// While a chunk waits offline, nothing more is sent.
  Future<void> sync() {
    if (_inFlight) return Future<void>.value();
    return _syncRun ??= _drain().whenComplete(() => _syncRun = null);
  }

  Future<void> _drain() async {
    while (true) {
      final TrackSession? s = _session;
      if (s == null) return;
      if (s.settled) {
        _setSync(s.pointCount == 0 ? RouteSync.none : RouteSync.synced);
        return;
      }
      if (!await _push(s)) return;
    }
  }

  /// Sends the chunk [s] is up to. True when the server confirmed it.
  Future<bool> _push(TrackSession s) async {
    _syncedAt = _clock();
    final int chunk = s.syncedCount ~/ RouteRepository.chunkSize;
    final int from = chunk * RouteRepository.chunkSize;
    final List<TrackPoint> points;
    try {
      points = await _store.points(
        s.uid,
        s.journeyId,
        from: from,
        limit: RouteRepository.chunkSize,
      );
    } on Object {
      _setSync(RouteSync.failed);
      return false;
    }
    final int upTo = from + points.length;
    final int missing = _missing(s, from, points);
    if (missing > 0) await _dropMissing(s.journeyId, missing);
    final bool closing = !s.recording;
    _setSync(RouteSync.syncing);
    final Future<void> write = _route.upload(
      uid: s.uid,
      journeyId: s.journeyId,
      chunk: chunk,
      points: points,
      summary: _summary(s.copyWith(pointCount: s.pointCount - missing)),
    );
    try {
      if (await settle(write)) {
        await _synced(s.uid, s.journeyId, upTo, closing);
        return true;
      }
    } on Object {
      _setSync(RouteSync.failed);
      return false;
    }
    // Offline: Firestore keeps the chunk and sends it when it can.
    _inFlight = true;
    _setSync(RouteSync.pending);
    unawaited(
      write.then(
        (_) async {
          _inFlight = false;
          await _synced(s.uid, s.journeyId, upTo, closing);
          await sync();
        },
        onError: (Object _) {
          _inFlight = false;
          _setSync(RouteSync.failed);
        },
      ),
    );
    return false;
  }

  /// Points [s] counts that the file no longer holds: a line a crash cut
  /// short can never be read. Left counted, the recording could never be
  /// fully sent, and would be sent again forever.
  static int _missing(TrackSession s, int from, List<TrackPoint> points) =>
      points.length < RouteRepository.chunkSize
      ? math.max(0, s.pointCount - from - points.length)
      : 0;

  Future<void> _dropMissing(String journeyId, int missing) => _serial(() async {
    final TrackSession? live = _session;
    if (live == null || live.journeyId != journeyId) return;
    final TrackSession fixed = live.copyWith(
      pointCount: live.pointCount - missing,
    );
    _session = fixed;
    await _store.saveSession(fixed);
  });

  /// The account has the points before [upTo] (and the final summary when
  /// [closing]).
  Future<void> _synced(String uid, String journeyId, int upTo, bool closing) =>
      _serial(() async {
        final TrackSession? live = _session;
        final bool isLive = live != null && live.journeyId == journeyId;
        final TrackSession? s = isLive
            ? live
            : await _store.session(uid, journeyId);
        if (s == null) return;
        final TrackSession done = s.copyWith(
          syncedCount: math.max(s.syncedCount, upTo),
          finalSynced: s.finalSynced || closing,
        );
        if (isLive) {
          _session = done;
          await _store.saveSession(done);
          if (done.settled) _setSync(RouteSync.synced);
        } else if (done.settled && !done.recording) {
          await _store.delete(uid, journeyId);
        } else {
          await _store.saveSession(done);
        }
      });

  /// Marks a stored recording ended and sends what is left of it, then
  /// forgets the phone's copy once the account has all of it.
  Future<void> _finish(TrackSession stored) async {
    _observer?.ended(stored.uid, stored.journeyId, _clock().toUtc());
    TrackSession s = stored.recording
        ? stored.copyWith(recording: false, stoppedAt: _clock().toUtc())
        : stored;
    if (stored.recording) await _store.saveSession(s);
    while (!s.settled) {
      final int from =
          (s.syncedCount ~/ RouteRepository.chunkSize) *
          RouteRepository.chunkSize;
      final List<TrackPoint> points = await _store.points(
        s.uid,
        s.journeyId,
        from: from,
        limit: RouteRepository.chunkSize,
      );
      s = s.copyWith(pointCount: s.pointCount - _missing(s, from, points));
      try {
        final bool confirmed = await settle(
          _route.upload(
            uid: s.uid,
            journeyId: s.journeyId,
            chunk: from ~/ RouteRepository.chunkSize,
            points: points,
            summary: _summary(s),
          ),
        );
        if (!confirmed) return;
      } on Object {
        return;
      }
      s = s.copyWith(syncedCount: from + points.length, finalSynced: true);
      await _store.saveSession(s);
    }
    await _store.delete(s.uid, s.journeyId);
  }

  void _subscribe() {
    _subscribedAt = _clock();
    _fixes = _location
        .fixes(
          title: _translate('journeys.tracking.notice.title'),
          text: _translate('journeys.tracking.notice.text'),
        )
        .listen(
          (LocationFix fix) => _serial(() => _record(fix)),
          onError: _lost,
        );
    _services ??= _location.serviceChanges.listen((bool on) {
      if (_session == null) return;
      if (!on) {
        _blocked = TrackingStatus.locationOff;
        _observer?.interrupted(
          _session!.journeyId,
          InterruptionCause.locationServicesOff,
          _clock().toUtc(),
        );
        _emit();
      } else if (_fixes == null) {
        unawaited(start(_session!.journeyId));
      }
      // Not every phone can report it; the fixes still tell.
    }, onError: (Object _) {});
  }

  void _lost(Object error) {
    unawaited(_fixes?.cancel());
    _fixes = null;
    final bool off =
        error is LocationSourceError &&
        error.access == LocationAccess.serviceOff;
    _blocked = off
        ? TrackingStatus.locationOff
        : TrackingStatus.permissionRequired;
    final String? journeyId = _session?.journeyId;
    if (journeyId != null) {
      _observer?.interrupted(
        journeyId,
        off
            ? InterruptionCause.locationServicesOff
            : InterruptionCause.permissionRemoved,
        _clock().toUtc(),
      );
    }
    _emit();
  }

  Future<void> _record(LocationFix fix) async {
    final TrackSession? s = _session;
    if (s == null) return;
    _observer?.fixed(s.journeyId, fix, _clock().toUtc());
    _lastFix = fix;
    _blocked = null;
    final double? speed = _smoother.add(fix);
    if (speed != null) {
      _speed = speed;
      _speedAt = fix.at;
    }
    final DateTime? previousFix = s.lastFixAt;
    final bool newSegment =
        s.last != null &&
        (_resumed ||
            previousFix == null ||
            fix.at.difference(previousFix) > segmentGap);
    FixVerdict verdict = RouteFilter.judge(fix, s.last, _clock().toUtc());
    // Across a gap the phone may have travelled far: not a GPS jump.
    if (newSegment && verdict == FixVerdict.jump) verdict = FixVerdict.accepted;
    // A late-arriving old fix never moves this back.
    TrackSession next = s.copyWith(
      lastFixAt: previousFix != null && previousFix.isAfter(fix.at)
          ? previousFix
          : fix.at,
    );
    if (verdict == FixVerdict.accepted) {
      _resumed = false;
      final int segment = newSegment ? s.segment + 1 : s.segment;
      final TrackPoint point = TrackPoint(
        lat: fix.latitude,
        lng: fix.longitude,
        at: fix.at,
        accuracy: fix.accuracy,
        speed: speed,
        segment: segment,
      );
      final TrackPoint? last = s.last;
      final double added = last != null && !newSegment
          ? RouteMath.between(last, point)
          : 0;
      await _store.append(s.uid, s.journeyId, point);
      next = next.copyWith(
        segment: segment,
        last: point,
        pointCount: s.pointCount + 1,
        distanceMeters: s.distanceMeters + added,
      );
      if (_sync == RouteSync.synced || _sync == RouteSync.none) {
        _sync = RouteSync.queued;
      }
    }
    final DateTime now = _clock();
    final DateTime? saved = _savedAt;
    if (verdict == FixVerdict.accepted ||
        saved == null ||
        now.difference(saved) >= idleSave) {
      await _store.saveSession(next);
      _savedAt = now;
    }
    _session = next;
    _emit();
    if (next.pointCount - next.syncedCount >= RouteRepository.chunkSize) {
      unawaited(sync());
    }
  }

  TrackingStatus _status(DateTime now) {
    final TrackingStatus? blocked = _blocked;
    if (blocked != null) return blocked;
    final LocationFix? fix = _lastFix;
    if (fix == null) {
      final DateTime? since = _subscribedAt;
      return since != null && now.difference(since) > signalLost
          ? TrackingStatus.noSignal
          : TrackingStatus.starting;
    }
    if (now.difference(fix.at) > signalLost) return TrackingStatus.noSignal;
    return fix.accuracy <= 0 || fix.accuracy > RouteFilter.weakAccuracy
        ? TrackingStatus.weakSignal
        : TrackingStatus.active;
  }

  SpeedReading _speedReading(DateTime now, TrackingStatus status) {
    final double? speed = _speed;
    final DateTime? at = _speedAt;
    if (speed == null || at == null) return const SpeedReading.unavailable();
    final bool fresh =
        now.difference(at) <= speedFresh &&
        (status == TrackingStatus.active ||
            status == TrackingStatus.weakSignal);
    return fresh
        ? SpeedReading.current(speed, at)
        : SpeedReading.lastKnown(speed, at);
  }

  void _emit() {
    final TrackSession? s = _session;
    if (s == null) return;
    final DateTime now = _clock().toUtc();
    final TrackingStatus status = _status(now);
    _current = TrackingSnapshot(
      journeyId: s.journeyId,
      status: status,
      startedAt: s.startedAt,
      speed: _speedReading(now, status),
      distanceMeters: s.distanceMeters,
      last: s.last,
      sync: _sync,
    );
    _snapshots.add(_current);
  }

  void _setSync(RouteSync sync) {
    if (_sync == sync) return;
    _sync = sync;
    _emit();
  }

  Future<void> _halt() async {
    _ticker?.cancel();
    _ticker = null;
    await _fixes?.cancel();
    _fixes = null;
    await _services?.cancel();
    _services = null;
  }

  /// The recorded journey ended (here or on another phone): stop.
  Future<void> _checkJourney() async {
    final String? id = _session?.journeyId;
    if (id == null) return;
    if (await _activeOrUnknown(id) == false) await stop(id);
  }

  /// Signed out, or another account: pause, keeping the recording for when
  /// its account signs in again.
  Future<void> _checkAccount() async {
    final TrackSession? s = _session;
    if (s == null || await _uid() == s.uid) return;
    await _pause(s);
  }

  /// Stops without finishing: the account is being deleted, and nothing
  /// more may be written for it.
  Future<void> discard() async {
    final TrackSession? s = _session;
    if (s == null) return;
    await _pause(s);
    await _syncRun;
  }

  Future<void> _pause(TrackSession s) async {
    _observer?.paused(s.journeyId);
    await _halt();
    await _queue;
    // A chunk waiting offline stays that account's: Firestore holds it for
    // them, and the next account's route must not wait behind it.
    _inFlight = false;
    _clear();
  }

  Future<bool> _isActive(String journeyId) async =>
      await _activeOrUnknown(journeyId) ?? false;

  /// Whether the journey is in progress; null when it cannot be read now.
  Future<bool?> _activeOrUnknown(String journeyId) async {
    try {
      return (await _journeys.journey(journeyId))?.status ==
          JourneyStatus.active;
    } on JourneyFailure {
      return null;
    }
  }

  Future<String?> _uid() async => (await _sessionReader.signedInUser())?.id;

  Future<void> _serial(Future<void> Function() step) =>
      _queue = _queue.then((_) => step()).catchError((Object _) {});

  RouteSummary _summary(TrackSession s) => RouteSummary(
    distanceMeters: s.distanceMeters,
    pointCount: s.pointCount,
    recording: s.recording,
    firstAt: s.startedAt,
    lastAt: s.last?.at,
  );

  /// Stops listening (tests; the app keeps one tracker for its lifetime).
  Future<void> dispose() async {
    await _halt();
    await _journeyChanges.cancel();
    await _accountChanges.cancel();
    await _snapshots.close();
  }
}
