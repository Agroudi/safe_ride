import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/safety/escalation_gate.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/shared_widgets/section_heading.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_location_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/safety_help_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/safety_help_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_directory_section.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_location_card.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_warning.dart';
import 'package:safe_ride/features/safety/presentation/widgets/help_people_section.dart';
import 'package:safe_ride/features/safety/presentation/widgets/help_status_card.dart';

/// Where to find help: after a safety check nobody answered, or any time.
/// "I'm okay" first while a check is open, then the emergency numbers (the
/// same directory as Emergency information), where the user is, sharing and
/// their people. Everything on it is the user's own action — a call they
/// place, a link they choose to send. SafeRide contacts nobody from here,
/// sends no location, and the screen says so.
class SafetyHelpPage extends StatelessWidget {
  const SafetyHelpPage({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: <BlocProvider<dynamic>>[
      BlocProvider<SafetyHelpCubit>(
        create: (_) => sl<SafetyHelpCubit>()..load(),
      ),
      BlocProvider<EmergencyCubit>(create: (_) => sl<EmergencyCubit>()..load()),
      BlocProvider<EmergencyLocationCubit>(
        create: (_) => sl<EmergencyLocationCubit>()..load(),
      ),
    ],
    child: Scaffold(
      body: SafeArea(
        child: Builder(
          builder: (BuildContext context) => ListView(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.screenSide,
              AppSpacing.screenTop,
              AppSpacing.screenSide,
              28.fx,
            ),
            children: <Widget>[
              TitleBar(title: context.tr('safety.help.title')),
              Gap(16.fx),
              const HelpStatusCard(),
              Gap(24.fx),
              SectionHeading(
                title: context.tr('safety.help.emergency.heading'),
              ),
              Gap(10.fx),
              EmergencyWarning(text: context.tr('safety.emergency.warning')),
              Gap(14.fx),
              const EmergencyDirectorySection(),
              Gap(12.fx),
              AppPrimaryButton(
                label: context.tr('safety.help.emergency.more'),
                outlined: true,
                onPressed: () => context.pushNamed(AppRoutes.emergencyInfo),
              ),
              Gap(24.fx),
              SectionHeading(title: context.tr('safety.location.heading')),
              Gap(10.fx),
              const EmergencyLocationCard(),
              const _Share(),
              Gap(24.fx),
              SectionHeading(title: context.tr('safety.help.people.heading')),
              Gap(10.fx),
              const HelpPeopleSection(),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Sharing the journey of an open escalation — only if the user chooses, on
/// Batch 16's own screen, where nothing is shared until they start it.
class _Share extends StatelessWidget {
  const _Share();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SafetyHelpCubit, SafetyHelpState>(
        builder: (BuildContext context, SafetyHelpState state) {
          final OpenEscalation? open = state.escalation;
          if (open == null) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsetsDirectional.only(top: 24.fx),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SectionHeading(title: context.tr('safety.help.share.heading')),
                Gap(10.fx),
                InfoNote(text: context.tr('safety.help.share.note')),
                Gap(12.fx),
                AppPrimaryButton(
                  label: context.tr('safety.help.share.action'),
                  outlined: true,
                  onPressed: () => context.pushNamed(
                    AppRoutes.shareJourney,
                    pathParameters: <String, String>{'id': open.journeyId},
                  ),
                ),
              ],
            ),
          );
        },
      );
}
