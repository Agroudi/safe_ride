import 'dart:convert';
import 'dart:math';

/// A bearer credential: 256 random bits, as the id of the one document it
/// opens. Whoever holds it can use it, so it is never logged and never put
/// anywhere but its link and its owner's own record. A share's link and a
/// connection invite are both one.
abstract final class BearerToken {
  static const int bytes = 32;

  static final RegExp _shape = RegExp(r'^[A-Za-z0-9_-]{43}$');

  /// [random] is for tests: only `Random.secure` may make a real one.
  static String generate([Random? random]) {
    final Random source = random ?? Random.secure();
    final List<int> raw = <int>[
      for (int i = 0; i < bytes; i++) source.nextInt(256),
    ];
    return base64Url.encode(raw).replaceAll('=', '');
  }

  static bool isValid(String? token) => token != null && _shape.hasMatch(token);
}
