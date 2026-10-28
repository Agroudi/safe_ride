import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// The status glyph on a quiet wash of its colour; announced as its word.
class NotificationStatusIcon extends StatelessWidget {
  const NotificationStatusIcon({
    required this.icon,
    required this.color,
    required this.label,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        width: 40.fx,
        height: 40.fx,
        decoration: BoxDecoration(
          color: context.appColors.tint(color),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22.fx, color: color),
      ),
    );
  }
}

/// An `InkResponse`, not an `IconButton`: the host sits above the navigator,
/// outside any `Overlay`, so a tooltip would have nowhere to show.
class NotificationCloseButton extends StatelessWidget {
  const NotificationCloseButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Its own node: without `container` it would merge into the card's live
    // region, and the whole card would become the dismiss button.
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onPressed,
        radius: 22,
        child: SizedBox.square(
          dimension: kMinInteractiveDimension,
          child: Icon(
            Icons.close_rounded,
            size: 20.fx,
            color: context.appColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// The optional single action under the message.
class NotificationAction extends StatelessWidget {
  const NotificationAction({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 6.fx),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, kMinInteractiveDimension),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: context.appColors.accentText,
          textStyle: context.texts.labelLarge,
        ),
        child: Text(label),
      ),
    );
  }
}
