import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/features/safety/data/repository/message_composer.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';

/// The one way SafeRide opens the phone app or the messaging app, for every
/// Call and Message in the app: prepares the number ([DialNumber]), refuses
/// it when missing or malformed, and lets only one launch through at a time —
/// a second tap while an app is opening, or within [cooldown] after one
/// opened, does nothing. A launch that failed can be tried again at once.
/// App-wide, so two buttons on one screen cannot open two apps.
///
/// It never dials and never sends: the phone app shows the number and the
/// user presses call, or cancels; the messaging app shows the text and the
/// user edits and sends it, or doesn't. Nothing about a launch, a number or
/// a text is stored or logged.
class CallLauncher {
  CallLauncher(
    this._dialer,
    this._composer, {
    DateTime Function()? clock,
    this.cooldown = AppDurations.dialCooldown,
  }) : _clock = clock ?? DateTime.now;

  final PhoneDialer _dialer;
  final MessageComposer _composer;
  final DateTime Function() _clock;
  final Duration cooldown;

  bool _opening = false;
  DateTime? _openedAt;

  /// What opening the phone app with [raw] came to, or null when the tap was
  /// ignored as a duplicate.
  Future<DialOutcome?> open(String raw) => _launch<DialOutcome>(
    raw,
    invalid: DialOutcome.invalidNumber,
    opened: DialOutcome.opened,
    launch: _dialer.open,
  );

  /// What opening the messaging app with [raw] and [body] — a text the user
  /// can still change — came to, or null when the tap was a duplicate.
  Future<ComposeOutcome?> message(String raw, String body) =>
      _launch<ComposeOutcome>(
        raw,
        invalid: ComposeOutcome.invalidNumber,
        opened: ComposeOutcome.opened,
        launch: (String number) => _composer.compose(number, body),
      );

  Future<T?> _launch<T>(
    String raw, {
    required T invalid,
    required T opened,
    required Future<T> Function(String number) launch,
  }) async {
    if (_opening) return null;
    final DateTime? last = _openedAt;
    if (last != null && _clock().difference(last) < cooldown) return null;
    final String? number = DialNumber.prepare(raw);
    if (number == null) return invalid;
    _opening = true;
    try {
      final T outcome = await launch(number);
      if (outcome == opened) _openedAt = _clock();
      return outcome;
    } finally {
      _opening = false;
    }
  }
}
