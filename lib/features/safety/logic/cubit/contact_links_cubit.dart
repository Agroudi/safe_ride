import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/safety/data/repository/contact_invite_repository.dart';

/// Which contacts accepted an invite: contact id → the digits it was for.
/// One per screen.
class ContactLinksCubit extends Cubit<Map<String, String>> {
  ContactLinksCubit(this._repository) : super(const <String, String>{}) {
    _subscription = _repository.changes.listen((_) => load());
  }

  final ContactInviteRepository _repository;
  late final StreamSubscription<void> _subscription;

  Future<void> load() async {
    final Map<String, String> links = await _repository.links();
    if (!isClosed) emit(links);
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
