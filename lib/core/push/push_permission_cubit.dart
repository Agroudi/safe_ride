import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/push/push_notifications.dart';

/// The notification permission, for the Profile row that asks for it. Null
/// while it is being read.
class PushPermissionCubit extends Cubit<PushPermission?> {
  PushPermissionCubit(this._push) : super(null);

  final PushNotifications _push;

  Future<void> load() async {
    final PushPermission permission = await _push.permission();
    if (!isClosed) emit(permission);
  }

  /// Asks the phone — only while it can still be asked.
  Future<void> request() async {
    if (state != PushPermission.notAsked) return;
    final PushPermission permission = await _push.requestPermission();
    if (!isClosed) emit(permission);
  }
}
