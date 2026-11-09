import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/security/bearer_token.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/location_share.dart';
import 'package:safe_ride/features/journeys/data/models/shared_view.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/data/repository/location_sharing.dart';
import 'package:safe_ride/features/journeys/data/repository/shared_view_repository.dart';
import 'package:safe_ride/features/journeys/logic/cubit/share_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/shared_view_cubit.dart';

import '../tracking_fakes.dart';

class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      const SessionUser(id: 'sara', fullName: 'Sara');
}

class _FakeView implements SharedViewRepository {
  final StreamController<SharedViewEvent> events =
      StreamController<SharedViewEvent>.broadcast();
  final Map<int, List<SharedRoutePoint>> chunks =
      <int, List<SharedRoutePoint>>{};
  final List<int> asked = <int>[];

  @override
  Stream<SharedViewEvent> watch(String token) => events.stream;

  @override
  Future<List<SharedRoutePoint>> chunk(String token, int chunk) async {
    asked.add(chunk);
    return chunks[chunk] ?? const <SharedRoutePoint>[];
  }
}

void main() {
  group('ShareCubit', () {
    late FakeLocation location;
    late FakeShares shares;
    late FakeShareLinks links;
    late JourneyTracker tracker;
    late LocationSharing sharing;
    late ShareCubit cubit;

    setUp(() {
      final _Session session = _Session();
      final FirestoreJourneyRepository journeys = FirestoreJourneyRepository(
        FakeFirebaseFirestore(),
        session,
      );
      location = FakeLocation(now: LocationAccess.granted);
      shares = FakeShares();
      links = FakeShareLinks();
      tracker = JourneyTracker(
        location: location,
        store: MemoryTrackStore(),
        route: FakeRoute(),
        journeys: journeys,
        session: session,
        translate: (String k) => k,
        tickEvery: const Duration(days: 1),
      );
      sharing = LocationSharing(
        tracker: tracker,
        shares: shares,
        journeys: journeys,
        session: session,
        links: links,
        tickEvery: const Duration(days: 1),
      );
      cubit = ShareCubit(sharing, tracker, journeys);
    });

    tearDown(() async {
      await cubit.close();
      await sharing.dispose();
      await tracker.dispose();
    });

    test('nothing is shared until asked', () {
      expect(cubit.state, isA<ShareIdle>());
      expect(shares.saved, isEmpty);
    });

    test('starting shows the share', () async {
      await cubit.start(ShareDuration.minutes30);
      expect(cubit.state, isA<ShareActive>());
    });

    test('a failure is said, and no link exists', () async {
      links.viewer = false;
      await cubit.start(ShareDuration.minutes30);
      expect(cubit.state, const ShareFailed(ShareFailureCode.unavailable));
    });

    test('the system prompt comes from the tap, and a no is said', () async {
      location
        ..now = LocationAccess.denied
        ..afterAsking = LocationAccess.denied;
      await cubit.start(ShareDuration.minutes30);
      expect(location.asked, 1);
      expect(cubit.state, const ShareFailed(ShareFailureCode.noAccess));
    });

    test('Start always asks, so the notice can show', () async {
      await cubit.start(ShareDuration.minutes30);
      expect(location.noticesAsked, 1);
    });

    test('a journey that cannot be read cannot be shared', () async {
      await cubit.start(ShareDuration.minutes30, journeyId: 'nope');
      expect(cubit.state, const ShareFailed(ShareFailureCode.notActive));
    });

    test('stopping says whether the server has it', () async {
      await cubit.start(ShareDuration.minutes30);
      shares.stopConfirmed = false;
      await cubit.stop();
      expect(cubit.state, const ShareStopped(confirmed: false));
    });

    test('a screen opened later finds the share', () async {
      await cubit.start(ShareDuration.minutes30);
      final ShareCubit second = ShareCubit(
        sharing,
        tracker,
        FirestoreJourneyRepository(FakeFirebaseFirestore(), _Session()),
      );
      expect(second.state, isA<ShareActive>());
      await second.close();
    });
  });

  group('SharedViewCubit', () {
    late _FakeView repository;
    late DateTime now;
    late SharedViewCubit cubit;
    final String token = BearerToken.generate(Random(1));

    SharedView view({
      String tracking = 'live',
      bool position = true,
      DateTime? at,
      int routeChunks = 0,
      int routeVersion = 0,
      DateTime? expires,
    }) => SharedView(
      kind: 'journey',
      expiresAt: expires ?? now.add(const Duration(hours: 1)),
      tracking: tracking,
      point: position ? const LatLng(24.7, 46.68) : null,
      locationAt: position ? at ?? now : null,
      routeChunks: routeChunks,
      routeVersion: routeVersion,
    );

    Future<void> send(SharedViewEvent e) async {
      repository.events.add(e);
      await pumpEventQueue();
    }

    setUp(() {
      repository = _FakeView();
      now = DateTime.utc(2026, 11, 4, 12);
      cubit = SharedViewCubit(
        repository,
        clock: () => now,
        checkEvery: const Duration(days: 1),
      );
    });

    tearDown(() => cubit.close());

    test('a malformed link opens nothing and reads nothing', () {
      cubit.open('nope');
      expect(cubit.state.phase, SharedViewPhase.ended);
      expect(repository.events.hasListener, isFalse);
    });

    test('a live share shows as live', () async {
      cubit.open(token);
      await send(SharedViewEvent(view: view()));
      expect(cubit.state.phase, SharedViewPhase.ready);
      expect(cubit.state.liveness, SharedLiveness.live);
    });

    test('a new position arrives', () async {
      cubit.open(token);
      await send(SharedViewEvent(view: view()));
      now = now.add(const Duration(seconds: 15));
      await send(SharedViewEvent(view: view(at: now)));
      expect(cubit.state.view?.locationAt, now);
    });

    test('with nothing new, it stops being called live by itself', () async {
      cubit.open(token);
      await send(SharedViewEvent(view: view()));
      now = now.add(const Duration(minutes: 2));
      cubit.check();
      expect(cubit.state.liveness, SharedLiveness.stale);
    });

    test('offline it keeps what it has, marked stale', () async {
      cubit.open(token);
      await send(SharedViewEvent(view: view()));
      await send(SharedViewEvent(view: view(), offline: true));
      expect(cubit.state.phase, SharedViewPhase.ready);
      expect(cubit.state.offline, isTrue);
      expect(cubit.state.liveness, SharedLiveness.stale);
    });

    test('back online it is live again, with a fresh position', () async {
      cubit.open(token);
      await send(SharedViewEvent(view: view()));
      await send(const SharedViewEvent(offline: true));
      now = now.add(const Duration(minutes: 5));
      await send(SharedViewEvent(view: view(at: now)));
      expect(cubit.state.liveness, SharedLiveness.live);
    });

    test('nothing yet and no connection is said', () async {
      cubit.open(token);
      await send(const SharedViewEvent(offline: true));
      expect(cubit.state.phase, SharedViewPhase.unreachable);
    });

    test('stopped: what was shown goes with it', () async {
      cubit.open(token);
      await send(SharedViewEvent(view: view()));
      await send(const SharedViewEvent(ended: true));
      expect(cubit.state.phase, SharedViewPhase.ended);
      expect(cubit.state.view, isNull);
    });

    test('expired, with nothing arriving to say so', () async {
      cubit.open(token);
      await send(
        SharedViewEvent(
          view: view(expires: now.add(const Duration(minutes: 1))),
        ),
      );
      now = now.add(const Duration(minutes: 2));
      cubit.check();
      expect(cubit.state.phase, SharedViewPhase.ended);
    });

    test('the route is read by chunk, and only what changed', () async {
      repository.chunks[0] = const <SharedRoutePoint>[
        SharedRoutePoint(lat: 24.1, lng: 46.1, segment: 0),
      ];
      repository.chunks[1] = const <SharedRoutePoint>[
        SharedRoutePoint(lat: 24.2, lng: 46.2, segment: 1),
      ];
      cubit.open(token);
      await send(SharedViewEvent(view: view(routeChunks: 2, routeVersion: 1)));
      expect(repository.asked, <int>[0, 1]);
      expect(cubit.segments, hasLength(2));

      repository.asked.clear();
      await send(SharedViewEvent(view: view(routeChunks: 2, routeVersion: 1)));
      expect(repository.asked, isEmpty, reason: 'same route, no read');

      await send(SharedViewEvent(view: view(routeChunks: 2, routeVersion: 2)));
      expect(repository.asked, <int>[1], reason: 'only the last chunk');
    });

    test('a share from Firestore reads the same way', () {
      final SharedView? v = SharedView.read(<String, dynamic>{
        'kind': 'location',
        'expiresAt': Timestamp.fromDate(now),
        'tracking': 'waiting',
      });
      expect(v?.isJourney, isFalse);
    });
  });
}
