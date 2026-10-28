import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// Who is signed in: name, email, the mobile number when one was given
/// (marked unverified, because it is), and where the account lives.
/// [name] null draws a loading state of the same height.
class SettingsAccountCard extends StatelessWidget {
  const SettingsAccountCard({
    required this.deviceOnlyLabel,
    required this.unverifiedLabel,
    this.name,
    this.email,
    this.phone,
    super.key,
  });

  final String? name;
  final String? email;
  final String? phone;
  final String deviceOnlyLabel;
  final String unverifiedLabel;

  /// [value] in a left-to-right isolate (U+2066 … U+2069), so a `+` and the
  /// digits keep their order inside Arabic (CLAUDE.md §8).
  static String _ltr(String value) =>
      '${String.fromCharCode(0x2066)}$value${String.fromCharCode(0x2069)}';

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? who = name;
    final String? number = phone;
    final TextStyle? quiet = context.texts.bodySmall?.copyWith(
      color: colors.textMuted,
    );

    return Container(
      constraints: BoxConstraints(minHeight: 96.fx),
      padding: EdgeInsets.all(16.fx),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18.fx),
        border: Border.all(color: colors.border),
      ),
      child: who == null
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44.fx,
                  height: 44.fx,
                  decoration: BoxDecoration(
                    color: colors.tint(colors.secondary),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: colors.accentText,
                    size: 24.fx,
                  ),
                ),
                Gap(14.fx),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4.fx,
                    children: <Widget>[
                      Text(
                        who,
                        style: context.texts.titleSmall?.copyWith(
                          color: colors.text,
                        ),
                      ),
                      // An address is one left-to-right run, even in Arabic.
                      Text(
                        email ?? '',
                        textDirection: TextDirection.ltr,
                        style: context.texts.bodyMedium?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                      if (number != null)
                        Text(
                          '${_ltr(number)}  ·  $unverifiedLabel',
                          style: quiet,
                        ),
                      Text(deviceOnlyLabel, style: quiet),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
