import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/security/bearer_token.dart';
import 'package:safe_ride/core/firebase/firestore_account_data.dart';
import 'package:safe_ride/core/firebase/firestore_paths.dart';
import 'package:safe_ride/features/journeys/data/models/location_share.dart';
import 'package:safe_ride/features/journeys/data/models/shared_view.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_share_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/share_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/shared_view_repository.dart';

void main() {
  group('BearerToken', () {
    test('is 256 bits, url-safe, and never the same', () {
      final Set<String> seen = <String>{};
      for (int i = 0; i < 500; i++) {
        final String t = BearerToken.generate();
        expect(BearerToken.isValid(t), isTrue);
        expect(t, hasLength(43));
        seen.add(t);
      }
      expect(seen, hasLength(500));
    });

    test('a short, long or odd token is refused', () {
      final String t = BearerToken.generate(Random(1));
      expect(BearerToken.isValid(null), isFalse);
      expect(BearerToken.isValid(''), isFalse);
      expect(BearerToken.isValid(t.substring(1)), isFalse);
      expect(BearerToken.isValid('${t}a'), isFalse);
      expect(BearerToken.isValid('${t.substring(1)}/'), isFalse);
    });
  });

  group('ShareLinks', () {
    test('the token is after the #, so no server ever receives it', () {
      final String t = BearerToken.generate(Random(1));
      final Uri link = Uri.parse(ShareLinks.link(t));
      expect(link.path, '/s');
      expect(link.query, isEmpty);
      expect(link.fragment, t);
      expect(ShareLinks.tokenOf(link), t);
    });

    test('anything else opens nothing', () {
      expect(ShareLinks.tokenOf(Uri.parse('https://x.test/s')), isNull);
      expect(ShareLinks.tokenOf(Uri.parse('https://x.test/s#short')), isNull);
    });
  });

  group('ShareDuration', () {
    test('every option is inside what the rules allow', () {
      for (final ShareDuration d in ShareDuration.values) {
        expect(d.length, lessThan(const Duration(hours: 12)));
      }
    });

    test('until it finishes is only for a journey', () {
      expect(
        ShareDuration.forLocation,
        isNot(contains(ShareDuration.untilFinished)),
      );
      expect(ShareDuration.forJourney.first, ShareDuration.untilFinished);
    });
  });

  group('SharedView', () {
    final DateTime now = DateTime.utc(2026, 11, 4, 12);
    Timestamp at(DateTime t) => Timestamp.fromDate(t);

    Map<String, dynamic> data({
      Map<String, dynamic> extra = const {},
    }) => <String, dynamic>{
      'kind': 'journey',
      'expiresAt': at(now.add(const Duration(hours: 1))),
      'tracking': 'live',
      'location': <String, Object>{'lat': 24.7, 'lng': 46.68, 'accuracy': 8},
      'locationAt': at(now.subtract(const Duration(seconds: 10))),
      'routeChunks': 2,
      'routeVersion': 5,
      ...extra,
    };

    SharedLiveness live(
      SharedView v, {
      DateTime? time,
      DateTime? heard,
      bool offline = false,
    }) => v.liveness(
      now: time ?? now,
      heardAt: heard ?? time ?? now,
      offline: offline,
    );

    test('a recent position is live', () {
      expect(live(SharedView.read(data())!), SharedLiveness.live);
    });

    test('an old position is never called live', () {
      final SharedView v = SharedView.read(data())!;
      final DateTime later = now.add(const Duration(minutes: 2));
      expect(live(v, time: later), SharedLiveness.stale);
    });

    test('nothing heard lately is stale, whatever the clock says', () {
      final SharedView v = SharedView.read(data())!;
      expect(
        live(v, heard: now.subtract(const Duration(minutes: 2))),
        SharedLiveness.stale,
      );
    });

    test('offline is stale, paused and finished are told apart', () {
      expect(
        live(SharedView.read(data())!, offline: true),
        SharedLiveness.stale,
      );
      expect(
        live(SharedView.read(data(extra: {'tracking': 'paused'}))!),
        SharedLiveness.paused,
      );
      expect(
        live(SharedView.read(data(extra: {'journeyStatus': 'finished'}))!),
        SharedLiveness.finished,
      );
    });

    test('no position yet is waiting, not live', () {
      final Map<String, dynamic> none = data()
        ..remove('location')
        ..remove('locationAt');
      expect(live(SharedView.read(none)!), SharedLiveness.waiting);
    });

    test('bad coordinates are no position', () {
      final SharedView v = SharedView.read(
        data(
          extra: <String, dynamic>{
            'location': <String, Object>{'lat': 95, 'lng': 46.68},
          },
        ),
      )!;
      expect(v.point, isNull);
    });

    test('a document that cannot be read shows nothing', () {
      expect(SharedView.read(const <String, dynamic>{}), isNull);
      expect(SharedView.read(<String, dynamic>{'kind': 'journey'}), isNull);
    });

    test('expires at its time', () {
      final SharedView v = SharedView.read(data())!;
      expect(v.expiredAt(now), isFalse);
      expect(v.expiredAt(now.add(const Duration(hours: 1))), isTrue);
    });
  });

  group('SharedRoutePoint.segments', () {
    test('no line crosses a gap', () {
      final List<List<Object>> lines =
          SharedRoutePoint.segments(const <SharedRoutePoint>[
            SharedRoutePoint(lat: 24.1, lng: 46.1, segment: 0),
            SharedRoutePoint(lat: 24.2, lng: 46.2, segment: 0),
            SharedRoutePoint(lat: 24.3, lng: 46.3, segment: 2),
          ]);
      expect(lines, hasLength(2));
      expect(lines.first, hasLength(2));
    });

    test('a point with bad coordinates is dropped', () {
      expect(
        SharedRoutePoint.read(<String, Object>{'lat': 91, 'lng': 46, 'seg': 0}),
        isNull,
      );
      expect(SharedRoutePoint.read('nope'), isNull);
    });
  });

  group('FirestoreShareRepository', () {
    late FakeFirebaseFirestore db;
    late FirestoreShareRepository repository;
    final String token = BearerToken.generate(Random(1));
    final DateTime expires = DateTime.now().toUtc().add(
      const Duration(hours: 1),
    );

    setUp(() {
      db = FakeFirebaseFirestore();
      repository = FirestoreShareRepository(db);
    });

    Future<Map<String, dynamic>> public() async =>
        (await db.doc(FirestorePaths.share(token)).get()).data()!;

    Future<void> create({ShareKind kind = ShareKind.journey}) =>
        repository.create(
          uid: 'sara',
          token: token,
          kind: kind,
          expiresAt: expires,
          journeyId: kind == ShareKind.journey ? 'j1' : null,
          origin: kind == ShareKind.journey
              ? const SharedPlace(name: 'Home', lat: 24.7, lng: 46.68)
              : null,
          destination: kind == ShareKind.journey
              ? const SharedPlace(name: 'Work')
              : null,
        );

    test('the public document holds nothing of the owner', () async {
      await create();
      final Map<String, dynamic> d = await public();
      expect(d.keys, isNot(contains('ownerUid')));
      expect(d.keys, isNot(contains('uid')));
      expect(d.keys, isNot(contains('journeyId')));
      expect(d.toString(), isNot(contains('sara')));
      expect(d.toString(), isNot(contains('j1')));
      expect(d['tracking'], 'waiting');
    });

    test('the owner keeps the record that proves it', () async {
      await create();
      final List<ShareRecord> mine = await repository.records('sara');
      expect(mine.single.token, token);
      expect(mine.single.journeyId, 'j1');
      expect(await repository.records('omar'), isEmpty);
    });

    test('a location share says nothing of any journey', () async {
      await create(kind: ShareKind.location);
      final Map<String, dynamic> d = await public();
      for (final String k in <String>[
        'origin',
        'destination',
        'journeyStatus',
      ]) {
        expect(d.keys, isNot(contains(k)));
      }
    });

    test('a position is written, stamped, with its route', () async {
      await create();
      await repository.publish(
        token,
        ShareUpdate(
          tracking: 'live',
          position: SharePosition(
            lat: 24.7,
            lng: 46.68,
            accuracy: 8,
            fixAt: DateTime.now().toUtc(),
          ),
          distanceMeters: 120,
          routeChunks: 1,
          routeVersion: 1,
          chunks: const <int, List<SharedRoutePoint>>{
            0: <SharedRoutePoint>[
              SharedRoutePoint(lat: 24.7, lng: 46.68, segment: 0),
            ],
          },
        ),
      );
      final Map<String, dynamic> d = await public();
      expect(d['tracking'], 'live');
      expect(d['location']['lat'], 24.7);
      expect(d['locationAt'], isNotNull);
      expect(d['routeChunks'], 1);
      final DocumentSnapshot<Map<String, dynamic>> chunk = await db
          .doc('${FirestorePaths.shareRoute(token)}/00000')
          .get();
      expect(chunk.data()?['points'], hasLength(1));
    });

    test('a share that is gone is said, and not recreated', () async {
      await expectLater(
        repository.publish(token, const ShareUpdate(tracking: 'live')),
        throwsA(isA<ShareGone>()),
      );
      expect((await db.doc(FirestorePaths.share(token)).get()).exists, isFalse);
    });

    test('finishing drops the position and shortens the time', () async {
      await create();
      await repository.publish(
        token,
        ShareUpdate(
          tracking: 'live',
          position: SharePosition(
            lat: 24.7,
            lng: 46.68,
            accuracy: 8,
            fixAt: DateTime.now().toUtc(),
          ),
        ),
      );
      final DateTime soon = DateTime.now().toUtc().add(
        const Duration(minutes: 10),
      );
      await repository.finish(
        'sara',
        token,
        expiresAt: soon,
        last: const ShareUpdate(tracking: 'ended'),
      );
      final Map<String, dynamic> d = await public();
      expect(d['journeyStatus'], 'finished');
      expect(d.keys, isNot(contains('location')));
      expect(d.keys, isNot(contains('locationAt')));
      final List<ShareRecord> mine = await repository.records('sara');
      expect(mine.single.expiresAt.isBefore(expires), isTrue);
    });

    test('stopping removes the link, its route and the record', () async {
      await create();
      await db.doc('${FirestorePaths.shareRoute(token)}/00000').set(
        <String, Object>{'chunk': 0},
      );
      expect(await repository.stop('sara', token), isTrue);
      expect((await db.doc(FirestorePaths.share(token)).get()).exists, isFalse);
      expect(
        (await db.collection(FirestorePaths.shareRoute(token)).get()).docs,
        isEmpty,
      );
      expect(await repository.records('sara'), isEmpty);
    });
  });

  group('account deletion', () {
    test(
      'removes every share, public and private, and nobody else\'s',
      () async {
        final FakeFirebaseFirestore db = FakeFirebaseFirestore();
        final FirestoreShareRepository repository = FirestoreShareRepository(
          db,
        );
        final String mine = BearerToken.generate(Random(1));
        final String theirs = BearerToken.generate(Random(2));
        final DateTime later = DateTime.now().toUtc().add(
          const Duration(hours: 1),
        );
        await repository.create(
          uid: 'sara',
          token: mine,
          kind: ShareKind.location,
          expiresAt: later,
        );
        await repository.create(
          uid: 'omar',
          token: theirs,
          kind: ShareKind.location,
          expiresAt: later,
        );
        await db.doc('${FirestorePaths.shareRoute(mine)}/00000').set(
          <String, Object>{'chunk': 0},
        );

        await FirestoreAccountData(db).erase('sara');

        expect(
          (await db.doc(FirestorePaths.share(mine)).get()).exists,
          isFalse,
        );
        expect(
          (await db.collection(FirestorePaths.shareRoute(mine)).get()).docs,
          isEmpty,
        );
        expect(await repository.records('sara'), isEmpty);
        expect(
          (await db.doc(FirestorePaths.share(theirs)).get()).exists,
          isTrue,
        );
        expect(await repository.records('omar'), hasLength(1));
      },
    );
  });

  group('FirestoreSharedViewRepository', () {
    test('reads a share, and its deletion is the end of it', () async {
      final FakeFirebaseFirestore db = FakeFirebaseFirestore();
      final String token = BearerToken.generate(Random(1));
      await FirestoreShareRepository(db).create(
        uid: 'sara',
        token: token,
        kind: ShareKind.location,
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      final List<SharedViewEvent> seen = <SharedViewEvent>[];
      final FirestoreSharedViewRepository repository =
          FirestoreSharedViewRepository(db);
      final sub = repository.watch(token).listen(seen.add);
      await pumpEventQueue();
      expect(seen.last.view?.kind, 'location');
      await FirestoreShareRepository(db).stop('sara', token);
      await pumpEventQueue();
      expect(seen.last.ended, isTrue);
      await sub.cancel();
    });
  });
}
