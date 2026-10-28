import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// Home's top: the greeting and the question under it, and the avatar that
/// opens the profile. [initial] null draws a person glyph instead.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.greeting,
    required this.subtitle,
    required this.avatarLabel,
    required this.onAvatar,
    this.initial,
    super.key,
  });

  final String greeting;
  final String subtitle;
  final String avatarLabel;
  final VoidCallback onAvatar;
  final String? initial;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? letter = initial;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                container: true,
                header: true,
                child: Text(
                  greeting,
                  style: context.texts.headlineSmall?.copyWith(
                    color: colors.text,
                  ),
                ),
              ),
              Gap(4.fx),
              Text(
                subtitle,
                style: context.texts.bodyMedium?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Gap(12.fx),
        // Its own node: otherwise TalkBack merges it into the greeting and it
        // is never a button of its own.
        Semantics(
          container: true,
          button: true,
          label: avatarLabel,
          excludeSemantics: true,
          child: InkResponse(
            onTap: onAvatar,
            radius: 28.fx,
            child: Container(
              width: 48.fx,
              height: 48.fx,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.tint(colors.secondary),
                border: Border.all(color: colors.border),
              ),
              child: letter == null
                  ? Icon(Icons.person_rounded, color: colors.accentText)
                  : Text(
                      letter,
                      style: context.texts.titleMedium?.copyWith(
                        color: colors.accentText,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
