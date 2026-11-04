import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/safety/data/models/received_alert.dart';

sealed class ReceivedAlertsState extends Equatable {
  const ReceivedAlertsState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class AlertsLoading extends ReceivedAlertsState {
  const AlertsLoading();
}

final class AlertsReady extends ReceivedAlertsState {
  const AlertsReady(this.alerts);

  final List<ReceivedAlert> alerts;

  @override
  List<Object?> get props => <Object?>[alerts];
}

final class AlertsFailed extends ReceivedAlertsState {
  const AlertsFailed();
}
