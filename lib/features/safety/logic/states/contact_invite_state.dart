import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/safety/data/models/invite_failure.dart';
import 'package:safe_ride/features/safety/data/repository/contact_invite_repository.dart';

sealed class ContactInviteState extends Equatable {
  const ContactInviteState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class InviteIdle extends ContactInviteState {
  const InviteIdle();
}

final class InviteBusy extends ContactInviteState {
  const InviteBusy();
}

final class InviteCreated extends ContactInviteState {
  const InviteCreated(this.invite);

  final ContactInvite invite;

  @override
  List<Object?> get props => <Object?>[invite.code];
}

/// Accepted: [ownerName] can now reach this user with an alert.
final class InviteAccepted extends ContactInviteState {
  const InviteAccepted(this.ownerName);

  final String ownerName;

  @override
  List<Object?> get props => <Object?>[ownerName];
}

final class InviteFailed extends ContactInviteState {
  const InviteFailed(this.code);

  final InviteFailureCode code;

  @override
  List<Object?> get props => <Object?>[code];
}
