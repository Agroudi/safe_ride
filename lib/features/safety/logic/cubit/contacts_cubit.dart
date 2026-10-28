import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/logic/states/contacts_state.dart';

/// The trusted-contacts list: loads, and reloads after every change the
/// repository reports (a contact deleted on the form disappears at once).
/// One per screen.
class ContactsCubit extends Cubit<ContactsState> {
  ContactsCubit(this._repository) : super(const ContactsLoading()) {
    _subscription = _repository.changes.listen((_) => load());
  }

  final TrustedContactsRepository _repository;
  late final StreamSubscription<void> _subscription;

  Future<void> load() async {
    try {
      final List<TrustedContactModel> all = await _repository.contacts();
      if (!isClosed) emit(ContactsReady(all));
    } on ContactFailure catch (e) {
      if (!isClosed) emit(ContactsFailed(e.code));
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
