import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/shared_widgets/point_list.dart';
import 'package:safe_ride/core/shared_widgets/section_heading.dart';
import 'package:safe_ride/features/journeys/data/models/location_share.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/share_labels.dart';

/// What will be shared and for how long, said before anything starts. Nothing
/// is shared until Start is pressed.
class StartSharingForm extends StatefulWidget {
  const StartSharingForm({
    required this.journey,
    required this.busy,
    required this.onStart,
    super.key,
  });

  /// A journey in progress, not the current location.
  final bool journey;
  final bool busy;
  final ValueChanged<ShareDuration> onStart;

  @override
  State<StartSharingForm> createState() => _StartSharingFormState();
}

class _StartSharingFormState extends State<StartSharingForm> {
  List<ShareDuration> get _options =>
      widget.journey ? ShareDuration.forJourney : ShareDuration.forLocation;

  late ShareDuration _chosen = _options.first;

  @override
  Widget build(BuildContext context) {
    final String kind = widget.journey ? 'journey' : 'location';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.tr('sharing.start.$kind.intro'),
          style: context.texts.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        Gap(16.fx),
        PointList(
          title: context.tr('sharing.start.seesTitle'),
          icon: Icons.visibility_rounded,
          color: context.appColors.accentText,
          points: <String>[
            for (final String key
                in widget.journey
                    ? const <String>['position', 'ends', 'route', 'status']
                    : const <String>['position', 'status'])
              context.tr('sharing.start.sees.$key'),
          ],
        ),
        Gap(12.fx),
        PointList(
          title: context.tr('sharing.start.neverTitle'),
          icon: Icons.visibility_off_rounded,
          color: context.appColors.textMuted,
          points: <String>[context.tr('sharing.start.never')],
        ),
        Gap(20.fx),
        SectionHeading(title: context.tr('sharing.start.durationTitle')),
        Gap(8.fx),
        RadioGroup<ShareDuration>(
          groupValue: _chosen,
          onChanged: (ShareDuration? d) {
            if (d != null) setState(() => _chosen = d);
          },
          child: Column(
            children: <Widget>[
              for (final ShareDuration d in _options)
                RadioListTile<ShareDuration>(
                  value: d,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    ShareLabels.duration(context, d),
                    style: context.texts.bodyMedium?.copyWith(
                      color: context.appColors.text,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Gap(12.fx),
        InfoNote(text: context.tr('sharing.start.privacy')),
        Gap(8.fx),
        InfoNote(text: context.tr('sharing.notEmergency')),
        Gap(20.fx),
        AppPrimaryButton(
          label: context.tr('sharing.start.action'),
          busy: widget.busy,
          onPressed: widget.busy ? null : () => widget.onStart(_chosen),
        ),
      ],
    );
  }
}
