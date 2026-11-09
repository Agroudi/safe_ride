import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/logic/cubit/connections_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/connections_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/manage_connection_form.dart';

/// One connection, by the other account's id. It follows the live list, so a
/// connection the other person ends says so here too.
class ManageConnectionPage extends StatelessWidget {
  const ManageConnectionPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) => BlocProvider<ConnectionsCubit>(
    create: (_) => sl<ConnectionsCubit>()..load(),
    child: BlocBuilder<ConnectionsCubit, ConnectionsState>(
      builder: (BuildContext context, ConnectionsState state) {
        final ConnectionModel? connection = state.find(id);
        if (connection != null && connection.isActive) {
          return ManageConnectionForm(
            key: ValueKey<String>(id),
            connection: connection,
            busy: state.busy,
          );
        }
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screenSide,
                AppSpacing.screenTop,
                AppSpacing.screenSide,
                24.fx,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TitleBar(
                    title: context.tr('safety.connections.manageScreen.title'),
                  ),
                  Gap(20.fx),
                  if (state.phase == ConnectionsPhase.loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    AppEmptyState(
                      icon: Icons.link_off_rounded,
                      title: context.tr(
                        'safety.connections.manageScreen.gone.title',
                      ),
                      body: context.tr(
                        'safety.connections.manageScreen.gone.body',
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
