import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/safety/data/models/contact_reach.dart';

void main() {
  test('no number saved is missing', () {
    for (final String? none in <String?>[null, '', '   ']) {
      expect(ContactReach.of(none), ContactReach.missing, reason: '$none');
    }
  });

  test('a number as people type it is available', () {
    for (final String ok in <String>[
      '+966 55 000 0001',
      '055-000-0001',
      '(055) 000 0001',
      '0550000001',
    ]) {
      expect(ContactReach.of(ok), ContactReach.available, reason: ok);
    }
  });

  test('a number SafeRide will not hand over is invalid — never a button '
      'that cannot work', () {
    for (final String bad in <String>[
      '12a4',
      '5',
      '+966 55 000 0001 234 5', // 16 digits: the form allows up to 20
      '++966550000001',
    ]) {
      expect(ContactReach.of(bad), ContactReach.invalid, reason: bad);
    }
  });
}
