import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/safety/escalation_gate.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/data/repository/geocoding_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/map_tile_provider.dart';
import 'package:safe_ride/features/journeys/data/repository/routing_repository.dart';
import 'package:safe_ride/features/journeys/logic/cubit/route_preview_cubit.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/escalation.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/location_share.dart';
import 'package:safe_ride/features/journeys/data/models/shared_view.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/data/repository/location_sharing.dart';
import 'package:safe_ride/features/journeys/data/repository/share_link_check.dart';
import 'package:safe_ride/features/journeys/data/repository/share_repository.dart';
import 'package:safe_ride/features/journeys/logic/cubit/share_cubit.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/data/models/track_session.dart';
import 'package:safe_ride/features/journeys/data/models/tracking_snapshot.dart';
import 'package:safe_ride/features/journeys/data/repository/escalation_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/escalation_sync.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/location_source.dart';
import 'package:safe_ride/features/journeys/data/repository/route_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_notifications.dart';
import 'package:safe_ride/features/journeys/data/repository/track_store.dart';
import 'package:safe_ride/features/journeys/logic/cubit/escalation_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/safety_notice_cubit.dart';

/// A phone whose permission, services and fixes the test decides.
class FakeLocation implements LocationSource {
  FakeLocation({this.now = LocationAccess.denied, this.afterAsking});

  /// What [access] answers.
  LocationAccess now;

  /// What the system prompt answers (null: unchanged).
  LocationAccess? afterAsking;

  int asked = 0;
  int listens = 0;
  final List<String> opened = <String>[];
  StreamController<LocationFix> fixesController =
      StreamController<LocationFix>.broadcast();
  final StreamController<bool> services = StreamController<bool>.broadcast();

  @override
  Future<LocationAccess> access() async => now;

  /// Holds the system prompt open until completed.
  Completer<void>? prompt;

  @override
  Future<LocationAccess> requestAccess() async {
    asked++;
    await prompt?.future;
    now = afterAsking ?? now;
    return now;
  }

  int noticesAsked = 0;

  @override
  Future<void> requestNotices() async => noticesAsked++;

  String? lastNoticeTitle;

  /// What a one-off reading gives, and how many were asked for.
  LocationFix? oneOff;
  int oneOffs = 0;

  @override
  Future<LocationFix?> current() async {
    oneOffs++;
    return oneOff;
  }

  @override
  Stream<LocationFix> fixes({required String title, required String text}) {
    listens++;
    lastNoticeTitle = title;
    return fixesController.stream;
  }

  @override
  Stream<bool> get serviceChanges => services.stream;

  @override
  Future<void> openAppSettings() async => opened.add('app');

  @override
  Future<void> openLocationSettings() async => opened.add('location');

  void fix(
    double lat,
    double lng, {
    DateTime? at,
    double accuracy = 8,
    double? speed,
  }) => fixesController.add(
    LocationFix(
      latitude: lat,
      longitude: lng,
      at: at ?? DateTime.now().toUtc(),
      accuracy: accuracy,
      speed: speed,
    ),
  );
}

/// [TrackStore] in memory.
class MemoryTrackStore implements TrackStore {
  final Map<String, TrackSession> _sessions = <String, TrackSession>{};
  final Map<String, List<TrackPoint>> _points = <String, List<TrackPoint>>{};

  static String _key(String uid, String id) => '$uid/$id';

  @override
  Future<TrackSession?> session(String uid, String journeyId) async =>
      _sessions[_key(uid, journeyId)];

  @override
  Future<List<TrackSession>> sessions(String uid) async => <TrackSession>[
    for (final TrackSession s in _sessions.values)
      if (s.uid == uid) s,
  ];

  int saves = 0;

  /// Makes saving the session throw: a full disk.
  Object? failure;

  /// Loses the last point, as a line a crash cut short would be.
  void loseLast(String uid, String journeyId) =>
      _points[_key(uid, journeyId)]!.removeLast();

  @override
  Future<void> saveSession(TrackSession session) async {
    final Object? f = failure;
    if (f != null) throw f;
    saves++;
    _sessions[_key(session.uid, session.journeyId)] = session;
  }

  @override
  Future<void> append(String uid, String journeyId, TrackPoint point) async =>
      (_points[_key(uid, journeyId)] ??= <TrackPoint>[]).add(point);

  @override
  Future<List<TrackPoint>> points(
    String uid,
    String journeyId, {
    int from = 0,
    int? limit,
  }) async {
    final List<TrackPoint> all =
        _points[_key(uid, journeyId)] ?? const <TrackPoint>[];
    if (from >= all.length) return const <TrackPoint>[];
    final int end = limit == null
        ? all.length
        : (from + limit).clamp(from, all.length);
    return all.sublist(from, end);
  }

