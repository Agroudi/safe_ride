import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/logic/states/contact_form_state.dart';

/// Adds a trusted contact, or loads, saves and deletes one. One per screen;
/// a second tap while it is busy is dropped.
class ContactFormCubit extends Cubit<ContactFormState> {
  ContactFormCubit(this._repository) : super(const ContactFormReady());

  final TrustedContactsRepository _repository;

  TrustedContactModel? get _contact => switch (state) {
    ContactFormReady(:final TrustedContactModel? contact) => contact,
    ContactFormBusy(:final TrustedContactModel? contact) => contact,
    ContactFormFailed(:final TrustedContactModel? contact) => contact,
    _ => null,
  };

  /// Editing: reads the contact. Adding needs no call.
  Future<void> load(String id) async {
    emit(const ContactFormLoading());
    try {
      final TrustedContactModel? contact = await _repository.contact(id);
      if (isClosed) return;
      emit(
        contact == null
            ? const ContactFormMissing()
            : ContactFormReady(contact: contact),
      );
    } on ContactFailure catch (e) {
      if (!isClosed) emit(ContactFormFailed(e.code));
    }
  }

  Future<void> save({
    required String fullName,
    required String phone,
    String? relationship,
  }) => _run(() async {
    final TrustedContactModel? editing = _contact;
    if (editing == null) {
      await _repository.add(
        fullName: fullName,
        phone: phone,
        relationship: relationship,
      );
    } else {
      await _repository.update(
        editing.id,
        fullName: fullName,
        phone: phone,
        relationship: relationship,
      );
    }
    return const ContactFormSaved();
  });

  Future<void> delete() => _run(() async {
    final TrustedContactModel? editing = _contact;
    if (editing != null) await _repository.delete(editing.id);
    return const ContactFormDeleted();
  });

  Future<void> _run(Future<ContactFormState> Function() body) async {
    if (state is ContactFormBusy || state is ContactFormLoading) return;
    final TrustedContactModel? contact = _contact;
    emit(ContactFormBusy(contact: contact));
    try {
      final ContactFormState done = await body();
      if (!isClosed) emit(done);
    } on ContactFailure catch (e) {
      if (!isClosed) emit(ContactFormFailed(e.code, contact: contact));
    }
  }
}
