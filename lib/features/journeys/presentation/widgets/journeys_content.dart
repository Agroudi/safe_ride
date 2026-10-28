import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/logic/states/journeys_state.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_list.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';

/// What a journeys section shows for each state: a spinner while loading,
/// the failure with a retry, the [empty] card (no journeys at all), the
/// [filteredEmpty] card (none match [where]), or the list. The page supplies
/// the cards and the failure's words.
class JourneysContent extends StatelessWidget {
  const JourneysContent({
    required this.state,
    required this.empty,
    required this.failedTitle,
    required this.failedBody,
    required this.retryLabel,
    required this.onRetry,
    required this.onOpen,
    this.limit,
    this.where,
    this.filteredEmpty,
    this.onCancel,
    super.key,
  });

  final JourneysState state;
  final Widget empty;
  final String failedTitle;
  final String failedBody;
  final String retryLabel;
  final VoidCallback onRetry;
  final ValueChanged<JourneyModel> onOpen;
  final int? limit;

  /// Which journeys to show; null shows all.
  final bool Function(JourneyModel)? where;
  final Widget? filteredEmpty;
  final ValueChanged<JourneyModel>? onCancel;

  @override
  Widget build(BuildContext context) {
    final List<JourneyModel> all;
    switch (state) {
      case JourneysLoading():
        return SizedBox(
          height: 120.fx,
          child: const Center(child: CircularProgressIndicator()),
        );
      case JourneysFailed():
        return AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: failedTitle,
          body: failedBody,
          actionLabel: retryLabel,
          onAction: onRetry,
        );
      case JourneysReady(:final List<JourneyModel> journeys):
        all = journeys;
    }
    if (all.isEmpty) return empty;
    final bool Function(JourneyModel)? keep = where;
    final List<JourneyModel> shown = keep == null
        ? all
        : all.where(keep).toList();
    if (shown.isEmpty) return filteredEmpty ?? empty;
    return JourneyList(
      journeys: shown,
      limit: limit,
      onOpen: onOpen,
      onCancel: onCancel,
    );
  }
}
