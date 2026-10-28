import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/session/session_reader.dart';

/// Home greets the first name — without cutting a compound name in half.
void main() {
  String? first(String fullName) =>
      SessionUser(id: 'x', fullName: fullName).firstName;

  test('the first word of an ordinary name', () {
    expect(first('Sara Ahmed'), 'Sara');
    expect(first('  Omar   Khaled '), 'Omar');
    expect(first('Mona'), 'Mona');
  });

  test('a prefix that is half a name keeps its second half', () {
    expect(first('عبد الرحمن محمد'), 'عبد الرحمن');
    expect(first('Abdel Rahman Ali'), 'Abdel Rahman');
    expect(first('abdul Aziz'), 'abdul Aziz');
    expect(first('أبو بكر'), 'أبو بكر');
  });

  test('a lone prefix is still a name', () {
    expect(first('Abdel'), 'Abdel');
  });

  test('no name, no first name', () {
    expect(first(''), isNull);
    expect(first('   '), isNull);
  });
}
