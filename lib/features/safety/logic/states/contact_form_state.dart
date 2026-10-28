import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';

/// Adding or editing one trusted contact.
sealed class ContactFormState extends Equatable {
  const ContactFormState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Editing: the contact is being read.
final class ContactFormLoading extends ContactFormState {
  const ContactFormLoading();
}

/// Ready to fill or change; [contact] null when adding.
final class ContactFormReady extends ContactFormState {
  const ContactFormReady({this.contact});

  final TrustedContactModel? contact;

  @override
  List<Object?> get props => <Object?>[contact];
}

/// Save (or delete) is running; the form is locked.
final class ContactFormBusy extends ContactFormState {
  const ContactFormBusy({this.contact});

  final TrustedContactModel? contact;

  @override
  List<Object?> get props => <Object?>[contact];
}

final class ContactFormSaved extends ContactFormState {
  const ContactFormSaved();
}

final class ContactFormDeleted extends ContactFormState {
  const ContactFormDeleted();
}

/// The contact to edit does not exist (a stale link).
final class ContactFormMissing extends ContactFormState {
  const ContactFormMissing();
}

/// Recoverable: the form keeps what was typed.
final class ContactFormFailed extends ContactFormState {
  const ContactFormFailed(this.code, {this.contact});

  final ContactFailureCode code;
  final TrustedContactModel? contact;

  @override
  List<Object?> get props => <Object?>[code, contact];
}
