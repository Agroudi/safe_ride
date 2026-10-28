import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';

/// Form rules, returning a translated message or `null` when the value is fine.
///
/// Use as `Validators.of(context).password` in an `AppTextField(validator: …)`.
/// Adjust the patterns and limits here per project — every form reads them from
/// this one place.
class Validators {
  const Validators._(this._languageCode);

  /// Reads the locale so length messages print their number in the locale's
  /// own digits («٨ أحرف», not «8 أحرف»).
  factory Validators.of(BuildContext context) =>
      Validators._(context.locale.languageCode);

  final String _languageCode;

  static const int passwordMin = 8;
  static const int passwordMax = 128;
  static const int fullNameMax = 200;
  static const int placeMax = 120;
  static const int relationshipMax = 40;

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s.]+(?:\.[^@\s.]+)+$');
  static final RegExp _phone = RegExp(r'^\+?[0-9][0-9\s\-()]{6,19}$');
  static final RegExp _digit = RegExp('[0-9]');
  static final RegExp _uppercase = RegExp('[A-Z]');

  String? required(String? value) => (value == null || value.trim().isEmpty)
      ? 'validation.required'.tr()
      : null;

  String? email(String? value) =>
      required(value) ??
      (_email.hasMatch(value!.trim().toLowerCase())
          ? null
          : 'validation.email'.tr());

  /// Whitespace is collapsed first, so "  a  " is one letter, not five.
  String? fullName(String? value) {
    final String cleaned = (value ?? '').split(RegExp(r'\s+')).join(' ').trim();
    if (cleaned.length < 2) return 'validation.fullName'.tr();
    if (cleaned.length > fullNameMax) {
      return _length('validation.maxLength', fullNameMax);
    }
    return null;
  }

  /// Optional: empty is fine, anything typed has to look like a number.
  String? phone(String? value) {
    final String entry = (value ?? '').trim();
    if (entry.isEmpty) return null;
    return _phone.hasMatch(entry) ? null : 'validation.phone'.tr();
  }

  /// 8–128 characters, at least one digit and one uppercase letter, checked in
  /// that order so the first unmet rule is the one shown.
  String? password(String? value) {
    final String entry = value ?? '';
    if (entry.isEmpty) return 'validation.required'.tr();
    if (entry.length < passwordMin) {
      return _length('validation.minLength', passwordMin);
    }
    if (entry.length > passwordMax) {
      return _length('validation.maxLength', passwordMax);
    }
    if (!_digit.hasMatch(entry)) return 'validation.passwordDigit'.tr();
    if (!_uppercase.hasMatch(entry)) return 'validation.passwordUppercase'.tr();
    return null;
  }

  /// [password] is read at validation time, not captured when the form is
  /// built — otherwise it would compare against an empty string forever.
  FormFieldValidator<String> confirm(String Function() password) =>
      (String? value) => (value ?? '') == password()
      ? null
      : 'validation.passwordMismatch'.tr();

  /// A trusted contact's number: present, and shaped like [phone] wants.
  String? contactPhone(String? value) => required(value) ?? phone(value);

  /// Optional; at most [relationshipMax] characters.
  String? relationship(String? value) =>
      (value ?? '').trim().length > relationshipMax
      ? 'validation.relationship'.tr()
      : null;

  /// A journey's place, in the user's own words: present, 2 to [placeMax]
  /// characters after trimming.
  String? place(String? value) {
    final String? missing = required(value);
    if (missing != null) return missing;
    final String entry = value!.trim();
    if (entry.length < 2) return 'validation.place'.tr();
    if (entry.length > placeMax) {
      return _length('validation.maxLength', placeMax);
    }
    return null;
  }

  /// [place], and not the same as [other] (read at validation time),
  /// ignoring case and outer spaces.
  FormFieldValidator<String> destination(String Function() other) =>
      (String? value) =>
          place(value) ??
          (value!.trim().toLowerCase() == other().trim().toLowerCase()
              ? 'validation.samePlace'.tr()
              : null);

  /// A departure: present, and not in the past (a minute's grace for the time
  /// it takes to tap Review). [kept] — the departure an edit opened with —
  /// passes as it is, so fixing a place on a journey whose time has gone by
  /// does not force a new time.
  FormFieldValidator<DateTime> departure({DateTime? kept}) =>
      (DateTime? value) {
        if (value == null) return 'validation.required'.tr();
        if (value == kept) return null;
        final DateTime limit = DateTime.now().subtract(
          const Duration(minutes: 1),
        );
        return value.isBefore(limit) ? 'validation.departurePast'.tr() : null;
      };

  /// How many of the three password rules [value] meets — drives the strength
  /// bar on registration.
  static int passwordScore(String value) => <bool>[
    value.length >= passwordMin,
    _digit.hasMatch(value),
    _uppercase.hasMatch(value),
  ].where((bool met) => met).length;

  String _length(String key, int count) => key.plural(
    count,
    namedArgs: <String, String>{
      'count': LocaleNumbers.decimal(_languageCode).format(count),
    },
  );
}
