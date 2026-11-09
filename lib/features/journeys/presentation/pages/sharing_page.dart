import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/journeys/data/models/location_share.dart';
import 'package:safe_ride/features/journeys/logic/cubit/share_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/manage_sharing.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/share_labels.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/start_sharing_form.dart';

/// Starting a share, or managing the one that is on: one screen, so there is
/// never a way to start a second. [journeyId] shares that journey; without it,
/// the current location.
class SharingPage extends StatelessWidget {
  const SharingPage({this.journeyId, super.key});

  final String? journeyId;

  @override
  Widget build(BuildContext context) => BlocProvider<ShareCubit>(
    create: (_) => sl<ShareCubit>(),
    child: _SharingView(journeyId: journeyId),
  );
}

class _SharingView extends StatelessWidget {
  const _SharingView({required this.journeyId});

  final String? journeyId;

  void _onState(BuildContext context, ShareState state) {
    if (state is ShareFailed) {
      sl<AppNotifier>().show(ShareLabels.failure(context, state.code));
    } else if (state is ShareStopped) {
      sl<AppNotifier>().show(
        ShareLabels.stopped(context, confirmed: state.confirmed),
      );
    }
  }

  String _title(ShareState state) => state is ShareActive
      ? 'sharing.manage.title'
      : journeyId == null
      ? 'sharing.start.location.title'
      : 'sharing.start.journey.title';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: BlocConsumer<ShareCubit, ShareState>(
        listener: _onState,
        builder: (BuildContext context, ShareState state) => ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            AppSpacing.screenTop,
            AppSpacing.screenSide,
            28.fx,
          ),
          children: <Widget>[
            TitleBar(title: context.tr(_title(state))),
            Gap(20.fx),
            if (state case ShareActive(:final status))
              ManageSharing(
                status: status,
                onStop: () => unawaited(context.read<ShareCubit>().stop()),
              )
            else
              StartSharingForm(
                journey: journeyId != null,
                busy: state is ShareStarting,
                onStart: (ShareDuration d) => unawaited(
                  context.read<ShareCubit>().start(d, journeyId: journeyId),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
