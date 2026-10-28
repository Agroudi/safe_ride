import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// A screen's heading and the supporting line under it. Every authentication
/// screen opens with one; the recovery screens put a back tile and an icon
/// above it.
class AuthHeader extends StatelessWidget {
  const AuthHeader({required this.title, super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: context.texts.headlineMedium),
        if (subtitle case final String line) ...<Widget>[
          Gap(10.fx),
          Text(
            line,
            style: context.texts.bodyMedium?.copyWith(
              color: context.appColors.textMuted,
              height: 1.8,
            ),
          ),
        ],
      ],
    );
  }
}
