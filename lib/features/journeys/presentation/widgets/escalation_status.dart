import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/features/journeys/logic/cubit/escalation_cubit.dart';

/// What became of a journey's unanswered safety check, in words that claim
/// only what is known: "accepted" is the provider's word, never "delivered".
/// Draws nothing when nothing is unanswered.
class EscalationStatus extends StatelessWidget {
  const EscalationStatus({required this.journeyId, super.key});

  final String journeyId;

  @override
  Widget build(BuildContext context) => BlocProvider<EscalationCubit>(
    create: (_) => sl<EscalationCubit>()..watch(journeyId),
    child: BlocBuilder<EscalationCubit, EscalationState>(
      builder: (BuildContext context, EscalationState state) {
        if (state.phase == EscalationPhase.none) {
          return const SizedBox.shrink();
        }
        final String key = 'journeys.escalation.${state.phase.name}';
        final int accepted = state.escalation?.accepted ?? 0;
        return Padding(
          padding: EdgeInsetsDirectional.only(bottom: 20.fx),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              InfoNote(
                text: state.phase == EscalationPhase.accepted
                    ? context.plural(
                        key,
                        accepted,
                        namedArgs: <String, String>{
                          'count': LocaleNumbers.decimal(
                            context.locale.languageCode,
                          ).format(accepted),
                        },
                      )
                    : context.tr(key),
              ),
              if (state.canRetry) ...<Widget>[
                Gap(10.fx),
                AppPrimaryButton(
                  label: context.tr('journeys.escalation.retry'),
                  outlined: true,
                  onPressed: context.read<EscalationCubit>().retry,
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
