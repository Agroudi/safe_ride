import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_assets.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// A label stacked over a validated text field — every form in the app.
///
/// The field's look comes from `AppTheme.inputDecorationTheme`; this widget only
/// adds the label, the password eye, and the [validator]. Put it inside a
/// `Form` and call `formKey.currentState!.validate()` on submit.
///
/// ⚠️ One widget, on purpose. PrepAI grew two near-identical field widgets
/// (one for login/register, one for password recovery) and had to log them as
/// debt; any new field variant here is a parameter, not a copy.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.label,
    super.key,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    this.obscurable = false,
    this.enabled = true,
    this.errorText,
    this.helperText,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  /// Hides the text and shows the eye that reveals it again.
  final bool obscurable;

  final bool enabled;

  /// An error the form did not find — the repository's ("this email is
  /// already taken"). Shown under the field like a validator's; the page
  /// clears it when the field changes.
  final String? errorText;

  /// A standing note under the field (the password policy).
  final String? helperText;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscurable;

  /// Phone numbers and emails are typed left to right in both languages —
  /// in an RTL field `+966…` becomes `…966+` — but stay at the reading
  /// start, so an Arabic form keeps one edge.
  ///
  /// The field's `textAlign` also places its hint, helper and error, which
  /// resolve it in the page's direction while the text resolves it in LTR —
  /// `end` is right for one and left for the other. So the one case where a
  /// physical alignment is right: the reading start, picked by direction.
  bool get _latin =>
      widget.keyboardType == TextInputType.phone ||
      widget.keyboardType == TextInputType.emailAddress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          widget.label,
          style: context.texts.labelMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        Gap(9.fx),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          forceErrorText: widget.errorText,
          autofillHints: widget.autofillHints,
          obscureText: _obscured,
          textDirection: _latin ? TextDirection.ltr : null,
          textAlign: !_latin
              ? TextAlign.start
              : context.isRtl
              ? TextAlign.right
              : TextAlign.left,
          style: context.texts.bodyMedium?.copyWith(
            color: context.appColors.text,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            // `05xxxxxxxx` and `name@example.com` read like what is typed.
            hintTextDirection: _latin ? TextDirection.ltr : null,
            helperText: widget.helperText,
            helperMaxLines: 3,
            errorMaxLines: 3,
            suffixIconConstraints: const BoxConstraints(),
            suffixIcon: widget.obscurable
                ? _PasswordEye(
                    obscured: _obscured,
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// The eye at the end edge of a password field. The design only draws the
/// hidden state, so the revealed one falls back to the Material glyph.
class _PasswordEye extends StatelessWidget {
  const _PasswordEye({required this.obscured, required this.onPressed});

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color tone = context.appColors.textMuted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: 10.fx, end: 16.fx),
        child: obscured
            ? SvgPicture.asset(
                AppAssets.eyeOff,
                width: 21.fx,
                height: 19.fx,
                colorFilter: ColorFilter.mode(tone, BlendMode.srcIn),
              )
            : Icon(Icons.visibility_outlined, size: 21.fx, color: tone),
      ),
    );
  }
}
