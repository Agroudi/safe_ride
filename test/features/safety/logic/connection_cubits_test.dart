import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/security/bearer_token.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_invite_model.dart';
import 'package:safe_ride/features/safety/data/models/connection_links.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/data/repository/connection_repository.dart';
import 'package:safe_ride/features/safety/logic/cubit/accept_connection_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/connections_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/accept_connection_state.dart';
import 'package:safe_ride/features/safety/logic/states/connections_state.dart';

final DateTime _at = DateTime.utc(2026, 11, 5);
final String _token = BearerToken.generate(Random(1));

ConnectionModel _connection(String id, ConnectionStatus status) =>
    ConnectionModel(
      ownerUid: 'sara',
      contactUid: id,
      contactName: id,
      status: status,
      inviteId: _token,
      createdAt: _at,
      acceptedAt: _at,
    );

ConnectionInviteModel _invite() => ConnectionInviteModel(
  token: _token,
  inviterUid: 'sara',
  inviterName: 'Sara Ahmed',
  status: ConnectionStatus.pending,
  createdAt: _at,
  expiresAt: _at.add(ConnectionInviteModel.lifetime),
);

class _Repository implements ConnectionRepository {
  final StreamController<void> changed = StreamController<void>.broadcast();
  List<ConnectionModel> all = <ConnectionModel>[];
  List<ConnectionInviteModel> waiting = <ConnectionInviteModel>[];
  ConnectionFailureCode? failure;
  ConnectionFailureCode? previewFailure;
  Completer<void>? hold;
  bool stale = false;
  int created = 0;
  int accepted = 0;
  final List<String> revoked = <String>[];

  Future<void> _gate() async {
    await hold?.future;
    final ConnectionFailureCode? code = failure;
    if (code != null) throw ConnectionFailure(code);
  }

  @override
  Stream<void> get changes => changed.stream;

  @override
  bool get mayBeStale => stale;

  @override
  Future<List<ConnectionModel>> connections() async {
    await _gate();
    return all;
  }

  @override
  Future<List<ConnectionInviteModel>> invites() async => waiting;

  @override
  Future<ConnectionInviteModel> createInvite() async {
    created++;
    await _gate();
    return _invite();
  }

  @override
  Future<void> cancelInvite(String token) => _gate();

  @override
  Future<ConnectionInviteModel> preview(String token) async {
    final ConnectionFailureCode? code = previewFailure;
    if (code != null) throw ConnectionFailure(code);
    return _invite();
  }

  @override
  Future<ConnectionModel> accept(String token) async {
    accepted++;
    await _gate();
    return _connection('sara', ConnectionStatus.accepted);
  }

  @override
  Future<void> revoke(String contactUid) async {
    await _gate();
    revoked.add(contactUid);
  }

  @override
  Future<void> rename(String contactUid, String? nickname) => _gate();

  @override
  Future<void> clear(String contactUid) => _gate();
}

