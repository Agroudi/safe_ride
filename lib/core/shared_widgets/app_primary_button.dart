import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_button_label.dart';
import 'package:safe_ride/core/shared_widgets/press_scale.dart';

/// The app's call to action — filled, or [outlined] for the quieter of two.
///
/// Everything screens disagree on is a parameter whose default is what most
/// screens use, so `AppPrimaryButton(label: …, onPressed: …)` is the standard
/// action. Do not grow a second button widget beside this one.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    super.key,
    this.onPressed,
    this.color,
    this.foregroundColor,
    this.outlined = false,
    this.busy = false,
    this.withShadow = true,
    this.dimWhenDisabled = true,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Fill colour (the border, when [outlined]); null draws the theme's primary.
  final Color? color;

  /// Label and spinner colour; null draws what reads on [color] — `onPrimary`
  /// when filled, the accent itself when [outlined]. Pass it with any [color]
  /// that is not primary, e.g. `onStatus` on a success fill.
  final Color? foregroundColor;

  /// The secondary style: transparent fill, a primary border and label, no
  /// glow. Beside a filled button it reads as the second choice.
  final bool outlined;

  /// Swaps the label for a spinner while a request is in flight (see
  /// `AppButtonLabel`). The button keeps its size — a shrinking action moves
  /// everything under it.
  final bool busy;

  /// The tinted glow under a standalone filled action.
  final bool withShadow;

  /// Fades the button while [onPressed] is null.
  final bool dimWhenDisabled;

  @override
  Widget build(BuildContext context) {
    final Color accent = color ?? context.appColors.primary;
    final Color ink =
        foregroundColor ?? (outlined ? accent : context.appColors.onPrimary);
    final BorderRadius corners = BorderRadius.circular(40.fx);
    final bool enabled = onPressed != null && !busy;

    // Gives a little under the finger while it can be pressed.
    final Widget button = PressScale(
      enabled: enabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : accent,
          borderRadius: corners,
          border: outlined ? Border.all(color: accent, width: 1.5.fx) : null,
          boxShadow: withShadow && !outlined
              ? <BoxShadow>[
                  BoxShadow(
                    // A strong glow turns muddy on a dark background.
                    color: accent.withValues(
                      alpha: context.isDark ? 0.25 : 0.45,
                    ),
                    offset: Offset(0, 10.fx),
                    blurRadius: 24.fx,
                    spreadRadius: -10.fx,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: corners,
            // The theme's focus wash is primary — invisible on a primary
            // fill. The label's colour shows on both styles.
            focusColor: ink.withValues(alpha: 0.24),
            onTap: busy ? null : onPressed,
            child: ConstrainedBox(
              // The accessibility minimum, whatever the text scale shrinks to.
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.fx,
                  vertical: 15.fx,
                ),
                // ⚠️ `Center(heightFactor: 1)`, not `alignment:` — an aligned
                // box with no explicit height grows to fill whatever it is
                // given.
                child: Center(
                  heightFactor: 1,
                  child: AppButtonLabel(
                    label: label,
                    busy: busy,
                    color: ink,
                    style: context.texts.titleSmall,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // The spinner replaces the label, so the label is announced instead —
    // and "disabled" while busy, so nobody taps twice. `container`: always
    // its own node — inside a card it would otherwise merge with the card's
    // text and stop being a button of its own.
    final Widget announced = Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: busy ? label : null,
      excludeSemantics: busy,
      child: button,
    );

    if (!dimWhenDisabled || onPressed != null) return announced;
    return Opacity(opacity: 0.45, child: announced);
  }
}
