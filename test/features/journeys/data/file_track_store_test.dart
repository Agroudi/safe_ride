import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/data/models/track_session.dart';
import 'package:safe_ride/features/journeys/data/repository/file_track_store.dart';

void main() {
  late Directory root;
  late FileTrackStore store;
  final DateTime t0 = DateTime.utc(2026, 11, 1, 9);

  TrackPoint point(int i) => TrackPoint(
    lat: 24.7 + i / 1000,
    lng: 46.67,
    at: t0.add(Duration(seconds: 5 * i)),
    accuracy: 8,
    speed: i.toDouble(),
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tracks');
    store = FileTrackStore(root: () async => root);
  });

  tearDown(() => root.delete(recursive: true));

  test('points come back in the order they were recorded', () async {
    for (int i = 0; i < 5; i++) {
      await store.append('sara', 'j1', point(i));
    }
    final List<TrackPoint> all = await store.points('sara', 'j1');
    expect(all, <TrackPoint>[for (int i = 0; i < 5; i++) point(i)]);
    expect(await store.points('sara', 'j1', from: 3), <TrackPoint>[
      point(3),
      point(4),
    ]);
    expect(await store.points('sara', 'j1', from: 1, limit: 2), <TrackPoint>[
      point(1),
      point(2),
    ]);
    expect(await store.points('sara', 'j1', from: 9), isEmpty);
  });

  test('a line cut short by a crash is skipped', () async {
    await store.append('sara', 'j1', point(0));
    final File file = File('${root.path}/tracks/sara/j1.points');
    await file.writeAsString('{"lat": 24.', mode: FileMode.append);
    await store.append('sara', 'j1', point(1));
    // The torn line and the next one share a line; only the clean ones count.
    expect((await store.points('sara', 'j1')).first, point(0));
  });

  test('a session is saved, replaced and read back', () async {
    final TrackSession s = TrackSession(
      journeyId: 'j1',
      uid: 'sara',
      recording: true,
      startedAt: t0,
      pointCount: 2,
      distanceMeters: 120.5,
      last: point(1),
    );
    await store.saveSession(s);
    expect(await store.session('sara', 'j1'), s);
    await store.saveSession(s.copyWith(syncedCount: 2));
    expect((await store.session('sara', 'j1'))?.syncedCount, 2);
  });

  test('each account sees only its own recordings', () async {
    await store.saveSession(
      TrackSession(
        journeyId: 'j1',
        uid: 'sara',
        recording: true,
        startedAt: t0,
      ),
    );
    await store.append('sara', 'j1', point(0));
    expect(await store.sessions('omar'), isEmpty);
    expect(await store.session('omar', 'j1'), isNull);
    expect(await store.points('omar', 'j1'), isEmpty);
    expect(await store.sessions('sara'), hasLength(1));
  });

  test('delete forgets the points and the session', () async {
    await store.saveSession(
      TrackSession(
        journeyId: 'j1',
        uid: 'sara',
        recording: false,
        startedAt: t0,
      ),
    );
    await store.append('sara', 'j1', point(0));
    await store.delete('sara', 'j1');
    expect(await store.session('sara', 'j1'), isNull);
    expect(await store.points('sara', 'j1'), isEmpty);
  });

  test('ids that could leave the directory are refused', () async {
    expect(() => store.points('sara', '../x'), throwsArgumentError);
    expect(() => store.sessions('a/b'), throwsArgumentError);
  });
}
