import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/shared_widgets/app_back_button.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_map_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_live_map.dart';

/// A journey on the map: where the phone is, the route recorded so far, and
/// where it started and ends. It only shows what `JourneyTracker` already has:
/// leaving this screen changes nothing about the recording.
class JourneyMapPage extends StatelessWidget {
  const JourneyMapPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) => BlocProvider<JourneyMapCubit>(
    create: (_) => sl<JourneyMapCubit>()..open(id),
    child: const _JourneyMapView(),
  );
}

class _JourneyMapView extends StatelessWidget {
  const _JourneyMapView();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BlocBuilder<JourneyMapCubit, JourneyMapState>(
      buildWhen: (JourneyMapState a, JourneyMapState b) =>
          a.loading != b.loading || a.missing != b.missing,
      builder: (BuildContext context, JourneyMapState state) {
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.missing) {
          return SafeArea(
            child: Column(
              children: <Widget>[
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppBackButton(),
                ),
                AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: context.tr('journeys.detail.missingTitle'),
                  body: context.tr('journeys.detail.missingBody'),
                ),
              ],
            ),
          );
        }
        return JourneyLiveMap(opening: state);
      },
    ),
  );
}
