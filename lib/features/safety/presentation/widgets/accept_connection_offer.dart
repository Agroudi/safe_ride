import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/shared_widgets/point_list.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/presentation/widgets/contact_initial.dart';

/// Who is inviting, and what saying yes does and does not do.
class AcceptConnectionOffer extends StatelessWidget {
  const AcceptConnectionOffer({
    required this.name,
    required this.submitting,
    required this.onAccept,
    required this.onDecline,
    super.key,
  });

  final String name;
  final bool submitting;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            ContactInitial(name: name),
            Gap(12.fx),
            Expanded(
              child: Text(
                context.tr(
                  'safety.connections.accept.invited',
                  namedArgs: <String, String>{'name': name},
                ),
                style: context.texts.titleMedium?.copyWith(color: colors.text),
              ),
            ),
          ],
        ),
        Gap(20.fx),
        PointList(
          title: context.tr('safety.connections.accept.meansTitle'),
          icon: Icons.check_rounded,
          color: colors.secondary,
          points: <String>[
            context.tr('safety.connections.accept.meansName'),
            context.tr('safety.connections.accept.meansNothing'),
            context.tr('safety.connections.accept.meansEnd'),
          ],
        ),
        Gap(10.fx),
        InfoNote(text: context.tr('safety.connections.accept.onlyIfKnown')),
        Gap(24.fx),
        AppPrimaryButton(
          label: context.tr('safety.connections.accept.accept'),
          busy: submitting,
          onPressed: onAccept,
        ),
        Gap(12.fx),
        AppPrimaryButton(
          label: context.tr('safety.connections.accept.notNow'),
          outlined: true,
          onPressed: submitting ? null : onDecline,
        ),
      ],
    );
  }
}
