import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/checklist_item_tile.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/checklist_progress.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_facts.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_route_card.dart';

/// The checklist for [journey]: which journey it is, the progress, one row
/// per item of [version], and Start — enabled only once every item is
/// confirmed — or Not now. Everything is locked while [starting].
class JourneyChecklistForm extends StatelessWidget {
  const JourneyChecklistForm({
    required this.journey,
    required this.version,
    required this.items,
    required this.confirmed,
    required this.starting,
    required this.onToggle,
    required this.onStart,
    required this.onNotNow,
    super.key,
  });

  final JourneyModel journey;
  final int version;
  final List<String> items;
  final Set<String> confirmed;
  final bool starting;
  final ValueChanged<String> onToggle;
  final VoidCallback onStart;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final NumberFormat digits = LocaleNumbers.decimal(
      context.locale.languageCode,
    );
    final int done = items.where(confirmed.contains).length;
    final bool complete = done == items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.tr('journeys.checklist.intro'),
          style: context.texts.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
            height: 1.6,
          ),
        ),
        Gap(16.fx),
        JourneyRouteCard(
          fromLabel: context.tr('journeys.from'),
          from: journey.origin,
          toLabel: context.tr('journeys.to'),
          to: journey.destination,
          trailing: JourneyDeparture(departsAt: journey.departsAt),
        ),
        Gap(24.fx),
        ChecklistProgress(
          done: done,
          total: items.length,
          label: context.tr(
            'journeys.checklist.progress',
            namedArgs: <String, String>{
              'done': digits.format(done),
              'total': digits.format(items.length),
            },
          ),
          hint: context.tr(
            complete
                ? 'journeys.checklist.complete'
                : 'journeys.checklist.incomplete',
          ),
        ),
        Gap(16.fx),
        for (final String item in items) ...<Widget>[
          ChecklistItemTile(
            key: ValueKey<String>(item),
            label: context.tr('journeys.checklist.v$version.$item'),
            confirmed: confirmed.contains(item),
            onTap: starting ? null : () => onToggle(item),
          ),
          Gap(10.fx),
        ],
        Gap(10.fx),
        InfoNote(text: context.tr('journeys.checklist.note')),
        Gap(28.fx),
        AppPrimaryButton(
          label: context.tr('journeys.checklist.start'),
          busy: starting,
          onPressed: complete ? onStart : null,
        ),
        Gap(12.fx),
        AppPrimaryButton(
          label: context.tr('journeys.checklist.notNow'),
          outlined: true,
          onPressed: starting ? null : onNotNow,
        ),
      ],
    );
  }
}
