import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// A plain tappable line of text — "forgot password", "create account",
/// "continue as a guest". Each one only differs by its style, so the caller
/// passes that in.
class AuthLinkButton extends StatelessWidget {
  const AuthLinkButton({
    required this.label,
    required this.style,
    super.key,
    this.onPressed,
  });

  final String label;
  final TextStyle? style;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      // A few pixels of padding so the tap target is bigger than the glyphs.
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.fx),
        child: Text(label, textAlign: TextAlign.center, style: style),
      ),
    );
  }
}
