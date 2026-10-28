import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';

/// What the splash shows when startup could not decide where to open: a calm
/// explanation and a retry — never a spinner that runs on, never a guessed
/// destination.
///
/// The message is one live region, so a screen reader announces it when it
/// takes the spinner's place. The button stays outside it, a separate stop.
class SplashFailure extends StatelessWidget {
  const SplashFailure({
    required this.title,
    required this.body,
    required this.retryLabel,
    required this.onRetry,
    super.key,
  });

  final String title;
  final String body;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Merged, so the title and body are read as one announcement rather
        // than the live region holding two separate nodes.
        MergeSemantics(
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: context.texts.titleMedium,
                ),
                Gap(8.fx),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: context.texts.bodyMedium?.copyWith(
                    color: context.appColors.textMuted,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        Gap(24.fx),
        AppPrimaryButton(label: retryLabel, onPressed: onRetry),
      ],
    );
  }
}
