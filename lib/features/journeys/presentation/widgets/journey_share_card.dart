import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/features/journeys/data/models/location_share.dart';
import 'package:safe_ride/features/journeys/logic/cubit/share_cubit.dart';
import 'package:safe_ride/core/shared_widgets/status_chip.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_labels.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/share_labels.dart';

/// On a journey in progress: share it, or see that something is being shared.
class JourneyShareCard extends StatelessWidget {
  const JourneyShareCard({required this.journeyId, super.key});

  final String journeyId;

  void _open(BuildContext context) => context.pushNamed(
    AppRoutes.shareJourney,
    pathParameters: <String, String>{'id': journeyId},
  );

  @override
  Widget build(BuildContext context) => BlocProvider<ShareCubit>(
    create: (_) => sl<ShareCubit>(),
    child: BlocBuilder<ShareCubit, ShareState>(
      builder: (BuildContext context, ShareState state) {
        if (state case ShareActive(:final ShareStatus status)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusChip(
                  label: ShareLabels.delivery(context, status.delivery),
                  color: ShareLabels.deliveryTone(
                    context.appColors,
                    status.delivery,
                  ),
                ),
              ),
              Gap(6.fx),
              Text(
                context.tr(
                  'sharing.manage.ends',
                  namedArgs: <String, String>{
                    'time': MapLabels.clock(context, status.record.expiresAt),
                  },
                ),
                style: context.texts.bodySmall?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
              Gap(8.fx),
              AppPrimaryButton(
                label: context.tr('sharing.manage.title'),
                outlined: true,
                onPressed: () => _open(context),
              ),
            ],
          );
        }
        return AppPrimaryButton(
          label: context.tr('sharing.start.journey.title'),
          outlined: true,
          onPressed: () => _open(context),
        );
      },
    ),
  );
}
