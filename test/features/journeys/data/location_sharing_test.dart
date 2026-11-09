import 'dart:async';
import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/security/bearer_token.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_checklist.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/location_share.dart';
import 'package:safe_ride/features/journeys/data/models/shared_view.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_monitor.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/data/repository/location_sharing.dart';
import 'package:safe_ride/features/journeys/data/repository/share_repository.dart';

import '../tracking_fakes.dart';

class _Session implements SessionReader {
  String? uid = 'sara';
  final StreamController<void> changed = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => changed.stream;

  @override
  Future<SessionUser?> signedInUser() async =>
      uid == null ? null : SessionUser(id: uid!, fullName: 'Sara');
}

void main() {
  late _Session session;
  late FirestoreJourneyRepository journeys;
  late FakeLocation location;
  late FakeRoute route;
  late FakeShares shares;
  late FakeShareLinks links;
  late JourneyTracker tracker;
  late LocationSharing sharing;
  late MemoryIncidentRepository incidents;
  late DateTime now;

  setUp(() {
    session = _Session();
    journeys = FirestoreJourneyRepository(FakeFirebaseFirestore(), session);
    location = FakeLocation(now: LocationAccess.granted);
    route = FakeRoute();
    shares = FakeShares();
    links = FakeShareLinks();
    incidents = MemoryIncidentRepository();
    now = DateTime.now().toUtc();
    tracker = JourneyTracker(
      location: location,
      store: MemoryTrackStore(),
      route: route,
      journeys: journeys,
      session: session,
      observer: IncidentMonitor(incidents),
      translate: (String k) => k,
      clock: () => now,
      tickEvery: const Duration(days: 1),
    );
    sharing = LocationSharing(
      tracker: tracker,
      shares: shares,
      journeys: journeys,
      session: session,
      links: links,
      clock: () => now,
      tickEvery: const Duration(days: 1),
    );
  });

  tearDown(() async {
    await sharing.dispose();
    await tracker.dispose();
  });

  Future<void> flush() => pumpEventQueue(times: 100);

  Future<JourneyModel> started() async {
    final JourneyModel j = await journeys.plan(
      origin: 'Home',
      destination: 'Work',
      departsAt: DateTime.now().add(const Duration(hours: 1)),
    );
    await journeys.start(
      j.id,
      checklistVersion: 1,
      confirmed: JourneyChecklist.itemsOf(1).toSet(),
    );
    return (await journeys.journey(j.id))!;
  }

  /// A fix [metres] north of the start, [after] the last one.
  Future<void> fix(
    double metres, {
    Duration after = const Duration(seconds: 2),
    double accuracy = 8,
  }) async {
    now = now.add(after);
    location.fix(24.7 + metres / 111195, 46.67, at: now, accuracy: accuracy);
    await flush();
  }

  Future<void> wait(Duration d) async {
    now = now.add(d);
    sharing.tick();
    await flush();
  }

  List<SharePosition> positions() => <SharePosition>[
    for (final ShareUpdate u in shares.published) ?u.position,
  ];

  group('starting', () {
    test(
      'a location share needs no journey and opens one subscription',
      () async {
        await sharing.start(duration: ShareDuration.minutes30);
        expect(location.listens, 1);
        expect(sharing.current?.record.kind, ShareKind.location);
        expect(tracker.journeyId, isNull, reason: 'nothing is recorded');
      },
    );

    test('the token is a fresh 256-bit one', () async {
      final ShareRecord a = await sharing.start(
        duration: ShareDuration.minutes15,
      );
      expect(BearerToken.isValid(a.token), isTrue);
      await sharing.stop();
      final ShareRecord b = await sharing.start(
        duration: ShareDuration.minutes15,
      );
      expect(b.token, isNot(a.token));
    });

    test('it expires when it said', () async {
      final ShareRecord r = await sharing.start(duration: ShareDuration.hour1);
      expect(r.expiresAt, now.add(const Duration(hours: 1)));
    });

    test('no link is made when the viewer is not there', () async {
      links.viewer = false;
      await expectLater(
        sharing.start(duration: ShareDuration.minutes15),
        throwsA(
          isA<ShareFailure>().having(
            (ShareFailure f) => f.code,
            'code',
            ShareFailureCode.unavailable,
          ),
        ),
      );
      expect(shares.saved, isEmpty);
      expect(sharing.current, isNull);
    });

    test('a share nobody could read is taken back', () async {
      links.public = false;
      await expectLater(
        sharing.start(duration: ShareDuration.minutes15),
        throwsA(isA<ShareFailure>()),
      );
      expect(shares.stopped, hasLength(1));
      expect(shares.saved, isEmpty);
      expect(sharing.current, isNull);
    });

    test('the rules refusing it is a failure, not a share', () async {
      shares.createFailure = const ShareGone();
      await expectLater(
        sharing.start(duration: ShareDuration.minutes15),
        throwsA(
          isA<ShareFailure>().having(
            (ShareFailure f) => f.code,
            'code',
            ShareFailureCode.refused,
          ),
        ),
      );
    });

    test('no connection is said, and nothing is left', () async {
      shares.createFailure = const ShareFailure(ShareFailureCode.offline);
      await expectLater(
        sharing.start(duration: ShareDuration.minutes15),
        throwsA(isA<ShareFailure>()),
      );
      expect(sharing.current, isNull);
    });

    test('without location access nothing starts', () async {
      location.now = LocationAccess.denied;
      await expectLater(
        sharing.start(duration: ShareDuration.minutes15),
        throwsA(
          isA<ShareFailure>().having(
            (ShareFailure f) => f.code,
            'code',
            ShareFailureCode.noAccess,
          ),
        ),
      );
      expect(location.listens, 0);
    });

    test('one share at a time', () async {
      await sharing.start(duration: ShareDuration.minutes15);
      await expectLater(
        sharing.start(duration: ShareDuration.minutes15),
        throwsA(
          isA<ShareFailure>().having(
            (ShareFailure f) => f.code,
            'code',
            ShareFailureCode.alreadySharing,
          ),
        ),
      );
    });

    test('only a journey in progress can be shared', () async {
      final JourneyModel planned = await journeys.plan(
        origin: 'Home',
        destination: 'Work',
        departsAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await expectLater(
        sharing.start(duration: ShareDuration.minutes15, journey: planned),
        throwsA(
          isA<ShareFailure>().having(
            (ShareFailure f) => f.code,
            'code',
            ShareFailureCode.notActive,
          ),
        ),
      );
    });
  });

  group('publishing', () {
    setUp(() async {
      await sharing.start(duration: ShareDuration.hour1);
    });

    test('the first position goes at once, and reaches the link', () async {
      await fix(0);
      expect(positions(), hasLength(1));
      expect(shares.published.single.tracking, 'live');
      expect(sharing.current?.delivery, ShareDelivery.reaching);
      expect(sharing.current?.lastDeliveredAt, isNotNull);
    });

    test('fixes every 2 s become at most one write per 15 s', () async {
      await fix(0);
      for (int i = 1; i <= 15; i++) {
        await fix(i * 40.0);
      }
      // 30 s of fixes: the first, then one per interval.
      expect(positions().length, inInclusiveRange(2, 3));
    });

    test(
      'a phone standing still sends no position, only that it is there',
      () async {
        await fix(0);
        for (int i = 0; i < 20; i++) {
          await fix(1, after: const Duration(seconds: 5));
        }
        expect(positions(), hasLength(1), reason: 'no duplicate coordinates');
        final int confirmations = shares.published
            .where((ShareUpdate u) => u.confirmed)
            .length;
        expect(confirmations, 1, reason: 'one per minute');
      },
    );

    test('an inaccurate or stale fix is never published', () async {
      await fix(0);
      await fix(500, after: const Duration(seconds: 20), accuracy: 80);
      now = now.add(const Duration(seconds: 20));
      location.fix(24.8, 46.67, at: now.subtract(const Duration(minutes: 5)));
      await flush();
      expect(positions(), hasLength(1));
    });

    test('a GPS jump is never published', () async {
      await fix(0);
      await fix(90000, after: const Duration(seconds: 16));
      expect(positions(), hasLength(1));
    });

    test('invalid coordinates are never published', () async {
      await fix(0);
      now = now.add(const Duration(seconds: 16));
      location.fix(0, 0, at: now);
      await flush();
      location.fix(95, 46, at: now);
      await flush();
      expect(positions(), hasLength(1));
    });

    test(
      'no fix for a while says paused once, and returning goes live',
      () async {
        await fix(0);
        await wait(JourneyTracker.signalLost + const Duration(seconds: 1));
        await wait(const Duration(seconds: 30));
        final Iterable<ShareUpdate> paused = shares.published.where(
          (ShareUpdate u) => u.tracking == 'paused',
        );
        expect(paused, hasLength(1));
        expect(
          paused.single.position,
          isNull,
          reason: 'no position is claimed',
        );
        expect(sharing.current?.delivery, ShareDelivery.paused);
        await fix(60);
        expect(shares.published.last.tracking, 'live');
        expect(sharing.current?.delivery, ShareDelivery.reaching);
      },
    );

    group('with no connection', () {
      test('it says so, and sends only the latest position after', () async {
        await fix(0);
        shares.publishFailure = const ShareFailure(ShareFailureCode.offline);
        await fix(100, after: const Duration(seconds: 16));
        expect(sharing.current?.delivery, ShareDelivery.notReaching);
        for (int i = 2; i <= 40; i++) {
          await fix(i * 100.0, after: const Duration(seconds: 16));
        }
        shares.publishFailure = null;
        final int before = positions().length;
        await fix(4100, after: const Duration(seconds: 31));
        expect(positions().length, before + 1, reason: 'no backlog');
        expect(positions().last.lat, closeTo(24.7 + 4100 / 111195, 0.0001));
        expect(sharing.current?.delivery, ShareDelivery.reaching);
      });

      test('it waits between tries', () async {
        await fix(0);
        shares.publishFailure = const ShareFailure(ShareFailureCode.offline);
        await fix(100, after: const Duration(seconds: 16));
        shares.publishFailure = null;
        await fix(200, after: const Duration(seconds: 5));
        expect(positions(), hasLength(1));
        await fix(300, after: const Duration(seconds: 26));
        expect(positions(), hasLength(2));
      });
    });

    test('one send at a time', () async {
      await fix(0);
      final Completer<void> slow = Completer<void>();
      shares.hold = slow;
      await fix(100, after: const Duration(seconds: 16));
      await fix(200, after: const Duration(seconds: 16));
      await fix(300, after: const Duration(seconds: 16));
      shares.hold = null;
      slow.complete();
      await flush();
      expect(positions(), hasLength(2));
    });
  });

  group('ending', () {
    test('stopping ends publishing and the subscription at once', () async {
      await sharing.start(duration: ShareDuration.hour1);
      await fix(0);
      expect(await sharing.stop(), isTrue);
      expect(sharing.current, isNull);
      expect(shares.stopped, hasLength(1));
      final int sent = shares.published.length;
      await fix(100, after: const Duration(seconds: 20));
      expect(shares.published.length, sent);
      expect(location.fixesController.hasListener, isFalse);
    });

    test('stopped offline: it says so, and nothing more is sent', () async {
      await sharing.start(duration: ShareDuration.hour1);
      shares.stopConfirmed = false;
      expect(await sharing.stop(), isFalse);
      expect(sharing.current, isNull);
    });

    test('expiring ends it by itself', () async {
      await sharing.start(duration: ShareDuration.minutes15);
      await fix(0);
      await wait(const Duration(minutes: 16));
      expect(sharing.current, isNull);
      expect(shares.stopped, hasLength(1));
    });

    test('stopped from another phone: this one finds out and stops', () async {
      await sharing.start(duration: ShareDuration.hour1);
      await fix(0);
      shares.publishFailure = const ShareGone();
      await fix(100, after: const Duration(seconds: 16));
      expect(sharing.current, isNull);
    });
  });

  group('a shared journey', () {
    Future<JourneyModel> sharedJourney() async {
      final JourneyModel j = await started();
      await tracker.start(j.id);
      await sharing.start(duration: ShareDuration.untilFinished, journey: j);
      return j;
    }

    test('adds no location subscription', () async {
      await sharedJourney();
      expect(location.listens, 1);
    });

    test('a shared location joins a recording, and outlives it', () async {
      await sharing.start(duration: ShareDuration.hour1);
      final JourneyModel j = await started();
      await tracker.start(j.id);
      expect(location.listens, 1, reason: 'the same subscription');
      await journeys.complete(j.id);
      await flush();
      await tracker.stop(j.id);
      await flush();
      expect(sharing.current, isNotNull);
      await fix(0);
      expect(positions(), isNotEmpty, reason: 'still sharing the location');
    });

    test('recording is untouched by sharing', () async {
      await sharedJourney();
      await fix(0);
      await fix(100, after: const Duration(seconds: 3));
      await fix(200, after: const Duration(seconds: 3));
      expect(tracker.current?.distanceMeters, closeTo(200, 5));
      expect(tracker.current?.last, isNotNull);
    });

    test('a failing share never disturbs the recording', () async {
      await sharedJourney();
      shares.publishFailure = StateError('broken');
      await fix(0);
      await fix(100, after: const Duration(seconds: 16));
      await fix(200, after: const Duration(seconds: 16));
      expect(tracker.current?.distanceMeters, closeTo(200, 5));
    });

    test('the route goes at most once a minute, with the distance', () async {
      await sharedJourney();
      await fix(0);
      for (int i = 1; i <= 40; i++) {
        await fix(i * 40.0, after: const Duration(seconds: 3));
      }
      final Iterable<ShareUpdate> withRoute = shares.published.where(
        (ShareUpdate u) => u.chunks.isNotEmpty,
      );
      expect(withRoute.length, inInclusiveRange(1, 3));
      expect(withRoute.last.routeChunks, 1);
      expect(withRoute.last.distanceMeters, greaterThan(0));
    });

    test('a position never carries the whole route', () async {
      await sharedJourney();
      await fix(0);
      await fix(100, after: const Duration(seconds: 16));
      await fix(200, after: const Duration(seconds: 16));
      expect(
        shares.published.where((ShareUpdate u) => u.chunks.isEmpty),
        isNotEmpty,
      );
    });

    test('a gap in the recording stays a gap', () async {
      await sharedJourney();
      await fix(0);
      await fix(100, after: const Duration(seconds: 3));
      await fix(200, after: const Duration(minutes: 3));
      await fix(300, after: const Duration(seconds: 3));
      await wait(const Duration(seconds: 61));
      final List<SharedRoutePoint> points = shares.published
          .lastWhere((ShareUpdate u) => u.chunks.isNotEmpty)
          .chunks
          .values
          .first;
      expect(SharedRoutePoint.segments(points), hasLength(2));
    });

    test('the journey finishing ends it, without the last position', () async {
      final JourneyModel j = await sharedJourney();
      await fix(0);
      await journeys.complete(j.id);
      await flush();
      expect(sharing.current, isNull);
      expect(shares.finished, hasLength(1));
      expect(shares.finished.single.position, isNull);
      final ShareRecord after = shares.saved.values.single;
      expect(
        after.expiresAt.isBefore(now.add(const Duration(minutes: 11))),
        isTrue,
      );
    });

    test('offline at the end, the link is ended outright', () async {
      final JourneyModel j = await sharedJourney();
      shares.finishFailure = const ShareFailure(ShareFailureCode.offline);
      await journeys.complete(j.id);
      await flush();
      expect(shares.stopped, hasLength(1));
    });

    test('a cancelled journey ends it too', () async {
      final JourneyModel j = await sharedJourney();
      await journeys.cancel(j.id);
      await flush();
      expect(sharing.current, isNull);
    });
  });

  group('the account', () {
    test('signing out ends the link and stops publishing', () async {
      await sharing.start(duration: ShareDuration.hour1);
      await fix(0);
      await sharing.beforeSignOut();
      expect(shares.stopped, hasLength(1));
      expect(sharing.current, isNull);
      expect(location.fixesController.hasListener, isFalse);
    });

    test('a failed clean-up never holds up signing out', () async {
      await sharing.start(duration: ShareDuration.hour1);
      shares.stopFailure = StateError('unreachable');
      await expectLater(sharing.beforeSignOut(), completes);
      expect(sharing.current, isNull);
    });

    test('the next account publishes nothing of the last one', () async {
      await sharing.start(duration: ShareDuration.hour1);
      await fix(0);
      final int sent = shares.published.length;
      session.uid = 'omar';
      session.changed.add(null);
      await flush();
      expect(sharing.current, isNull);
      await fix(100, after: const Duration(seconds: 20));
      expect(shares.published.length, sent);
    });

    test('an account change between a fix and its send stops it', () async {
      await sharing.start(duration: ShareDuration.hour1);
      await fix(0);
      final int sent = shares.published.length;
      session.uid = 'omar';
      now = now.add(const Duration(seconds: 16));
      location.fix(24.8, 46.67, at: now);
      await flush();
      expect(shares.published.length, sent);
    });

    test('a journey and its local records survive signing out', () async {
      final JourneyModel j = await started();
      await tracker.start(j.id);
      await sharing.start(duration: ShareDuration.hour1, journey: j);
      await sharing.beforeSignOut();
      expect((await journeys.journey(j.id))?.status, JourneyStatus.active);
      expect(tracker.journeyId, j.id, reason: 'recording is not sharing');
    });

    test('deleting the account stops everything being sent', () async {
      await sharing.start(duration: ShareDuration.hour1);
      await sharing.erase('sara');
      expect(sharing.current, isNull);
      expect(location.fixesController.hasListener, isFalse);
    });
  });

  group('after a restart', () {
    ShareRecord record({
      ShareKind kind = ShareKind.location,
      Duration left = const Duration(minutes: 10),
      String? journeyId,
    }) {
      final ShareRecord r = ShareRecord(
        token: BearerToken.generate(Random(1)),
        kind: kind,
        expiresAt: now.add(left),
        journeyId: journeyId,
      );
      shares.saved[r.token] = r;
      return r;
    }

    test('a share still running is picked up', () async {
      record();
      await sharing.recover();
      expect(sharing.current, isNotNull);
      await fix(0);
      expect(positions(), hasLength(1));
    });

    test('an expired one is cleared', () async {
      final ShareRecord r = record(left: const Duration(minutes: -1));
      await sharing.recover();
      expect(sharing.current, isNull);
      expect(shares.stopped, <String>[r.token]);
    });

    test('a journey that ended meanwhile is not picked up', () async {
      final JourneyModel j = await started();
      await journeys.complete(j.id);
      final ShareRecord r = record(
        kind: ShareKind.journey,
        left: const Duration(hours: 5),
        journeyId: j.id,
      );
      await sharing.recover();
      expect(sharing.current, isNull);
      expect(shares.stopped, <String>[r.token]);
    });

    test('a shared journey carries on with its route so far', () async {
      final JourneyModel j = await started();
      await tracker.start(j.id);
      await fix(0);
      await fix(100, after: const Duration(seconds: 3));
      record(kind: ShareKind.journey, journeyId: j.id);
      await sharing.recover();
      await fix(200, after: const Duration(seconds: 16));
      expect(sharing.current?.record.journeyId, j.id);
      expect(
        shares.published.expand(
          (ShareUpdate u) =>
              u.chunks.values.expand((List<SharedRoutePoint> c) => c),
        ),
        isNotEmpty,
      );
    });

    test('signed out, nothing is touched', () async {
      record();
      session.uid = null;
      await sharing.recover();
      expect(sharing.current, isNull);
      expect(shares.stopped, isEmpty);
    });
  });

  test('stopping a share leaves the recording running', () async {
    final JourneyModel j = await started();
    await tracker.start(j.id);
    await sharing.start(duration: ShareDuration.hour1, journey: j);
    await fix(0);
    await fix(100, after: const Duration(seconds: 16));
    await sharing.stop();
    expect(tracker.journeyId, j.id);
    final TrackPoint? last = tracker.current?.last;
    await fix(200, after: const Duration(seconds: 3));
    expect(tracker.current?.last, isNot(last), reason: 'still recording');
    expect(location.listens, 1);
  });

  test('detection hears the same fixes with or without a share', () async {
    Future<int> driveThenBrake(String label) async {
      final JourneyModel j = await started();
      await tracker.start(j.id);
      if (label == 'shared') {
        await sharing.start(duration: ShareDuration.hour1, journey: j);
      }
      double at = 0;
      for (int i = 0; i < 6; i++) {
        at += 40;
        now = now.add(const Duration(seconds: 2));
        location.fix(24.7 + at / 111195, 46.67, at: now, speed: 20);
        await flush();
      }
      // Still for 48 s: with no speed error reported, the drop waits 45 s.
      for (int i = 0; i < 24; i++) {
        now = now.add(const Duration(seconds: 2));
        location.fix(24.7 + at / 111195, 46.67, at: now, speed: 0);
        await flush();
      }
      await sharing.stop();
      await journeys.complete(j.id);
      await tracker.stop(j.id);
      await flush();
      return (await incidents.forUser('sara')).length;
    }

    final int plain = await driveThenBrake('plain');
    final int shared = await driveThenBrake('shared');
    expect(shared, plain * 2, reason: 'the second journey adds as many');
    expect(plain, greaterThan(0));
  });
}
