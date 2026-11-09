/// Something that must finish before the session ends, while the account can
/// still act. It never blocks signing out: a step that fails is the step's
/// own problem.
abstract interface class SignOutStep {
  Future<void> beforeSignOut();
}
