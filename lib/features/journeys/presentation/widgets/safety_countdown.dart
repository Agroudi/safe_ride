import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// The seconds left, large, inside a ring that empties as they run out.
/// A figure, not an animation: it changes when the number does.
class SafetyCountdown extends StatelessWidget {
  const SafetyCountdown({
    required this.seconds,
    required this.fraction,
    required this.digits,
    required this.label,
    super.key,
  });

  /// Whole seconds left, and the share of the countdown left (0–1).
  final int seconds;
  final double fraction;

  /// [seconds] in the locale's digits.
  final String digits;

  /// "12 seconds left", for a screen reader.
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final double size = 112.fx;

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: fraction.clamp(0, 1),
                strokeWidth: 8.fx,
                color: colors.warning,
                backgroundColor: colors.tint(colors.warning),
              ),
            ),
            // Fits at any text scale.
            Padding(
              padding: EdgeInsets.all(18.fx),
              child: FittedBox(
                child: Text(
                  digits,
                  style: context.texts.displaySmall?.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
