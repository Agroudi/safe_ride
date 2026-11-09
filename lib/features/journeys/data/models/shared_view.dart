import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';

/// How the phone's position stands, from a recipient's side.
enum SharedLiveness {
  /// Sharing has started, and no position has arrived yet.
  waiting,

  /// A recent position.
  live,

  /// The phone said it has no location for now.
  paused,

  /// The last position is old, or this device is offline: it may have moved.
  stale,

  /// The journey ended.
  finished,
}

/// One end of a shared journey: the user's own words, and where it is when it
/// was picked on the map.
final class SharedPlace extends Equatable {
  const SharedPlace({required this.name, this.lat, this.lng});

  static SharedPlace? read(Object? value) {
    if (value is! Map) return null;
    final Object? name = value['name'];
    if (name is! String || name.isEmpty) return null;
    final Object? lat = value['lat'];
    final Object? lng = value['lng'];
    final bool placed =
        lat is num &&
        lng is num &&
        JourneyPlace.validCoordinates(lat.toDouble(), lng.toDouble());
    return SharedPlace(
      name: name,
      lat: placed ? lat.toDouble() : null,
      lng: placed ? lng.toDouble() : null,
    );
  }

  final String name;
  final double? lat;
  final double? lng;

  LatLng? get point {
    final double? a = lat;
    final double? b = lng;
    return a == null || b == null ? null : LatLng(a, b);
  }

  Map<String, Object> toFirestore() => <String, Object>{
    'name': name,
    'lat': ?lat,
    'lng': ?lng,
  };

  @override
  List<Object?> get props => <Object?>[name, lat, lng];
}

/// What a link shows: the public document, and nothing else. It holds no owner
/// and no journey id: rules cannot hide a field, so what must stay private is
/// simply not here.
final class SharedView extends Equatable {
  const SharedView({
    required this.kind,
    required this.expiresAt,
    required this.tracking,
    this.point,
    this.accuracy,
    this.locationAt,
    this.origin,
    this.destination,
    this.finished = false,
    this.distanceMeters,
    this.routeChunks = 0,
    this.routeVersion = 0,
  });

  /// A position older than this is no longer called live. The phone sends a
  /// position at least every minute while it has one.
  static const Duration staleAfter = Duration(seconds: 90);

  /// Null when the document cannot be read: nothing is shown from a guess.
  static SharedView? read(Map<String, dynamic> data) {
    final Object? expires = data['expiresAt'];
    final Object? kind = data['kind'];
    final Object? tracking = data['tracking'];
    if (expires is! Timestamp || kind is! String || tracking is! String) {
      return null;
    }
    final Object? location = data['location'];
    final Object? lat = location is Map ? location['lat'] : null;
    final Object? lng = location is Map ? location['lng'] : null;
    final Object? accuracy = location is Map ? location['accuracy'] : null;
    final bool placed =
        lat is num &&
        lng is num &&
        JourneyPlace.validCoordinates(lat.toDouble(), lng.toDouble());
    final Object? at = data['locationAt'];
    final Object? distance = data['distanceMeters'];
    final Object? chunks = data['routeChunks'];
    final Object? version = data['routeVersion'];
    return SharedView(
      kind: kind,
      expiresAt: expires.toDate().toUtc(),
      tracking: tracking,
      point: placed ? LatLng(lat.toDouble(), lng.toDouble()) : null,
      accuracy: accuracy is num ? accuracy.toDouble() : null,
      locationAt: at is Timestamp ? at.toDate().toUtc() : null,
      origin: SharedPlace.read(data['origin']),
      destination: SharedPlace.read(data['destination']),
      finished: data['journeyStatus'] == 'finished',
      distanceMeters: distance is num ? distance.toDouble() : null,
      routeChunks: chunks is int ? chunks : 0,
      routeVersion: version is int ? version : 0,
    );
  }

  final String kind;
  final DateTime expiresAt;
  final String tracking;
  final LatLng? point;
  final double? accuracy;

  /// When the server last received a position.
  final DateTime? locationAt;
  final SharedPlace? origin;
  final SharedPlace? destination;
  final bool finished;
  final double? distanceMeters;
  final int routeChunks;
  final int routeVersion;

  bool get isJourney => kind == 'journey';

  bool expiredAt(DateTime now) => !now.isBefore(expiresAt);

  /// [heardAt] is when this device last received the document, so a recipient
  /// whose clock is behind still sees an old position called old; [offline]
  /// means it is showing a copy it could not refresh.
  SharedLiveness liveness({
    required DateTime now,
    required DateTime heardAt,
    required bool offline,
  }) {
    if (finished) return SharedLiveness.finished;
    final DateTime? at = locationAt;
    if (point == null || at == null) {
      return offline ? SharedLiveness.stale : SharedLiveness.waiting;
    }
    if (offline) return SharedLiveness.stale;
    if (tracking == 'paused') return SharedLiveness.paused;
    final bool old =
        now.difference(at) > staleAfter || now.difference(heardAt) > staleAfter;
    return old ? SharedLiveness.stale : SharedLiveness.live;
  }

  @override
  List<Object?> get props => <Object?>[
    kind,
    expiresAt,
    tracking,
    point,
    accuracy,
    locationAt,
    origin,
    destination,
    finished,
    distanceMeters,
    routeChunks,
    routeVersion,
  ];
}

/// One point of a shared route. [segment] is the recording's: a gap in it
/// stays a gap on the recipient's map.
final class SharedRoutePoint extends Equatable {
  const SharedRoutePoint({
    required this.lat,
    required this.lng,
    required this.segment,
  });

  static SharedRoutePoint? read(Object? value) {
    if (value is! Map) return null;
    final Object? lat = value['lat'];
    final Object? lng = value['lng'];
    final Object? seg = value['seg'];
    if (lat is! num || lng is! num || seg is! int) return null;
    if (!JourneyPlace.validCoordinates(lat.toDouble(), lng.toDouble())) {
      return null;
    }
    return SharedRoutePoint(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      segment: seg,
    );
  }

  final double lat;
  final double lng;
  final int segment;

  Map<String, Object> toFirestore() => <String, Object>{
    'lat': lat,
    'lng': lng,
    'seg': segment,
  };

  /// [points] as unbroken lines: no line crosses a gap.
  static List<List<LatLng>> segments(Iterable<SharedRoutePoint> points) {
    final List<List<LatLng>> lines = <List<LatLng>>[];
    int? current;
    for (final SharedRoutePoint p in points) {
      if (p.segment != current) {
        lines.add(<LatLng>[]);
        current = p.segment;
      }
      lines.last.add(LatLng(p.lat, p.lng));
    }
    return lines;
  }

  @override
  List<Object?> get props => <Object?>[lat, lng, segment];
}
