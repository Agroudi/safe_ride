import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/press_scale.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// The preferences entry on the trailing edge — right in English, left in
/// Arabic.
///
/// A labelled pill, not a bare icon: a lone glyph is easy to miss, and the
/// tune glyph beside the word still points the way for someone who cannot read
/// the language the app opened in. It gives a little under the finger, as the
/// buttons do (`PressScale`).
class WelcomeTopBar extends StatelessWidget {
  const WelcomeTopBar({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: _PreferencesPill(label: label, onPressed: onPressed),
    );
  }
}

class _PreferencesPill extends StatelessWidget {
  const _PreferencesPill({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return PressScale(
      child: Semantics(
        container: true,
        button: true,
        child: Material(
          color: colors.surface,
          shape: StadiumBorder(
            side: BorderSide(color: colors.border, width: 1.fx),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              // The accessibility minimum in logical pixels, not a design unit:
              // it must not shrink on a small phone.
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  14.fx,
                  6.fx,
                  16.fx,
                  6.fx,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.tune_rounded,
                      size: 18.fx,
                      color: colors.primary,
                    ),
                    Gap(8.fx),
                    Flexible(
                      child: Text(
                        label,
                        style: context.texts.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