  @override
  Future<void> delete(String uid, String journeyId) async {
    _sessions.remove(_key(uid, journeyId));
    _points.remove(_key(uid, journeyId));
  }

  @override
  Future<void> eraseAccount(String uid) async {
    _sessions.removeWhere((String k, _) => k.startsWith('$uid/'));
    _points.removeWhere((String k, _) => k.startsWith('$uid/'));
  }
}

/// A route repository whose writes the test can hold back (offline) or
/// fail.
class FakeRoute implements RouteRepository {
  final List<({int chunk, int points, RouteSummary summary})> uploads =
      <({int chunk, int points, RouteSummary summary})>[];
  Completer<void>? hold;
  Object? failure;

  @override
  Future<void> upload({
    required String uid,
    required String journeyId,
    required int chunk,
    required List<TrackPoint> points,
    required RouteSummary summary,
  }) async {
    uploads.add((chunk: chunk, points: points.length, summary: summary));
    final Object? f = failure;
    if (f != null) throw f;
    final Completer<void>? wait = hold;
    if (wait != null) await wait.future;
  }

  /// What the account holds of the route.
  List<TrackPoint> stored = <TrackPoint>[];

  @override
  Future<List<TrackPoint>> points(String journeyId) async => stored;

  /// What the account would hold: the last summary sent.
  @override
  Future<RouteSummary?> summary(String journeyId) async =>
      uploads.isEmpty || failure != null ? null : uploads.last.summary;
}

/// [IncidentRepository] in memory.
class MemoryIncidentRepository implements IncidentRepository {
  final List<PotentialIncident> all = <PotentialIncident>[];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<PotentialIncident>> forUser(String uid) async =>
      <PotentialIncident>[
        for (final PotentialIncident i in all)
          if (i.uid == uid) i,
      ];

  @override
  Future<List<PotentialIncident>> forJourney(
    String uid,
    String journeyId,
  ) async => <PotentialIncident>[
    for (final PotentialIncident i in all)
      if (i.uid == uid && i.journeyId == journeyId) i,
  ];

  @override
  Future<void> put(PotentialIncident incident) async {
    final int at = all.indexWhere((PotentialIncident i) => i.id == incident.id);
    if (at == -1) {
      all.add(incident);
    } else {
      all[at] = incident;
    }
    _changes.add(null);
  }

  @override
  Future<void> eraseAccount(String uid) async {
    all.removeWhere((PotentialIncident i) => i.uid == uid);
    _changes.add(null);
  }
}

/// [SafetyCheckRepository] in memory, counting writes.
class MemorySafetyCheckRepository implements SafetyCheckRepository {
  final List<SafetyCheck> all = <SafetyCheck>[];
  int writes = 0;

  /// Makes writing throw: a full disk.
  Object? failure;

  @override
  Future<List<SafetyCheck>> forUser(String uid) async => <SafetyCheck>[
    for (final SafetyCheck c in all)
      if (c.uid == uid) c,
  ];

  @override
  Future<void> put(SafetyCheck check) async {
    final Object? f = failure;
    if (f != null) throw f;
    writes++;
    final int at = all.indexWhere((SafetyCheck c) => c.id == check.id);
    if (at == -1) {
      all.add(check);
    } else {
      all[at] = check;
    }
  }

  @override
  Future<void> eraseAccount(String uid) async =>
      all.removeWhere((SafetyCheck c) => c.uid == uid);
}

/// A phone's notifications, recorded; nothing reaches a real one.
class FakeSafetyNotifications implements SafetyNotifications {
  /// What was posted, in order: the check's id, `noAnswer`, or `clear`.
  final List<String> log = <String>[];

  /// What the system says.
  SafetyNoticeAccess now = SafetyNoticeAccess.allowed;

  /// What the prompt answers (null: unchanged).
  SafetyNoticeAccess? afterAsking;
  int asked = 0;
  int settingsOpened = 0;

  /// Makes every post throw: a phone whose notifications are broken.
  bool broken = false;

  final Map<String, DateTime> inbox = <String, DateTime>{};
  final StreamController<void> _answered = StreamController<void>.broadcast();

  /// A tap on "I'm safe", as the action's isolate reports it.
  void tapSafe(String checkId, DateTime at) {
    inbox[checkId] = at;
    _answered.add(null);
  }

  void _post(String what) {
    if (broken) throw StateError('no notifications');
    log.add(what);
  }

