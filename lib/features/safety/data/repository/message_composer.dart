import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// What happened when SafeRide asked the phone to write a text. Never
/// "sent": SafeRide only opens the messaging app with the text ready; the
/// user edits it, sends it — or doesn't — where SafeRide cannot see.
enum ComposeOutcome {
  /// The messaging app opened with the recipient and the text ready.
  opened,

  /// The number is not one SafeRide will hand to the messaging app.
  invalidNumber,

  /// Nothing on this device writes text messages (a tablet, for one).
  noMessaging,

  /// The messaging app could not be opened.
  failed,
}

/// Opens the messaging app with a recipient and an editable text — the
/// platform end of messaging. `UrlLauncherMessageComposer` implements it;
/// screens go through `CallLauncher`, which prepares the number first.
/// Nothing is ever sent by SafeRide: no SMS permission, no SMS API.
abstract interface class MessageComposer {
  Future<ComposeOutcome> compose(String number, String body);
}

/// [MessageComposer] over `url_launcher`'s `sms:` (Android's ACTION_VIEW to
/// the messaging app, iOS's Messages). The manifest's `<queries>` and iOS's
/// `LSApplicationQueriesSchemes` let it ask first whether anything can text.
class UrlLauncherMessageComposer implements MessageComposer {
  const UrlLauncherMessageComposer();

  /// The `sms:` link for [number] with [body]. Android reads the text from a
  /// `?body=` query; iOS's Messages from `&body=` after the number. The text
  /// is percent-encoded either way, so a space is never a `+`. No body: the
  /// messaging app opens empty.
  static Uri link(String number, String body, {required bool ios}) => Uri.parse(
    body.isEmpty
        ? 'sms:$number'
        : 'sms:$number${ios ? '&' : '?'}body=${Uri.encodeComponent(body)}',
  );

  @override
  Future<ComposeOutcome> compose(String number, String body) async {
    final Uri uri = link(
      number,
      body,
      ios: defaultTargetPlatform == TargetPlatform.iOS,
    );
    try {
      if (!await canLaunchUrl(Uri(scheme: 'sms', path: number))) {
        return ComposeOutcome.noMessaging;
      }
      return await launchUrl(uri, mode: LaunchMode.externalApplication)
          ? ComposeOutcome.opened
          : ComposeOutcome.failed;
    } on Object {
      return ComposeOutcome.failed;
    }
  }
}
