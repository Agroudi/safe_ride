import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/shared_widgets/section_heading.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_invite_model.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/logic/cubit/connections_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/connections_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_actions.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_ended_tile.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_invite_tile.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_tile.dart';

/// Who this account is connected to, the invites that are out, and the way to
/// make or answer one.
class ConnectionsSection extends StatelessWidget {
  const ConnectionsSection({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ConnectionsCubit, ConnectionsState>(
    builder: (BuildContext context, ConnectionsState state) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10.fx,
      children: <Widget>[
        SectionHeading(title: context.tr('safety.connections.heading')),
        InfoNote(text: context.tr('safety.connections.notice')),
        if (state.mayBeStale)
          InfoNote(text: context.tr('safety.connections.stale')),
        switch (state.phase) {
          ConnectionsPhase.loading => SizedBox(
            height: 120.fx,
            child: const Center(child: CircularProgressIndicator()),
          ),
          // Refused rather than unreachable: the rules are not deployed yet.
          ConnectionsPhase.failed
              when state.failure == ConnectionFailureCode.unavailable =>
            AppEmptyState(
              icon: Icons.handshake_rounded,
              title: context.tr('safety.connections.errors.unavailable.title'),
              body: context.tr('safety.connections.errors.unavailable.body'),
            ),
          ConnectionsPhase.failed => AppEmptyState(
            icon: Icons.error_outline_rounded,
            title: context.tr('safety.connections.failed.title'),
            body: context.tr('safety.connections.failed.body'),
            actionLabel: context.tr('safety.connections.failed.retry'),
            onAction: context.read<ConnectionsCubit>().load,
          ),
          ConnectionsPhase.ready => _Lists(state: state),
        },
        AppPrimaryButton(
          label: context.tr('safety.connections.invite'),
          busy: state.busy,
          onPressed: () => ConnectionActions.invite(context),
        ),
        AppPrimaryButton(
          label: context.tr('safety.connections.haveInvite'),
          outlined: true,
          onPressed: () => context.pushNamed(AppRoutes.connectionInvite),
        ),
      ],
    ),
  );
}

class _Lists extends StatelessWidget {
  const _Lists({required this.state});

  final ConnectionsState state;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final bool idle = !state.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10.fx,
      children: <Widget>[
        if (state.connected.isEmpty)
          AppEmptyState(
            icon: Icons.handshake_rounded,
            title: context.tr('safety.connections.empty.title'),
            body: context.tr('safety.connections.empty.body'),
          ),
        for (final ConnectionModel c in state.connected)
          ConnectionTile(
            key: ValueKey<String>(c.contactUid),
            connection: c,
            onManage: () => context.pushNamed(
              AppRoutes.manageConnection,
              pathParameters: <String, String>{'id': c.contactUid},
            ),
            onRemove: idle ? () => ConnectionActions.remove(context, c) : null,
          ),
        if (state.invites.isNotEmpty) ...<Widget>[
          Gap(6.fx),
          SectionHeading(
            title: context.tr('safety.connections.invites.heading'),
          ),
        ],
        for (final ConnectionInviteModel i in state.invites)
          ConnectionInviteTile(
            key: ValueKey<String>(i.token),
            invite: i,
            status: i.statusAt(now),
            onCopy: () => ConnectionActions.copy(context, i),
            onShare: () => ConnectionActions.share(context, i),
            onCancel: idle
                ? () => ConnectionActions.cancel(
                    context,
                    i,
                    waiting: i.statusAt(now) == ConnectionStatus.pending,
                  )
                : null,
          ),
        if (state.ended.isNotEmpty) ...<Widget>[
          Gap(6.fx),
          SectionHeading(title: context.tr('safety.connections.ended.heading')),
        ],
        for (final ConnectionModel c in state.ended)
          ConnectionEndedTile(
            key: ValueKey<String>('ended-${c.contactUid}'),
            connection: c,
            onClear: idle ? () => ConnectionActions.clear(context, c) : null,
          ),
      ],
    );
  }
}
