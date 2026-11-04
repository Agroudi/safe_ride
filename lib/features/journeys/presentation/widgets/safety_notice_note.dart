import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_notifications.dart';
import 'package:safe_ride/features/journeys/logic/cubit/safety_notice_cubit.dart';

/// On a journey in progress, when notifications are off: a safety check can
/// then be answered only with SafeRide on screen, so it says so and offers
/// to turn them on. Looks again on coming back from the phone's settings.
class SafetyNoticeNote extends StatefulWidget {
  const SafetyNoticeNote({super.key});

  @override
  State<SafetyNoticeNote> createState() => _SafetyNoticeNoteState();
}

class _SafetyNoticeNoteState extends State<SafetyNoticeNote> {
  late final SafetyNoticeCubit _cubit = sl<SafetyNoticeCubit>()..refresh();
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: _cubit.refresh,
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SafetyNoticeCubit, SafetyNoticeAccess>(
        bloc: _cubit,
        builder: (BuildContext context, SafetyNoticeAccess access) {
          if (access == SafetyNoticeAccess.allowed) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: EdgeInsetsDirectional.only(bottom: 20.fx),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                InfoNote(text: context.tr('journeys.safetyCheck.notice.off')),
                Gap(10.fx),
                AppPrimaryButton(
                  label: context.tr('journeys.safetyCheck.notice.turnOn'),
                  outlined: true,
                  onPressed: _cubit.allow,
                ),
              ],
            ),
          );
        },
      );
}
