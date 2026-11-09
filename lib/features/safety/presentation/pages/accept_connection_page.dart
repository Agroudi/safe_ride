import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_pages.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/logic/cubit/accept_connection_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/accept_connection_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/accept_connection_entry.dart';
import 'package:safe_ride/features/safety/presentation/widgets/accept_connection_offer.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_labels.dart';

/// Answering an invite, from its link or from what the person pasted. A link
/// can open the app cold, with nothing beneath this screen: leaving then goes
/// to the splash, which decides where the app belongs.
class AcceptConnectionPage extends StatelessWidget {
  const AcceptConnectionPage({required this.token, super.key});

  /// Null when reached from Trusted Contacts.
  final String? token;

  static void leave(BuildContext context) => context.canPop()
      ? context.pop()
      : context.goNamed(AppRoutes.splash, extra: AppPages.up);

  @override
  Widget build(BuildContext context) => BlocProvider<AcceptConnectionCubit>(
    create: (_) => sl<AcceptConnectionCubit>()..open(token),
    child: const _AcceptConnectionView(),
  );
}

class _AcceptConnectionView extends StatelessWidget {
  const _AcceptConnectionView();

  void _onState(BuildContext context, AcceptConnectionState state) {
    switch (state) {
      case AcceptDone(:final String inviterName):
        sl<AppNotifier>().show(
          AppNotification.success(
            title: context.tr(
              'safety.connections.accept.done.title',
              namedArgs: <String, String>{'name': inviterName},
            ),
            message: context.tr('safety.connections.accept.done.body'),
          ),
        );
        // Through the Safety tab, so the list's own back has somewhere to go.
        context
          ..goNamed(AppRoutes.safety)
          ..pushNamed(AppRoutes.trustedContacts);
      case AcceptReady(failure: final ConnectionFailureCode code):
        sl<AppNotifier>().show(ConnectionLabels.failure(context, code));
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AcceptConnectionCubit cubit = context.read<AcceptConnectionCubit>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
                title: context.tr('safety.connections.accept.title'),
                onBack: () => AcceptConnectionPage.leave(context),
              ),
              Gap(20.fx),
              BlocConsumer<AcceptConnectionCubit, AcceptConnectionState>(
                listener: _onState,
                builder: (BuildContext context, AcceptConnectionState state) =>
                    switch (state) {
                      AcceptEntry() => const AcceptConnectionEntry(),
                      AcceptChecking() || AcceptDone() => SizedBox(
                        height: 160.fx,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      AcceptSignedOut() => AppEmptyState(
                        icon: Icons.login_rounded,
                        title: context.tr(
                          'safety.connections.accept.signedOut.title',
                        ),
                        body: context.tr(
                          'safety.connections.accept.signedOut.body',
                        ),
                        actionLabel: context.tr(
                          'safety.connections.accept.signedOut.action',
                        ),
                        onAction: () => context.goNamed(
                          AppRoutes.splash,
                          extra: AppPages.up,
                        ),
                      ),
                      AcceptReady(
                        :final String inviterName,
                        :final bool submitting,
                      ) =>
                        AcceptConnectionOffer(
                          name: inviterName,
                          submitting: submitting,
                          onAccept: cubit.accept,
                          onDecline: () => AcceptConnectionPage.leave(context),
                        ),
                      AcceptFailed(:final ConnectionFailureCode code) =>
                        AppEmptyState(
                          icon: Icons.link_off_rounded,
                          title: context.tr(
                            'safety.connections.errors.${code.name}.title',
                          ),
                          body: context.tr(
                            'safety.connections.errors.${code.name}.body',
                          ),
                          actionLabel: context.tr(
                            code == ConnectionFailureCode.offline
                                ? 'safety.connections.accept.again'
                                : 'safety.connections.accept.another',
                          ),
                          onAction: code == ConnectionFailureCode.offline
                              ? cubit.retry
                              : cubit.startOver,
                        ),
                    },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