void main() {
  late _Repository repository;

  setUp(() => repository = _Repository());

  group('ConnectionsCubit', () {
    late ConnectionsCubit cubit;

    setUp(() => cubit = ConnectionsCubit(repository));
    tearDown(() => cubit.close());

    test('sets connected and ended apart, with the invites', () async {
      repository
        ..all = <ConnectionModel>[
          _connection('omar', ConnectionStatus.accepted),
          _connection('mona', ConnectionStatus.revoked),
        ]
        ..waiting = <ConnectionInviteModel>[_invite()];
      await cubit.load();

      expect(cubit.state.phase, ConnectionsPhase.ready);
      expect(cubit.state.connected.single.contactUid, 'omar');
      expect(cubit.state.ended.single.contactUid, 'mona');
      expect(cubit.state.invites.single.token, _token);
      expect(cubit.state.find('mona')?.isActive, isFalse);
      expect(cubit.state.find('nobody'), isNull);
    });

    test('says when the list is the phone\'s copy', () async {
      repository.stale = true;
      await cubit.load();
      expect(cubit.state.mayBeStale, isTrue);
    });

    test('a list that cannot be read says why', () async {
      repository.failure = ConnectionFailureCode.unavailable;
      await cubit.load();
      expect(cubit.state.phase, ConnectionsPhase.failed);
      expect(cubit.state.failure, ConnectionFailureCode.unavailable);
    });

    test('follows a change made elsewhere', () async {
      await cubit.load();
      repository.all = <ConnectionModel>[
        _connection('omar', ConnectionStatus.accepted),
      ];
      repository.changed.add(null);
      await pumpEventQueue();
      expect(cubit.state.connected, hasLength(1));
    });

    test('answers with the failure, and is free again', () async {
      await cubit.load();
      repository.failure = ConnectionFailureCode.offline;
      expect(await cubit.revoke('omar'), ConnectionFailureCode.offline);
      expect(cubit.state.busy, isFalse);
      expect(repository.revoked, isEmpty);
    });

    test('a second tap while the first is on its way does nothing', () async {
      await cubit.load();
      repository.hold = Completer<void>();
      final Future<ConnectionFailureCode?> first = cubit.invite();
      expect(cubit.state.busy, isTrue);
      expect(await cubit.invite(), isNull);
      repository.hold!.complete();
      await first;
      expect(repository.created, 1);
      expect(cubit.state.busy, isFalse);
    });
  });

  group('AcceptConnectionCubit', () {
    late AcceptConnectionCubit cubit;

    setUp(() => cubit = AcceptConnectionCubit(repository));
    tearDown(() => cubit.close());

    test('no token asks for one', () async {
      await cubit.open(null);
      expect(cubit.state, const AcceptEntry());
    });

    test('a good invite waits for a yes: opening accepts nothing', () async {
      await cubit.open(_token);
      expect(cubit.state, const AcceptReady('Sara Ahmed'));
      expect(repository.accepted, 0);
    });

    test('signed out is its own screen', () async {
      repository.previewFailure = ConnectionFailureCode.signedOut;
      await cubit.open(_token);
      expect(cubit.state, const AcceptSignedOut());
    });

    test('an invite that cannot be used says so', () async {
      repository.previewFailure = ConnectionFailureCode.noLongerValid;
      await cubit.open(_token);
      expect(
        cubit.state,
        const AcceptFailed(ConnectionFailureCode.noLongerValid),
      );
    });

    test('pasting finds the token, or says it is not an invite', () async {
      await cubit.paste('hello');
      expect(cubit.state, const AcceptFailed(ConnectionFailureCode.invalid));
      await cubit.paste('Open this: ${ConnectionLinks.link(_token)}');
      expect(cubit.state, const AcceptReady('Sara Ahmed'));
    });

    test('done only once the server said so', () async {
      await cubit.open(_token);
      repository.hold = Completer<void>();
      final Future<void> accepting = cubit.accept();
      expect(cubit.state, const AcceptReady('Sara Ahmed', submitting: true));
      repository.hold!.complete();
      await accepting;
      expect(cubit.state, const AcceptDone('Sara Ahmed'));
    });

    test('a double tap accepts once', () async {
      await cubit.open(_token);
      repository.hold = Completer<void>();
      final Future<void> first = cubit.accept();
      await cubit.accept();
      repository.hold!.complete();
      await first;
      expect(repository.accepted, 1);
    });

    test('offline keeps the offer, and connects nobody', () async {
      await cubit.open(_token);
      repository.failure = ConnectionFailureCode.offline;
      await cubit.accept();
      expect(
        cubit.state,
        const AcceptReady('Sara Ahmed', failure: ConnectionFailureCode.offline),
      );
      repository.failure = null;
      await cubit.accept();
      expect(cubit.state, const AcceptDone('Sara Ahmed'));
    });

    test('losing the invite ends the offer', () async {
      await cubit.open(_token);
      repository.failure = ConnectionFailureCode.noLongerValid;
      await cubit.accept();
      expect(
        cubit.state,
        const AcceptFailed(ConnectionFailureCode.noLongerValid),
      );
    });

    test('a lost check can be tried again, and start over', () async {
      repository.previewFailure = ConnectionFailureCode.offline;
      await cubit.open(_token);
      repository.previewFailure = null;
      await cubit.retry();
      expect(cubit.state, const AcceptReady('Sara Ahmed'));
      cubit.startOver();
      expect(cubit.state, const AcceptEntry());
    });

    test('accepting before an offer does nothing', () async {
      await cubit.open(null);
      await cubit.accept();
      expect(repository.accepted, 0);
    });
  });
}
