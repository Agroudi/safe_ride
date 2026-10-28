import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Salted PBKDF2-HMAC-SHA256 for the demo accounts, run on a background
/// isolate so the UI keeps its frames while it works.
///
/// ⚠️ **Demo-grade, not production.** [defaultIterations] is far below what
/// a server would use (pure Dart is slow), and a hash on a phone can be
/// attacked offline by anyone who extracts it. It exists so a password is
/// never stored in plaintext — not to make local accounts secure.
class PasswordHasher {
  const PasswordHasher({this.iterations = defaultIterations});

  /// About 0.2 s on a laptop, an estimated ~0.5 s on a mid-range phone.
  static const int defaultIterations = 30000;

  static const int _saltBytes = 16;

  /// The rounds new hashes are made with.
  final int iterations;

  /// A fresh random salt.
  Uint8List newSalt() {
    final Random random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_saltBytes, (_) => random.nextInt(256)),
    );
  }

  /// The 32-byte key for [password] and [salt]. [rounds] defaults to
  /// [iterations]; pass a stored account's own count to verify it.
  Future<Uint8List> derive(String password, List<int> salt, {int? rounds}) {
    final int n = rounds ?? iterations;
    final List<int> key = utf8.encode(password);
    final List<int> s = List<int>.of(salt);
    return Isolate.run(() => _pbkdf2(key, s, n));
  }

  /// True when [a] and [b] are equal, in a time that does not depend on
  /// where they first differ.
  static bool same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// One output block (32 bytes, SHA-256's size), so a single `T_1`.
  static Uint8List _pbkdf2(List<int> password, List<int> salt, int rounds) {
    final Hmac mac = Hmac(sha256, password);
    List<int> u = mac.convert(<int>[...salt, 0, 0, 0, 1]).bytes;
    final Uint8List out = Uint8List.fromList(u);
    for (int i = 1; i < rounds; i++) {
      u = mac.convert(u).bytes;
      for (int j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }
}
