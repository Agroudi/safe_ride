import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';

/// The account's trusted contacts.
sealed class ContactsState extends Equatable {
  const ContactsState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class ContactsLoading extends ContactsState {
  const ContactsLoading();
}

final class ContactsReady extends ContactsState {
  const ContactsReady(this.contacts);

  /// Alphabetical; may be empty.
  final List<TrustedContactModel> contacts;

  @override
  List<Object?> get props => <Object?>[contacts];
}

final class ContactsFailed extends ContactsState {
  const ContactsFailed(this.code);

  final ContactFailureCode code;

  @override
  List<Object?> get props => <Object?>[code];
}
