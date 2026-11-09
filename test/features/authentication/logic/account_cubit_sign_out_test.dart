import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/account/sign_out_step.dart';
import 'package:safe_ride/core/push/push_notifications.dart';
import 'package:safe_ride/features/authentication/data/models/user_model.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/cubit/account_cubit.dart';
import 'package:safe_ride/features/authentication/logic/states/account_state.dart';

class _Auth extends Fake implements AuthRepository {
  _Auth(this.calls);

  final List<String> calls;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<UserModel?> currentUser() async => UserModel(
    fullName: 'Sara Ahmed',
    email: 'sara@example.com',
    createdAt: DateTime.utc(2026),
  );

  @override
  Future<void> logout() async => calls.add('logout');
}

class _Device extends Fake implements DeviceRegistration {
  _Device(this.calls);

  final List<String> calls;

  @override
  Future<void> unregister() async => calls.add('unregister');
}

class _Step implements SignOutStep {
  _Step(this.calls);

  final List<String> calls;

  @override
  Future<void> beforeSignOut() async => calls.add('step');
}

void main() {
  test('a share ends while the account can still end it', () async {
    final List<String> calls = <String>[];
    final AccountCubit cubit = AccountCubit(
      _Auth(calls),
      _Device(calls),
      signOutSteps: <SignOutStep>[_Step(calls)],
    );
    await cubit.load();
    await cubit.signOut();
    expect(calls, <String>['step', 'unregister', 'logout']);
    expect(cubit.state, isA<AccountSignedOut>());
    await cubit.close();
  });
}
