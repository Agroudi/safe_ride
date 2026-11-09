import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_draft.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/data/models/route_progress.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/map_http.dart';
import 'package:safe_ride/features/journeys/data/repository/map_style_tuner.dart';
import 'package:safe_ride/features/journeys/data/repository/osrm_routing_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/photon_geocoding_repository.dart';

class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      const SessionUser(id: 'sara', fullName: 'Sara');
}

Map<String, Object?> _feature(
  String name, {
  double lng = 46.7,
  double lat = 24.7,
  Map<String, Object?> extra = const <String, Object?>{},
}) => <String, Object?>{
  'geometry': <String, Object?>{
    'coordinates': <double>[lng, lat],
  },
  'properties': <String, Object?>{'name': name, ...extra},
};

http.Response _json(Object body, {int status = 200}) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

void main() {
  group('MapHttp', () {
    test('names the app on every request', () async {
      late http.BaseRequest seen;
      await MapHttp(
        MockClient((http.Request r) async {
          seen = r;
          return _json(<String, Object?>{});
        }),
      ).getJson(Uri.parse('https://example.com'));
      expect(seen.headers['User-Agent'], startsWith('SafeRide/'));
    });

    Future<MapFailureCode?> failing(Future<http.Response> Function() f) async {
      try {
        await MapHttp(
          MockClient((_) => f()),
        ).getJson(Uri.parse('https://example.com'));
        return null;
      } on MapFailure catch (e) {
        return e.code;
      }
    }

    test(
      'no connection, an overloaded server and nonsense are told apart',
      () async {
        expect(
          await failing(() async => throw const SocketException('x')),
          MapFailureCode.offline,
        );
        expect(
          await failing(() async => throw http.ClientException('x')),
          MapFailureCode.offline,
        );
        expect(
          await failing(() async => http.Response('', 429)),
          MapFailureCode.unavailable,
        );
        expect(
          await failing(() async => http.Response('', 503)),
          MapFailureCode.unavailable,
        );
        expect(
          await failing(() async => http.Response('<html>', 200)),
          MapFailureCode.unavailable,
        );
      },
    );
  });

  group('Photon', () {
    late List<Uri> asked;
    late List<Map<String, Object?>> features;
    late PhotonGeocodingRepository geocoding;

    setUp(() {
      asked = <Uri>[];
      features = <Map<String, Object?>>[];
      geocoding = PhotonGeocodingRepository(
        MapHttp(
          MockClient((http.Request r) async {
            asked.add(r.url);
            return _json(<String, Object?>{'features': features});
          }),
        ),
        baseUrl: 'https://geo.test',
      );
    });

    test('reads a place, with a full address and an id', () async {
      features = <Map<String, Object?>>[
        _feature(
          'الرياض',
          extra: <String, Object?>{
            'state': 'منطقة الرياض',
            'country': 'السعودية',
            'osm_type': 'N',
            'osm_id': 42,
          },
        ),
      ];
      final List<JourneyPlace> found = await geocoding.search(
        'Riyadh',
        languageCode: 'ar',
      );
      expect(found.single.name, 'الرياض');
      expect(found.single.lat, 24.7);
      expect(found.single.lng, 46.7);
      expect(found.single.address, 'منطقة الرياض، السعودية');
      expect(found.single.placeId, 'N42');
    });

    test('Arabic asks for local names; English asks for English', () async {
      await geocoding.search('Cairo', languageCode: 'ar');
      expect(asked.last.queryParameters.containsKey('lang'), isFalse);
      await geocoding.search('Cairo', languageCode: 'en');
      expect(asked.last.queryParameters['lang'], 'en');
    });

    test('only an area leaves the phone, never the exact point', () async {
      await geocoding.search(
        'Mall',
        languageCode: 'en',
        near: const LatLng(24.713612, 46.675312),
      );
      expect(asked.single.queryParameters['lat'], '24.71');
      expect(asked.single.queryParameters['lon'], '46.68');
    });

    test('the same words are asked for once', () async {
      await geocoding.search('Mall', languageCode: 'en');
      await geocoding.search(' mall ', languageCode: 'en');
      expect(asked, hasLength(1));
      await geocoding.search('Mall', languageCode: 'ar');
      expect(asked, hasLength(2));
    });

    test('impossible coordinates and nameless results are dropped', () async {
      features = <Map<String, Object?>>[
        _feature('Nowhere', lat: 99),
        _feature('Null island', lat: 0, lng: 0),
        <String, Object?>{'geometry': <String, Object?>{}, 'properties': 1},
        _feature(''),
        _feature('Real'),
      ];
      final List<JourneyPlace> found = await geocoding.search(
        'x y z',
        languageCode: 'en',
      );
      expect(found.map((JourneyPlace p) => p.name), <String>['Real']);
    });

    test('a place listed twice shows once', () async {
      features = <Map<String, Object?>>[
        _feature('Dubai', extra: <String, Object?>{'country': 'UAE'}),
        _feature(
          'Dubai',
          lat: 25.2,
          extra: <String, Object?>{'country': 'UAE'},
        ),
        _feature('Dubai', extra: <String, Object?>{'country': 'Other'}),
      ];
      expect(await geocoding.search('Dubai', languageCode: 'en'), hasLength(2));
    });

    test('nothing there is an answer, not a failure', () async {
      expect(
        await geocoding.reverse(const LatLng(1, 1), languageCode: 'en'),
        isNull,
      );
    });
  });

  group('OSRM', () {
    OsrmRoutingRepository routing(Object body, {List<Uri>? asked}) =>
        OsrmRoutingRepository(
          MapHttp(
            MockClient((http.Request r) async {
              asked?.add(r.url);
              return _json(body, status: 200);
            }),
          ),
          baseUrl: 'https://route.test',
        );

    final Map<String, Object?> ok = <String, Object?>{
      'code': 'Ok',
      'routes': <Object?>[
        <String, Object?>{
          'distance': 1200.5,
          'duration': 300.0,
          'geometry': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
        },
      ],
    };

    test('decodes the published polyline example', () {
      final List<LatLng> points = OsrmRoutingRepository.decodePolyline(
        '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
      );
      expect(points, hasLength(3));
      expect(points[0].latitude, closeTo(38.5, 1e-5));
      expect(points[0].longitude, closeTo(-120.2, 1e-5));
      expect(points[2].latitude, closeTo(43.252, 1e-5));
      expect(points[2].longitude, closeTo(-126.453, 1e-5));
    });

    test('reads the distance and duration the provider gave', () async {
      final PlannedRoute route = await routing(
        ok,
      ).route(const LatLng(24.7, 46.7), const LatLng(21.5, 39.2));
      expect(route.distanceMeters, 1200.5);
      expect(route.durationSeconds, 300);
      expect(route.points, hasLength(3));
    });

    test('longitude first, and the same pair is asked for once', () async {
      final List<Uri> asked = <Uri>[];
      final OsrmRoutingRepository r = routing(ok, asked: asked);
      await r.route(const LatLng(24.7, 46.7), const LatLng(21.5, 39.2));
      await r.route(const LatLng(24.7, 46.7), const LatLng(21.5, 39.2));
      expect(asked, hasLength(1));
      expect(
        asked.single.path,
        contains('46.70000,24.70000;39.20000,21.50000'),
      );
    });

    test('no road is its own answer; nothing is made up', () async {
      await expectLater(
        routing(<String, Object?>{
          'code': 'NoRoute',
        }).route(const LatLng(1, 1), const LatLng(2, 2)),
        throwsA(
          isA<MapFailure>().having(
            (MapFailure f) => f.code,
            'code',
            MapFailureCode.noRoute,
          ),
        ),
      );
    });

    test('an answer without a route is a failure', () async {
      await expectLater(
        routing(<String, Object?>{
          'code': 'Ok',
          'routes': <Object?>[],
        }).route(const LatLng(1, 1), const LatLng(2, 2)),
        throwsA(isA<MapFailure>()),
      );
    });
  });

  group('RouteProgress', () {
    final PlannedRoute route = PlannedRoute(
      points: const <LatLng>[
        LatLng(24, 46),
        LatLng(24, 46.1),
        LatLng(24, 46.2),
      ],
      distanceMeters: 20000,
      durationSeconds: 1000,
    );

    test('halfway along, half is left', () {
      final RouteProgress p = RouteProgress.along(
        route,
        const LatLng(24, 46.1),
      )!;
      expect(p.remainingMeters, closeTo(10160, 100));
      expect(p.remainingSeconds, closeTo(500, 5));
    });

    test('off the route, nothing is claimed', () {
      expect(RouteProgress.along(route, const LatLng(24.05, 46.1)), isNull);
    });

    test('a route with no estimate gives distance only', () {
      final RouteProgress? p = RouteProgress.along(
        PlannedRoute(points: route.points, distanceMeters: 20000),
        const LatLng(24, 46.1),
      );
      expect(p?.remainingSeconds, isNull);
      expect(p?.remainingMeters, greaterThan(0));
    });

    test('too short a route says nothing', () {
      expect(
        RouteProgress.along(
          const PlannedRoute(points: <LatLng>[], distanceMeters: 0),
          const LatLng(24, 46),
        ),
        isNull,
      );
    });
  });

  group('JourneyPlace', () {
    test('coordinates must be real', () {
      expect(JourneyPlace.validCoordinates(24.7, 46.7), isTrue);
      expect(JourneyPlace.validCoordinates(90.1, 0), isFalse);
      expect(JourneyPlace.validCoordinates(0, 180.1), isFalse);
      expect(JourneyPlace.validCoordinates(0, 0), isFalse);
      expect(JourneyPlace.validCoordinates(double.nan, 1), isFalse);
    });

    test('a bad stored place costs only itself', () {
      const JourneyPlaceConverter c = JourneyPlaceConverter();
      expect(c.fromJson(null), isNull);
      expect(c.fromJson('x'), isNull);
      expect(
        c.fromJson(<String, Object?>{'name': 'x', 'lat': 99.0, 'lng': 1.0}),
        isNull,
      );
      expect(c.fromJson(<String, Object?>{'name': 'x'}), isNull);
      expect(
        c.fromJson(<String, Object?>{'name': 'x', 'lat': 24.7, 'lng': 46.7}),
        const JourneyPlace(name: 'x', lat: 24.7, lng: 46.7),
      );
    });

    test('a draft carries its places to review and back', () {
      final JourneyDraft back = JourneyDraft.from(
        JourneyDraft(
          origin: 'Home',
          destination: 'Work',
          departsAt: DateTime.utc(2026, 11, 5),
          originPlace: const JourneyPlace(name: 'Home', lat: 24.7, lng: 46.7),
          plannedDistanceMeters: 1200,
        ).toExtra(),
      )!;
      expect(back.originPlace?.lat, 24.7);
      expect(back.destinationPlace, isNull);
      expect(back.plannedDistanceMeters, 1200);
      expect(back.plannedDurationSeconds, isNull);
    });
  });

  group('journeys with places', () {
    late FakeFirebaseFirestore db;
    late FirestoreJourneyRepository journeys;
    const JourneyPlace home = JourneyPlace(
      name: 'Home',
      lat: 24.7,
      lng: 46.7,
      address: 'Olaya',
      placeId: 'N1',
    );
    const JourneyPlace work = JourneyPlace(name: 'Work', lat: 24.8, lng: 46.8);

    setUp(() {
      db = FakeFirebaseFirestore();
      journeys = FirestoreJourneyRepository(db, _Session());
    });

    Future<JourneyModel> planned() => journeys.plan(
      origin: 'Home',
      destination: 'Work',
      departsAt: DateTime.now().add(const Duration(hours: 1)),
      originPlace: home,
      destinationPlace: work,
      plannedDistanceMeters: 1500,
      plannedDurationSeconds: 240,
    );

    test('are saved, and read back as numbers', () async {
      final JourneyModel j = await planned();
      final JourneyModel back = (await journeys.journey(j.id))!;
      expect(back.originPlace, home);
      expect(back.destinationPlace, work);
      expect(back.plannedDistanceMeters, 1500);
      expect(back.plannedDurationSeconds, 240);
      expect(back.origin, 'Home');
    });

    test('a journey from before maps reads as it always did', () async {
      await db.doc('users/sara/journeys/old').set(<String, Object?>{
        'origin': 'Home',
        'destination': 'Work',
        'departsAt': DateTime.utc(2026),
        'status': 'completed',
        'createdAt': DateTime.utc(2026),
        'updatedAt': DateTime.utc(2026),
      });
      final JourneyModel old = (await journeys.journey('old'))!;
      expect(old.origin, 'Home');
      expect(old.originPlace, isNull);
      expect(old.destinationPlace, isNull);
    });

    test('a journey with no pins gains no empty fields', () async {
      final JourneyModel j = await journeys.plan(
        origin: 'Home',
        destination: 'Work',
        departsAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final Map<String, dynamic> stored =
          (await db.doc('users/sara/journeys/${j.id}').get()).data()!;
      expect(stored.containsKey('originPlace'), isFalse);
      expect(stored.containsKey('plannedDistanceMeters'), isFalse);
    });

    test('an edit without pins removes them and the old estimate', () async {
      final JourneyModel j = await planned();
      await journeys.update(
        j.id,
        origin: 'Gym',
        destination: 'Work',
        departsAt: DateTime.now().add(const Duration(hours: 2)),
      );
      final Map<String, dynamic> stored =
          (await db.doc('users/sara/journeys/${j.id}').get()).data()!;
      expect(stored.containsKey('originPlace'), isFalse);
      expect(stored.containsKey('plannedDurationSeconds'), isFalse);
      expect(stored['origin'], 'Gym');
    });

    test('closing a journey keeps its places', () async {
      final JourneyModel j = await planned();
      await journeys.cancel(j.id);
      expect((await journeys.journey(j.id))?.originPlace, home);
    });
  });

  group('MapStyleTuner', () {
    final Map<String, dynamic> style = <String, dynamic>{
      'layers': <Object?>[
        <String, dynamic>{'id': 'bg', 'type': 'background'},
        <String, dynamic>{
          'id': 'water',
          'type': 'fill',
          'source-layer': 'water',
          'paint': <String, dynamic>{'fill-color': '#000000'},
        },
        <String, dynamic>{
          'id': 'highway_motorway',
          'type': 'line',
          'source-layer': 'transportation',
          'paint': <String, dynamic>{'line-color': '#000000', 'line-width': 2},
        },
        <String, dynamic>{
          'id': 'highway_minor',
          'type': 'line',
          'source-layer': 'transportation',
        },
        <String, dynamic>{
          'id': 'label',
          'type': 'symbol',
          'paint': <String, dynamic>{'text-color': '#222222'},
        },
      ],
    };

    int luminance(String hex) {
      final int v = int.parse(hex.substring(1), radix: 16);
      return (v >> 16) + ((v >> 8) & 0xff) + (v & 0xff);
    }

    test('labels read clearly and major roads stand out', () {
      final List<Object?> layers =
          MapStyleTuner.dark(style, AppColors.dark)['layers'] as List<Object?>;
      Map<String, dynamic> paint(int i) =>
          (layers[i]! as Map<String, dynamic>)['paint'] as Map<String, dynamic>;

      expect(paint(0)['background-color'], '#0b1220');
      final int ground = luminance(paint(0)['background-color'] as String);
      expect(
        luminance(paint(4)['text-color'] as String),
        greaterThan(ground + 300),
      );
      expect(
        luminance(paint(2)['line-color'] as String),
        greaterThan(luminance(paint(3)['line-color'] as String)),
      );
      expect(paint(2)['line-width'], 2, reason: 'only colours change');
    });

    test('light and dark never share an id: the tile cache keys on it', () {
      final Map<String, dynamic> dark = MapStyleTuner.dark(
        style,
        AppColors.dark,
      );
      final Map<String, dynamic> light = MapStyleTuner.light(style);
      expect(dark['id'], isNot(light['id']));
      expect(dark['id'], isA<String>());
      expect(light['id'], isA<String>());
      expect((dark['metadata'] as Map<String, dynamic>)['version'], isNotNull);
    });

    test('the original style is not changed', () {
      MapStyleTuner.dark(style, AppColors.dark);
      final Map<String, dynamic> water =
          (style['layers'] as List<Object?>)[1]! as Map<String, dynamic>;
      expect((water['paint'] as Map<String, dynamic>)['fill-color'], '#000000');
    });
  });
}
