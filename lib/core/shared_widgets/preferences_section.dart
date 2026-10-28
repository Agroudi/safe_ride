import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// A labelled group of options in the preferences sheet: the heading, then
/// the rows.
class PreferencesSection extends StatelessWidget {
  const PreferencesSection({
    required this.label,
    required this.options,
    super.key,
  });

  final String label;
  final List<Widget> options;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8.fx,
      children: <Widget>[
        PreferencesHeading(label: label),
        ...options,
      ],
    );
  }
}

/// A heading a screen reader can jump between: the sheet's title, or the
/// quiet label above a group of options.
class PreferencesHeading extends StatelessWidget {
  const PreferencesHeading({
    required this.label,
    super.key,
    this.isTitle = false,
  });

  final String label;
  final bool isTitle;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = isTitle
        ? context.texts.titleLarge?.copyWith(color: context.appColors.text)
        : context.texts.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.appColors.textMuted,
          );

    return Semantics(header: true, child: Text(label, style: style));
  }
}
