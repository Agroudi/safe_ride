/// Something that keeps data for an account and must let go of it when the
/// account is deleted. The service locator lists them, in order, for
/// `AuthRepository.deleteAccount`; running one twice is harmless, so a
/// deletion that failed half way can simply be tried again.
abstract interface class AccountData {
  Future<void> erase(String uid);
}
