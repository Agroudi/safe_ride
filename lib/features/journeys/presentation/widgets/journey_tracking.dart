import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/logic/cubit/tracking_cubit.dart';
import 'package:safe_ride/features/journeys/logic/states/tracking_state.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_card.dart';

/// [journey]'s route recording on its details screen. Starts or joins the
/// recording while the journey is in progress, looks again when the app
/// comes back from the settings, and shows what was recorded once it ended.
class JourneyTracking extends StatelessWidget {
  const JourneyTracking({required this.journey, super.key});

  final JourneyModel journey;

  @override
  Widget build(BuildContext context) => BlocProvider<TrackingCubit>(
    create: (_) => sl<TrackingCubit>()..watch(journey),
    child: _Watcher(journey: journey),
  );
}

class _Watcher extends StatefulWidget {
  const _Watcher({required this.journey});

  final JourneyModel journey;

  @override
  State<_Watcher> createState() => _WatcherState();
}

class _WatcherState extends State<_Watcher> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<TrackingCubit>().refresh(),
    );
  }

  @override
  void didUpdateWidget(_Watcher old) {
    super.didUpdateWidget(old);
    if (old.journey.status != widget.journey.status) {
      context.read<TrackingCubit>().watch(widget.journey);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TrackingCubit cubit = context.read<TrackingCubit>();
    return BlocBuilder<TrackingCubit, TrackingState>(
      builder: (BuildContext context, TrackingState state) => TrackingCard(
        state: state,
        since: widget.journey.startedAt ?? widget.journey.updatedAt,
        onAllow: cubit.allow,
        onSettings: cubit.openSettings,
      ),
    );
  }
}
