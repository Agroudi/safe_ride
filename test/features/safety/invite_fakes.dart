import 'dart:async';

import 'package:safe_ride/features/safety/data/models/invite_failure.dart';
import 'package:safe_ride/features/safety/data/repository/contact_invite_repository.dart';

/// The invite backend, decided by the test; no function is ever called.
class FakeInvites implements ContactInviteRepository {
  FakeInvites({Map<String, String>? linked})
    : linked = linked ?? <String, String>{};

  /// Contact id → the digits it was accepted for.
  final Map<String, String> linked;
  final List<String> created = <String>[];
  final List<String> accepted = <String>[];
  final StreamController<void> changed = StreamController<void>.broadcast();

  /// Makes the next calls fail.
  InviteFailureCode? failure;

  /// Holds a call open until completed.
  Completer<void>? hold;

  Future<void> _gate() async {
    await hold?.future;
    final InviteFailureCode? code = failure;
    if (code != null) throw InviteFailure(code);
  }

  @override
  Future<ContactInvite> create(String contactId) async {
    created.add(contactId);
    await _gate();
    return ContactInvite(
      code: 'ABCDE-23456',
      expiresAt: DateTime.utc(2026, 11, 7, 10),
    );
  }

  @override
  Future<String> accept(String code) async {
    accepted.add(code);
    await _gate();
    return 'Sara Ahmed';
  }

  @override
  Future<Map<String, String>> links() async => linked;

  @override
  Stream<void> get changes => changed.stream;
}
