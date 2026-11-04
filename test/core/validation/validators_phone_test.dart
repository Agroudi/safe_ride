import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/validation/validators.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  EasyLocalization.logger.enableBuildModes = [];

  testWidgets('a number needs seven real digits, as the rules do', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'locale': 'en'});
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    late Validators v;
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: AppLocales.supported,
        fallbackLocale: AppLocales.fallback,
        path: AppLocales.translationsPath,
        child: Builder(
          builder: (BuildContext context) {
            v = Validators.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(v.phone('1------'), isNotNull);
    expect(v.phone('+1 (2) 3-4'), isNotNull);
    expect(v.phone('+966 50 123 4567'), isNull);
    expect(v.phone('0501234'), isNull);
    expect(v.phone(''), isNull);
  });
}
