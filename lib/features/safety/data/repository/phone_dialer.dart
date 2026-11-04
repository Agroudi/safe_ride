import 'package:url_launcher/url_launcher.dart';

/// What happened when SafeRide asked the phone to dial. Never "called":
/// SafeRide only opens the phone app with the number; whether the call is
/// placed and answered happens outside it, where it cannot see.
enum DialOutcome {
  /// The phone app opened with the number ready; the user presses call.
  opened,

  /// The number is not one SafeRide will hand to the phone app.
  invalidNumber,

  /// This device has nothing that dials (a tablet, a phone without one).
  noDialer,

  /// The phone app could not be opened.
  failed,
}

/// Opens the phone app with a number filled in — the calling service.
/// `UrlLauncherPhoneDialer` implements it; nothing ever dials by itself.
abstract interface class PhoneDialer {
  Future<DialOutcome> open(String number);
}

/// [PhoneDialer] over `url_launcher`'s `tel:` (Android's ACTION_VIEW to the
/// dialer, iOS's call prompt). The manifest's `<queries>` and iOS's
/// `LSApplicationQueriesSchemes` let it ask first whether anything dials.
class UrlLauncherPhoneDialer implements PhoneDialer {
  const UrlLauncherPhoneDialer();

  static final RegExp _number = RegExp(r'^\+?[0-9]{2,15}$');

  /// Digits only (an optional leading `+`), 2 to 15 of them.
  static bool isDialable(String number) => _number.hasMatch(number);

  @override
  Future<DialOutcome> open(String number) async {
    if (!isDialable(number)) return DialOutcome.invalidNumber;
    final Uri uri = Uri(scheme: 'tel', path: number);
    try {
      if (!await canLaunchUrl(uri)) return DialOutcome.noDialer;
      return await launchUrl(uri, mode: LaunchMode.externalApplication)
          ? DialOutcome.opened
          : DialOutcome.failed;
    } on Object {
      return DialOutcome.failed;
    }
  }
}
