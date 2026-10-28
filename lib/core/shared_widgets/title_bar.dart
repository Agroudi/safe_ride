import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_back_button.dart';

/// The back tile and a screen's title, pinned to the leading edge — the top
/// of register, profile and the journey screens. A tab's root has nothing to go back to: [back]
/// false leaves the title alone.
class TitleBar extends StatelessWidget {
  const TitleBar({required this.title, this.back = true, super.key});

  final String title;
  final bool back;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (back) ...<Widget>[const AppBackButton(), Gap(12.fx)],
        // `Expanded`, not `Flexible`, on the part that absorbs the slack.
        Expanded(
          child: Semantics(
            container: true,
            header: true,
            child: Text(title, style: context.texts.titleLarge),
          ),
        ),
      ],
    );
  }
}
