import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/safety/data/models/received_alert.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/logic/cubit/received_alerts_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/received_alerts_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/received_alert_card.dart';
import 'package:safe_ride/features/safety/presentation/widgets/safety_notices.dart';

/// Alerts from people who named this user a trusted contact — where a
/// notification opens. Says what SafeRide knows and what it does not.
class ReceivedAlertsPage extends StatelessWidget {
  const ReceivedAlertsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<ReceivedAlertsCubit>(
    create: (_) => sl<ReceivedAlertsCubit>()..load(),
    child: const _ReceivedAlertsView(),
  );
}

class _ReceivedAlertsView extends StatelessWidget {
  const _ReceivedAlertsView();

  Future<void> _call(BuildContext context, String number) async {
    final ReceivedAlertsCubit cubit = context.read<ReceivedAlertsCubit>();
    final DialOutcome outcome = await cubit.dial(number);
    if (context.mounted) {
      sl<AppNotifier>().show(SafetyNotices.dial(context, outcome, number));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: BlocBuilder<ReceivedAlertsCubit, ReceivedAlertsState>(
        builder: (BuildContext context, ReceivedAlertsState state) => ListView(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screenSide,
            AppSpacing.screenTop,
            AppSpacing.screenSide,
            28.fx,
          ),
          children: <Widget>[
            TitleBar(title: context.tr('safety.alerts.title')),
            Gap(20.fx),
            switch (state) {
              AlertsLoading() => SizedBox(
                height: 120.fx,
                child: const Center(child: CircularProgressIndicator()),
              ),
              AlertsFailed() => AppEmptyState(
                icon: Icons.error_outline_rounded,
                title: context.tr('safety.alerts.failed.title'),
                body: context.tr('safety.alerts.failed.body'),
                actionLabel: context.tr('safety.contacts.failed.retry'),
                onAction: context.read<ReceivedAlertsCubit>().load,
              ),
              AlertsReady(:final List<ReceivedAlert> alerts)
                  when alerts.isEmpty =>
                AppEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: context.tr('safety.alerts.empty.title'),
                  body: context.tr('safety.alerts.empty.body'),
                ),
              AlertsReady(:final List<ReceivedAlert> alerts) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12.fx,
                children: <Widget>[
                  for (final ReceivedAlert a in alerts)
                    _AlertCard(
                      key: ValueKey<String>(a.id),
                      alert: a,
                      onCall: (String number) => _call(context, number),
                    ),
                ],
              ),
            },
          ],
        ),
      ),
    ),
  );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onCall, super.key});

  final ReceivedAlert alert;
  final ValueChanged<String> onCall;

  @override
  Widget build(BuildContext context) {
    final Map<String, String> who = <String, String>{'name': alert.fromName};
    final String? phone = alert.fromPhone;
    return ReceivedAlertCard(
      title: context.tr('safety.alerts.cardTitle', namedArgs: who),
      time: LocaleNumbers.dateTime(
        context.locale.languageCode,
      ).format(alert.eventAt.toLocal()),
      body: context.tr('safety.alerts.${alert.type}', namedArgs: who),
      caution: context.tr('safety.alerts.caution'),
      callLabel: phone == null
          ? null
          : context.tr('safety.alerts.call', namedArgs: who),
      onCall: phone == null ? null : () => onCall(phone),
    );
  }
}
