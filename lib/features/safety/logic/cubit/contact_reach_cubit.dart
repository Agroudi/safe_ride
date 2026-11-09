import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/safety/data/repository/call_launcher.dart';
import 'package:safe_ride/features/safety/data/repository/message_composer.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';

/// Call and Message on the Trusted Contacts list, for numbers the user saved
/// themselves. The state is the id of the contact whose app is opening (null
/// when none), so its buttons wait. Through the one `CallLauncher`: nothing
/// dials or sends by itself, and nothing is stored. One per screen.
class ContactReachCubit extends Cubit<String?> {
  ContactReachCubit(this._calls) : super(null);

  final CallLauncher _calls;

  /// Opens the phone app with [phone]; null: a duplicate tap, ignored.
  Future<DialOutcome?> call(String contactId, String phone) =>
      _reaching(contactId, () => _calls.open(phone));

  /// Opens the messaging app to [phone] with [body], still editable; null: a
  /// duplicate tap, ignored.
  Future<ComposeOutcome?> message(
    String contactId,
    String phone,
    String body,
  ) => _reaching(contactId, () => _calls.message(phone, body));

  Future<T?> _reaching<T>(String contactId, Future<T?> Function() open) async {
    if (state != null) return null;
    emit(contactId);
    try {
      return await open();
    } finally {
      if (!isClosed) emit(null);
    }
  }
}
