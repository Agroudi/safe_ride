import 'package:equatable/equatable.dart';
import 'package:safe_ride/core/safety/emergency_position.dart';

/// Where the user is, as the emergency screens show it. [now] moves on a
/// clock, so a reading's age — and whether it is current — is always as of
/// now, never as of when it was read.
final class EmergencyLocationState extends Equatable {
  const EmergencyLocationState({
    required this.now,
    this.loading = true,
    this.position,
    this.locating = false,
    this.notFound = false,
  });

  final DateTime now;
  final bool loading;
  final EmergencyPosition? position;

  /// A reading asked for by the user is under way.
  final bool locating;

  /// The last reading asked for came back with nothing.
  final bool notFound;

  PositionReading? get reading => position?.reading;

  EmergencyLocationState copyWith({
    DateTime? now,
    bool? loading,
    EmergencyPosition? position,
    bool? locating,
    bool? notFound,
  }) => EmergencyLocationState(
    now: now ?? this.now,
    loading: loading ?? this.loading,
    position: position ?? this.position,
    locating: locating ?? this.locating,
    notFound: notFound ?? this.notFound,
  );

  @override
  List<Object?> get props => <Object?>[
    now,
    loading,
    position?.access,
    reading?.latitude,
    reading?.longitude,
    reading?.at,
    reading?.accuracy,
    position?.destination,
    locating,
    notFound,
  ];
}
