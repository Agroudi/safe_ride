import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/models/received_alert.dart';
import 'package:safe_ride/features/safety/data/repository/call_launcher.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/data/repository/received_alerts_repository.dart';
import 'package:safe_ride/features/safety/logic/states/received_alerts_state.dart';

/// The alerts this user received; follows new ones. One per screen.
class ReceivedAlertsCubit extends Cubit<ReceivedAlertsState> {
  ReceivedAlertsCubit(this._repository, this._calls)
    : super(const AlertsLoading()) {
    _subscription = _repository.changes.listen((_) => load());
  }

  final ReceivedAlertsRepository _repository;
  final CallLauncher _calls;
  late final StreamSubscription<void> _subscription;

  Future<void> load() async {
    try {
      final List<ReceivedAlert> all = await _repository.alerts();
      if (!isClosed) emit(AlertsReady(all));
    } on ContactFailure {
      if (!isClosed) emit(const AlertsFailed());
    }
  }

  /// Opens the phone app with [number], on the user's own tap.
  Future<DialOutcome?> dial(String number) => _calls.open(number);

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