  @override
  Future<void> prepare() async {}

  @override
  Future<bool> asking(SafetyCheck check) async {
    if (now != SafetyNoticeAccess.allowed) return false;
    _post(check.id);
    return true;
  }

  @override
  Future<bool> noAnswer(SafetyCheck check) async {
    if (now != SafetyNoticeAccess.allowed) return false;
    _post('noAnswer');
    return true;
  }

  @override
  Future<void> clear() async => _post('clear');

  @override
  Future<SafetyNoticeAccess> access() async => now;

  @override
  Future<SafetyNoticeAccess> request() async {
    asked++;
    return now = afterAsking ?? now;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Stream<void> get answered => _answered.stream;

  @override
  Future<Map<String, DateTime>> takeAnswers() async {
    final Map<String, DateTime> all = Map<String, DateTime>.of(inbox);
    inbox.clear();
    return all;
  }
}

/// The server, as far as a phone sees it. Writes wait on [hold] (offline);
/// [refused] makes them fail, as the rules would.
class FakeEscalations implements EscalationRepository {
  final List<String> submitted = <String>[];
  final Set<String> onServer = <String>{};
  final StreamController<Escalation?> record =
      StreamController<Escalation?>.broadcast();
  Completer<void>? hold;
  Object? refused;
  bool unreachable = false;

  @override
  Future<void> submit(SafetyCheck check, PotentialIncident incident) async {
    submitted.add(check.id);
    await hold?.future;
    final Object? no = refused;
    if (no != null) throw no;
    onServer.add(check.id);
  }

  @override
  Future<bool> received(String uid, String checkId) async {
    if (unreachable) throw StateError('offline');
    return onServer.contains(checkId);
  }

  @override
  Stream<Escalation?> watch(String uid, String checkId) => record.stream;
}

/// A map with no tiles: nothing reaches a network in a test.
class FakeMapTiles implements MapTileProvider {
  /// Makes the style fail, as with no connection.
  MapFailure? failure;
  final List<bool> asked = <bool>[];

  @override
  final ValueNotifier<bool> reachable = ValueNotifier<bool>(true);

  @override
  String get attribution => '© tiles';

  @override
  Future<Widget> layer({required bool dark, required AppColors colors}) async {
    asked.add(dark);
    final MapFailure? f = failure;
    if (f != null) throw f;
    return SizedBox(key: ValueKey<String>(dark ? 'tiles.dark' : 'tiles.light'));
  }
}

/// Places decided by the test, counting what was asked.
class FakeGeocoding implements GeocodingRepository {
  List<JourneyPlace> results = <JourneyPlace>[];
  JourneyPlace? named;
  MapFailure? failure;
  final List<String> searches = <String>[];
  int reverses = 0;

  /// Holds a search open, to overtake it.
  Completer<void>? hold;
  bool cancelled = false;

  @override
  Future<List<JourneyPlace>> search(
    String query, {
    required String languageCode,
    LatLng? near,
    Future<void>? cancel,
  }) async {
    searches.add(query);
    unawaited(cancel?.then((_) => cancelled = true));
    await hold?.future;
    final MapFailure? f = failure;
    if (f != null) throw f;
    return results;
  }

  @override
  Future<JourneyPlace?> reverse(
    LatLng point, {
    required String languageCode,
  }) async {
    reverses++;
    final MapFailure? f = failure;
    if (f != null) throw f;
    return named;
  }
}

/// Routes decided by the test, counting what was asked.
class FakeRouting implements RoutingRepository {
  PlannedRoute? answer;
  MapFailure failure = const MapFailure(MapFailureCode.unavailable);
  int asked = 0;

