import 'package:url_launcher/url_launcher.dart';

/// What happened when SafeRide asked the phone to dial. Never "called".
///
/// Six things happen between a tap on Call and help arriving, and SafeRide
/// sees only the first two: (1) the number is prepared ([DialNumber]);
/// (2) the phone app opens with it ready ([opened]). Then, outside SafeRide:
/// (3) the user presses call — or cancels; (4) the system may log the call,
/// which SafeRide never reads (no phone-state permission); (5) the call
/// connects; (6) a service answers and responds. SafeRide can report (1) and
/// (2) only, and no copy may suggest more.
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

/// A number as the phone app should receive it: the spaces, dashes, dots and
/// brackets people type taken out, then digits only (an optional leading
/// `+`), 2 to 15 of them. Anything else is never handed over.
abstract final class DialNumber {
  static final RegExp _typed = RegExp(r'[\s\-().]');

  /// [raw] ready to dial, or null when it is empty or malformed.
  static String? prepare(String raw) {
    final String number = raw.replaceAll(_typed, '');
    return UrlLauncherPhoneDialer.isDialable(number) ? number : null;
  }
}

/// Opens the phone app with a number filled in — the platform end of
/// calling. `UrlLauncherPhoneDialer` implements it; screens go through
/// `CallLauncher`, which prepares the number first. Nothing dials by itself.
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
