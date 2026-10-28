import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/data/models/user_model.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/cubit/account_cubit.dart';
import 'package:safe_ride/features/authentication/logic/cubit/auth_cubit.dart';
import 'package:safe_ride/features/authentication/logic/states/account_state.dart';
import 'package:safe_ride/features/authentication/logic/states/auth_state.dart';

final UserModel _sara = UserModel(
  fullName: 'Sara Ahmed',
  email: 'sara@example.com',
  createdAt: DateTime.utc(2026),
);

/// Answers each call with whatever [answer] holds — a user, a failure, or a
/// completer the test finishes later — and counts the calls.
class _Repository extends Fake implements AuthRepository {
  Completer<UserModel>? pending;
  AuthFailure? failure;
  UserModel? user = _sara;
  int calls = 0;
  int logouts = 0;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  Future<UserModel> _answer() {
    calls++;
    final Completer<UserModel>? wait = pending;
    if (wait != null) return wait.future;
    final AuthFailure? f = failure;
    return f != null
        ? Future<UserModel>.error(f)
        : Future<UserModel>.value(_sara);
  }

  @override
  Future<UserModel> login({required String email, required String password}) =>
      _answer();

  @override
  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) => _answer();

  @override
  Future<UserModel?> currentUser() async {
    final AuthFailure? f = failure;
    if (f != null) throw f;
    return user;
  }

  @override
  Future<void> logout() async {
    logouts++;
    final AuthFailure? f = failure;
    if (f != null) throw f;
  }

  @override
  Future<UserModel> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    final AuthFailure? f = failure;
    if (f != null) throw f;
    final UserModel updated = user!.copyWith(fullName: fullName, phone: phone);
    user = updated;
    _changes.add(null);
    return updated;
  }
}

void main() {
  group('AuthCubit', () {
    test('login: submitting, then succeeded with the user', () async {
      final AuthCubit cubit = AuthCubit(_Repository());
      final Future<List<AuthState>> states = cubit.stream.take(2).toList();

      await cubit.login(email: 'sara@example.com', password: 'Secret123');

      expect(await states, <AuthState>[
        const AuthSubmitting(),
        AuthSucceeded(_sara),
      ]);
      await cubit.close();
    });

    test('a failure is reported by code', () async {
      final _Repository repository = _Repository()
        ..failure = const AuthFailure(AuthFailureCode.wrongPassword);
      final AuthCubit cubit = AuthCubit(repository);

      await cubit.login(email: 'sara@example.com', password: 'nope');

      expect(cubit.state, const AuthFailed(AuthFailureCode.wrongPassword));
      await cubit.close();
    });

    test('a second submit while one runs is dropped', () async {
      final _Repository repository = _Repository()
        ..pending = Completer<UserModel>();
      final AuthCubit cubit = AuthCubit(repository);

      final Future<void> first = cubit.register(
        fullName: 'Sara Ahmed',
        email: 'sara@example.com',
        password: 'Secret123',
      );
      await cubit.register(
        fullName: 'Sara Ahmed',
        email: 'sara@example.com',
        password: 'Secret123',
      );
      expect(repository.calls, 1);

      repository.pending!.complete(_sara);
      await first;
      expect(cubit.state, AuthSucceeded(_sara));
      await cubit.close();
    });

    test('a retry after a failure goes through', () async {
      final _Repository repository = _Repository()
        ..failure = const AuthFailure(AuthFailureCode.storage);
      final AuthCubit cubit = AuthCubit(repository);

      await cubit.login(email: 'sara@example.com', password: 'Secret123');
      repository.failure = null;
      await cubit.login(email: 'sara@example.com', password: 'Secret123');

      expect(repository.calls, 2);
      expect(cubit.state, AuthSucceeded(_sara));
      await cubit.close();
    });
  });

  group('AccountCubit', () {
    test('loads the signed-in user', () async {
      final AccountCubit cubit = AccountCubit(_Repository());
      await cubit.load();
      expect(cubit.state, AccountReady(_sara));
      await cubit.close();
    });

    test('nobody signed in reads as signed out', () async {
      final AccountCubit cubit = AccountCubit(_Repository()..user = null);
      await cubit.load();
      expect(cubit.state, const AccountSignedOut());
      await cubit.close();
    });

    test('sign-out: busy, then signed out', () async {
      final _Repository repository = _Repository();
      final AccountCubit cubit = AccountCubit(repository);
      await cubit.load();
      final Future<List<AccountState>> states = cubit.stream.take(2).toList();

      await cubit.signOut();

      expect(await states, <AccountState>[
        AccountReady(_sara, signingOut: true),
        const AccountSignedOut(),
      ]);
      expect(repository.logouts, 1);
      await cubit.close();
    });

    test('a failed sign-out keeps the user on screen', () async {
      final _Repository repository = _Repository();
      final AccountCubit cubit = AccountCubit(repository);
      await cubit.load();
      repository.failure = const AuthFailure(AuthFailureCode.storage);

      await cubit.signOut();

      expect(cubit.state, AccountFailed(AuthFailureCode.storage, user: _sara));
      await cubit.close();
    });

    test('a saved profile edit reloads the account', () async {
      final _Repository repository = _Repository();
      final AccountCubit cubit = AccountCubit(repository);
      await cubit.load();
      final Future<AccountState> next = cubit.stream.first;

      final AuthFailureCode? failure = await cubit.updateProfile(
        fullName: 'Sara Al-Harbi',
      );

      expect(failure, isNull);
      expect(
        await next,
        AccountReady(_sara.copyWith(fullName: 'Sara Al-Harbi')),
      );
      await cubit.close();
    });

    test('a failed profile edit returns its code', () async {
      final _Repository repository = _Repository();
      final AccountCubit cubit = AccountCubit(repository);
      await cubit.load();
      repository.failure = const AuthFailure(AuthFailureCode.storage);

      expect(
        await cubit.updateProfile(fullName: 'Sara'),
        AuthFailureCode.storage,
      );
      expect(cubit.state, AccountReady(_sara));
      await cubit.close();
    });
  });
}