  @override
  Future<PlannedRoute> route(LatLng from, LatLng to) async {
    asked++;
    final PlannedRoute? a = answer;
    if (a == null) throw failure;
    return a;
  }
}

/// Registers what a journey screen's safety notes need: nothing unanswered,
/// notifications allowed. And the map's providers, none of them real.
void registerSafetyNotes(SessionReader session) {
  final MemorySafetyCheckRepository checks = MemorySafetyCheckRepository();
  final FakeEscalations server = FakeEscalations();
  final EscalationSync sync = EscalationSync(
    checks: checks,
    incidents: MemoryIncidentRepository(),
    repository: server,
    session: session,
    updates: const Stream<SafetyCheck?>.empty(),
    live: false,
  );
  final FakeRouting routing = FakeRouting();
  sl
    ..registerSingleton<MapTileProvider>(FakeMapTiles())
    ..registerSingleton<RoutingRepository>(routing)
    ..registerFactory<RoutePreviewCubit>(() => RoutePreviewCubit(routing))
    ..registerFactory<EscalationCubit>(
      () => EscalationCubit(checks, server, sync, session),
    )
    ..registerFactory<SafetyNoticeCubit>(
      () => SafetyNoticeCubit(FakeSafetyNotifications()),
    )
    ..registerFactory<ShareCubit>(() {
      final JourneyRepository journeys = FirestoreJourneyRepository(
        FakeFirebaseFirestore(),
        session,
      );
      final JourneyTracker tracker = JourneyTracker(
        location: FakeLocation(now: LocationAccess.granted),
        store: MemoryTrackStore(),
        route: FakeRoute(),
        journeys: journeys,
        session: session,
        translate: (String k) => k,
      );
      return ShareCubit(
        LocationSharing(
          tracker: tracker,
          shares: FakeShares(),
          journeys: journeys,
          session: session,
          links: FakeShareLinks(),
        ),
        tracker,
        journeys,
      );
    });
}

/// [ShareRepository] in memory, writing down what would reach the server.
class FakeShares implements ShareRepository {
  final List<ShareUpdate> published = <ShareUpdate>[];
  final List<ShareUpdate> finished = <ShareUpdate>[];
  final List<String> stopped = <String>[];
  final Map<String, ShareRecord> saved = <String, ShareRecord>{};

  /// Thrown by [publish]; [create] throws [createFailure].
  Object? publishFailure;
  Object? createFailure;
  Object? finishFailure;

  /// What [stop] answers: false is "queued for when the phone is back online".
  bool stopConfirmed = true;
  Object? stopFailure;
  Completer<void>? hold;

  @override
  Future<ShareRecord> create({
    required String uid,
    required String token,
    required ShareKind kind,
    required DateTime expiresAt,
    String? journeyId,
    SharedPlace? origin,
    SharedPlace? destination,
  }) async {
    final Object? f = createFailure;
    if (f != null) throw f;
    final ShareRecord r = ShareRecord(
      token: token,
      kind: kind,
      expiresAt: expiresAt,
      journeyId: journeyId,
    );
    saved[token] = r;
    return r;
  }

  @override
  Future<void> publish(String token, ShareUpdate update) async {
    final Completer<void>? wait = hold;
    if (wait != null) await wait.future;
    final Object? f = publishFailure;
    if (f != null) throw f;
    published.add(update);
  }

  @override
  Future<void> finish(
    String uid,
    String token, {
    required DateTime expiresAt,
    required ShareUpdate last,
  }) async {
    final Object? f = finishFailure;
    if (f != null) throw f;
    finished.add(last);
    saved[token] = saved[token]!.copyWith(expiresAt: expiresAt);
  }

  @override
  Future<bool> stop(String uid, String token) async {
    final Object? f = stopFailure;
    if (f != null) throw f;
    stopped.add(token);
    saved.remove(token);
    return stopConfirmed;
  }

  @override
  Future<List<ShareRecord>> records(String uid) async => saved.values.toList();
}

/// [ShareLinkCheck] that answers what the test decides.
class FakeShareLinks implements ShareLinkCheck {
  bool viewer = true;
  bool public = true;

  @override
  Future<bool> viewerReady() async => viewer;

  @override
  Future<bool> readable(String token) async => public;
}

/// Timers that fire only when the test moves the clock ([advance]).
class FakeTimers {
  FakeTimers(this.now);

  /// The clock the timers are due against.
  DateTime Function() now;
  final List<FakeTimer> _all = <FakeTimer>[];

  int get pending => _all.where((FakeTimer t) => t.isActive).length;

  Timer call(Duration after, void Function() callback) {
    final FakeTimer t = FakeTimer(now().add(after), callback);
    _all.add(t);
    return t;
  }

  /// Fires every active timer due by now.
  void fireDue() {
    for (final FakeTimer t in List<FakeTimer>.of(_all)) {
      if (t.isActive && !t.dueAt.isAfter(now())) t.fire();
    }
  }
}

class FakeTimer implements Timer {
  FakeTimer(this.dueAt, this._callback);

  final DateTime dueAt;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// An escalation lifecycle with nothing open: for screens that only show it.
class NoEscalations implements EscalationGate {
  @override
  Stream<void> get changed => const Stream<void>.empty();

  @override
  Future<OpenEscalation?> latestOpen() async => null;

  @override
  Future<OpenEscalation?> openFor(String journeyId) async => null;

  @override
  Future<ResolveOutcome> resolveSafe(String checkId) async =>
      ResolveOutcome.notOpen;
}
