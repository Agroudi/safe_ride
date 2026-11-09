import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';

/// Whether a saved number can be called or texted from SafeRide — said
/// before anyone taps, so a button is never offered that cannot work.
///
/// Only numbers the user saved themselves are ever reachable: a connection
/// (Batch 17) shares a name and nothing else, so a connected account has no
/// number here at all, by design.
enum ContactReach {
  /// A number the phone app and the messaging app will take.
  available,

  /// No number saved.
  missing,

  /// A number SafeRide won't hand over (too long, letters, …): the user can
  /// still dial it by hand.
  invalid;

  static ContactReach of(String? phone) {
    if (phone == null || phone.trim().isEmpty) return ContactReach.missing;
    return DialNumber.prepare(phone) == null
        ? ContactReach.invalid
        : ContactReach.available;
  }
}
