import 'dart:async';

import 'package:safe_ride/core/safety/escalation_gate.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_invite_model.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/connection_repository.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/data/repository/trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/data/repository/message_composer.dart';

/// The escalation lifecycle, decided by the test.
class FakeGate implements EscalationGate {
  OpenEscalation? open;
  final List<String> resolved = <String>[];
  Completer<void>? hold;
  final StreamController<void> _changed = StreamController<void>.broadcast();

  @override
  Stream<void> get changed => _changed.stream;

  @override
  Future<OpenEscalation?> latestOpen() async => open;

  @override
  Future<OpenEscalation?> openFor(String journeyId) async => open;

  @override
  Future<ResolveOutcome> resolveSafe(String checkId) async {
    await hold?.future;
    resolved.add(checkId);
    final bool was = open?.checkId == checkId;
    open = null;
    _changed.add(null);
    return was ? ResolveOutcome.resolved : ResolveOutcome.notOpen;
  }
}

/// Connections, decided by the test.
class FakeConnections implements ConnectionRepository {
  List<ConnectionModel> all = <ConnectionModel>[];
  List<ConnectionInviteModel> waiting = <ConnectionInviteModel>[];
  ConnectionFailureCode? failure;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  bool get mayBeStale => false;

  @override
  Future<List<ConnectionModel>> connections() async {
    final ConnectionFailureCode? f = failure;
    if (f != null) throw ConnectionFailure(f);
    return all;
  }

  @override
  Future<List<ConnectionInviteModel>> invites() async => waiting;

  @override
  Future<ConnectionInviteModel> createInvite() => throw UnimplementedError();

  @override
  Future<void> cancelInvite(String token) => throw UnimplementedError();

  @override
  Future<ConnectionInviteModel> preview(String token) =>
      throw UnimplementedError();

  @override
  Future<ConnectionModel> accept(String token) => throw UnimplementedError();

  @override
  Future<void> revoke(String contactUid) => throw UnimplementedError();

  @override
  Future<void> rename(String contactUid, String? nickname) =>
      throw UnimplementedError();

  @override
  Future<void> clear(String contactUid) => throw UnimplementedError();
}

/// Saved numbers, decided by the test.
class FakeContacts implements TrustedContactsRepository {
  List<TrustedContactModel> all = <TrustedContactModel>[];

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<List<TrustedContactModel>> contacts() async => all;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Never dials: records what it was asked to open.
/// A messaging app that never opens: it writes down what it was handed.
/// Nothing is ever sent from a test.
class RecordingComposer implements MessageComposer {
  ComposeOutcome outcome = ComposeOutcome.opened;
  final List<(String, String)> composed = <(String, String)>[];

  @override
  Future<ComposeOutcome> compose(String number, String body) async {
    composed.add((number, body));
    return outcome;
  }
}

class RecordingDialer implements PhoneDialer {
  DialOutcome outcome = DialOutcome.opened;
  final List<String> opened = <String>[];

  @override
  Future<DialOutcome> open(String number) async {
    opened.add(number);
    return outcome;
  }
}
