import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_labels.dart';

/// The departure, chosen with the platform's date then time pickers — a
/// `FormField`, so it validates and shows its error like the text fields
/// around it. The value is local time; callers store it as UTC.
class DepartureField extends FormField<DateTime> {
  DepartureField({
    required String label,
    required String hint,
    required ValueChanged<DateTime> onChanged,
    super.initialValue,
    super.validator,
    super.key,
  }) : super(
         builder: (FormFieldState<DateTime> field) => _DepartureBox(
           label: label,
           hint: hint,
           field: field,
           onChanged: onChanged,
         ),
       );
}

class _DepartureBox extends StatelessWidget {
  const _DepartureBox({
    required this.label,
    required this.hint,
    required this.field,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final FormFieldState<DateTime> field;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime start = field.value ?? now;
    // ⚠️ Without it, Arabic gets Latin digits in the grid (CLAUDE.md §8).
    final Locale digits = LocaleNumbers.pickerLocale(
      context.locale.languageCode,
    );
    final DateTime? day = await showDatePicker(
      context: context,
      locale: digits,
      initialDate: start.isBefore(now) ? now : start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !context.mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
      builder: (BuildContext context, Widget? child) => Localizations.override(
        context: context,
        locale: digits,
        child: child,
      ),
    );
    if (time == null) return;
    final DateTime picked = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    field.didChange(picked);
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final DateTime? value = field.value;
    final String? error = field.errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: context.texts.labelMedium?.copyWith(color: colors.textMuted),
        ),
        Gap(9.fx),
        Semantics(
          container: true,
          button: true,
          label: label,
          value: value == null
              ? hint
              : JourneyLabels.date(context, value.toUtc()),
          excludeSemantics: true,
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: BorderRadius.circular(16.fx),
            child: InputDecorator(
              isEmpty: value == null,
              decoration: InputDecoration(
                hintText: hint,
                errorText: error,
                errorMaxLines: 3,
                suffixIcon: Icon(
                  Icons.event_rounded,
                  color: colors.textMuted,
                  size: 21.fx,
                ),
              ),
              child: value == null
                  ? null
                  : Text(
                      JourneyLabels.date(context, value.toUtc()),
                      style: context.texts.bodyMedium?.copyWith(
                        color: colors.text,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The first quarter-hour that is still ahead — a sensible start for a new
/// plan, never in the past.
DateTime nextQuarterHour(DateTime now) {
  final DateTime floor = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute - now.minute % 15,
  );
  return floor.add(const Duration(minutes: 15));
}
