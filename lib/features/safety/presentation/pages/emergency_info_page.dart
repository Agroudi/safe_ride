import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/section_heading.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/safety/data/models/emergency_services.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_location_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/emergency_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_directory_section.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_guidance.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_location_card.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_sources.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_warning.dart';

/// Emergency information, reachable any time from Safety: the numbers of the
/// country the user says they are in — from the app's own checked dataset,
/// so offline too — where they are, for reading out, and what to do on the
/// call. Call only opens the phone app with the number ready: nothing dials
/// by itself, nobody is alerted, and nothing is sent.
class EmergencyInfoPage extends StatelessWidget {
  const EmergencyInfoPage({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: <BlocProvider<dynamic>>[
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
              TitleBar(title: context.tr('safety.emergency.title')),
              Gap(16.fx),
              EmergencyWarning(text: context.tr('safety.emergency.warning')),
              Gap(14.fx),
              const EmergencyDirectorySection(),
              Gap(24.fx),
              SectionHeading(title: context.tr('safety.location.heading')),
              Gap(10.fx),
              const EmergencyLocationCard(),
              Gap(24.fx),
              const EmergencyGuidance(),
              const _Sources(),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Where the numbers come from, once they are shown.
class _Sources extends StatelessWidget {
  const _Sources();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<EmergencyCubit, EmergencyState>(
        builder: (BuildContext context, EmergencyState state) =>
            switch (state) {
              EmergencyReady(:final EmergencyCountry numbers) => Padding(
                padding: EdgeInsetsDirectional.only(top: 16.fx),
                child: EmergencySources(country: numbers),
              ),
              _ => const SizedBox.shrink(),
            },
      );
}
