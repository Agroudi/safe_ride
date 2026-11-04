import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_notifications.dart';

/// Whether a safety check can reach the user with the app off screen, for
/// the journey screen's note. Starts as allowed, so nothing flashes before
/// the phone has answered. One per screen.
class SafetyNoticeCubit extends Cubit<SafetyNoticeAccess> {
  SafetyNoticeCubit(this._notifications) : super(SafetyNoticeAccess.allowed);

  final SafetyNotifications _notifications;

  /// Reads it again: at first, and when back from the phone's settings.
  Future<void> refresh() async {
    try {
      final SafetyNoticeAccess access = await _notifications.access();
      if (!isClosed) emit(access);
    } on Object {
      // Unknown is not "off": say nothing rather than guess.
    }
  }

  /// The system prompt the first time; after a refusal only the phone's
  /// settings can change it.
  Future<void> allow() async {
    final SafetyNoticeAccess access = await _notifications.request();
    if (isClosed) return;
    emit(access);
    if (access == SafetyNoticeAccess.blocked) {
      await _notifications.openSettings();
    }
  }
}
