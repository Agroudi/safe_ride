import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Calling and texting stay the user's own: the platform files may let
/// SafeRide ask whether something can dial or text, and nothing more.
void main() {
  final String manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final String plist = File('ios/Runner/Info.plist').readAsStringSync();

  test('Android asks for no permission to call, text or read either', () {
    for (final String permission in <String>[
      'CALL_PHONE',
      'SEND_SMS',
      'READ_SMS',
      'RECEIVE_SMS',
      'READ_PHONE_STATE',
      'READ_CALL_LOG',
      'READ_CONTACTS',
    ]) {
      expect(
        manifest,
        isNot(contains('android.permission.$permission')),
        reason: permission,
      );
    }
  });

  test('Android may ask whether something dials (tel) or texts (sms)', () {
    final String queries = RegExp(
      r'<queries>[\s\S]*</queries>',
    ).firstMatch(manifest)![0]!;
    for (final String scheme in <String>['tel', 'sms']) {
      expect(queries, contains('android:scheme="$scheme"'), reason: scheme);
    }
  });

  test('iOS may ask the same, for tel and sms', () {
    final String schemes = RegExp(
      r'<key>LSApplicationQueriesSchemes</key>\s*<array>[\s\S]*?</array>',
    ).firstMatch(plist)![0]!;
    expect(schemes, contains('<string>tel</string>'));
    expect(schemes, contains('<string>sms</string>'));
  });
}
