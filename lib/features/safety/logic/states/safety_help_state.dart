import 'package:equatable/equatable.dart';
import 'package:safe_ride/core/safety/escalation_gate.dart';
import 'package:safe_ride/features/safety/data/models/contact_reach.dart';

/// A connected person, as the help screen needs them: a name, nothing else.
final class HelpConnection extends Equatable {
  const HelpConnection(this.name);

  final String name;

  @override
  List<Object?> get props => <Object?>[name];
}

/// A saved number, without the number: the screen offers Call and Message
/// when [reach] allows them, and only the phone or messaging app shows the
/// number itself.
final class HelpSavedContact extends Equatable {
  const HelpSavedContact({
    required this.id,
    required this.name,
    this.relationship,
    this.reach = ContactReach.available,
  });

  final String id;
  final String name;
  final String? relationship;
  final ContactReach reach;

  @override
  List<Object?> get props => <Object?>[id, name, relationship, reach];
}

final class SafetyHelpState extends Equatable {
  const SafetyHelpState({
    this.loading = true,
    this.escalation,
    this.connected = const <HelpConnection>[],
    this.saved = const <HelpSavedContact>[],
    this.connectionsFailed = false,
    this.savedFailed = false,
    this.resolving = false,
    this.reaching,
  });

  final bool loading;

  /// The safety check nobody answered that is still open, if any.
  final OpenEscalation? escalation;

  /// People connected by an invite. Pending invitations and ended
  /// connections are not here: they are not people the user is connected to.
  final List<HelpConnection> connected;
  final List<HelpSavedContact> saved;
  final bool connectionsFailed;
  final bool savedFailed;

  /// "I'm okay" is being recorded.
  final bool resolving;

  /// The saved contact whose phone or messaging app is opening.
  final String? reaching;

  SafetyHelpState copyWith({
    bool? loading,
    OpenEscalation? Function()? escalation,
    List<HelpConnection>? connected,
    List<HelpSavedContact>? saved,
    bool? connectionsFailed,
    bool? savedFailed,
    bool? resolving,
    String? Function()? reaching,
  }) => SafetyHelpState(
    loading: loading ?? this.loading,
    escalation: escalation == null ? this.escalation : escalation(),
    connected: connected ?? this.connected,
    saved: saved ?? this.saved,
    connectionsFailed: connectionsFailed ?? this.connectionsFailed,
    savedFailed: savedFailed ?? this.savedFailed,
    resolving: resolving ?? this.resolving,
    reaching: reaching == null ? this.reaching : reaching(),
  );

  @override
  List<Object?> get props => <Object?>[
    loading,
    escalation?.checkId,
    connected,
    saved,
    connectionsFailed,
    savedFailed,
    resolving,
    reaching,
  ];
}
