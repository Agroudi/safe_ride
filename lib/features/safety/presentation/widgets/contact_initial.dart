import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// Someone's first letter in a circle: SafeRide keeps no photos.
class ContactInitial extends StatelessWidget {
  const ContactInitial({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Container(
      width: 44.fx,
      height: 44.fx,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.tint(colors.secondary),
        shape: BoxShape.circle,
      ),
      child: Text(
        name.characters.first.toUpperCase(),
        style: context.texts.titleMedium?.copyWith(color: colors.accentText),
      ),
    );
  }
}
