import 'package:safe_ride/core/constants/public_links.dart';
import 'package:safe_ride/core/security/bearer_token.dart';

/// Where an invite can be opened. The token goes after `#`, which browsers
/// never send to a server or in a Referer.
abstract final class ConnectionLinks {
  /// In the invite page, so a page of another site is never taken for it.
  static const String pageMarker = 'saferide-invite-page';

  static const String path = '/c';

  static final RegExp _inText = RegExp(
    r'(?:^|[^A-Za-z0-9_-])([A-Za-z0-9_-]{43})(?![A-Za-z0-9_-])',
  );

  static String link(String token) => '${PublicLinks.base}$path#$token';

  /// The token of a link, when it holds a well-formed one.
  static String? tokenOf(Uri uri) =>
      BearerToken.isValid(uri.fragment) ? uri.fragment : null;

  /// The token in what someone pasted: the link, the whole message around it,
  /// or the token alone.
  static String? tokenIn(String text) =>
      _inText.firstMatch(text.trim())?.group(1);
}
