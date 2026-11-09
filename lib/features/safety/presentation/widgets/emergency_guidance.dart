import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/point_list.dart';

/// Short guidance for someone under stress: which service to ask for, and
/// what to do on the call — tell them where you are, because SafeRide cannot.
/// No diagnosis, and nothing read into the GPS.
class EmergencyGuidance extends StatelessWidget {
  const EmergencyGuidance({super.key});

  static const List<String> _which = <String>['ambulance', 'police', 'fire'];
  static const List<String> _calling = <String>[
    'where',
    'stay',
    'location',
    'rely',
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      PointList(
        title: context.tr('safety.guidance.which.title'),
        points: <String>[
          for (final String k in _which) context.tr('safety.guidance.which.$k'),
        ],
        icon: Icons.medical_services_rounded,
        color: context.appColors.error,
      ),
      Gap(12.fx),
      PointList(
        title: context.tr('safety.guidance.calling.title'),
        points: <String>[
          for (final String k in _calling)
            context.tr('safety.guidance.calling.$k'),
        ],
        icon: Icons.record_voice_over_rounded,
        color: context.appColors.primary,
      ),
    ],
  );
}
