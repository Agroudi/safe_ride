import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/safety/data/models/invite_failure.dart';
import 'package:safe_ride/features/safety/data/repository/contact_invite_repository.dart';
import 'package:safe_ride/features/safety/logic/states/contact_invite_state.dart';

/// Makes an invite for one contact, and accepts one. One per screen; taps
/// while it is busy are ignored.
class ContactInviteCubit extends Cubit<ContactInviteState> {
  ContactInviteCubit(this._repository) : super(const InviteIdle());

  final ContactInviteRepository _repository;

  Future<void> create(String contactId) =>
      _run(() async => InviteCreated(await _repository.create(contactId)));

  Future<void> accept(String code) =>
      _run(() async => InviteAccepted(await _repository.accept(code.trim())));

  Future<void> _run(Future<ContactInviteState> Function() work) async {
    if (state is InviteBusy) return;
    emit(const InviteBusy());
    try {
      final ContactInviteState done = await work();
      if (!isClosed) emit(done);
    } on InviteFailure catch (e) {
      if (!isClosed) emit(InviteFailed(e.code));
    } on Object {
      if (!isClosed) emit(const InviteFailed(InviteFailureCode.network));
    }
  }
}
