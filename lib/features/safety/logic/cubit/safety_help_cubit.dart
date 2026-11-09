import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/safety/escalation_gate.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/data/models/contact_reach.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/call_launcher.dart';
import 'package:safe_ride/features/safety/data/repository/connection_repository.dart';
import 'package:safe_ride/features/safety/data/repository/message_composer.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/data/repository/trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/logic/states/safety_help_state.dart';

/// The help screen: an open escalation to close, the people the user can
/// reach themselves, a Call that only opens the phone app and a Message that
/// only opens the messaging app. **It contacts nobody**: nothing here sends,
/// shares or dials by itself. Connected people have no number here — a
/// connection shares a name only. One per screen.
class SafetyHelpCubit extends Cubit<SafetyHelpState> {
  SafetyHelpCubit(
    this._escalations,
    this._connections,
    this._contacts,
    this._calls,
  ) : super(const SafetyHelpState()) {
    _subscriptions = <StreamSubscription<void>>[
      _escalations.changed.listen((_) => _loadEscalation()),
      _connections.changes.listen((_) => _loadConnections()),
      _contacts.changes.listen((_) => _loadSaved()),
    ];
  }

  final EscalationGate _escalations;
  final ConnectionRepository _connections;
  final TrustedContactsRepository _contacts;
  final CallLauncher _calls;
  late final List<StreamSubscription<void>> _subscriptions;

  /// The saved numbers, by id: kept here, never in the state the screen draws.
  final Map<String, String> _numbers = <String, String>{};

  Future<void> load() async {
    await Future.wait(<Future<void>>[
      _loadEscalation(),
      _loadConnections(),
      _loadSaved(),
    ]);
    if (!isClosed) emit(state.copyWith(loading: false));
  }

  Future<void> _loadEscalation() async {
    final OpenEscalation? open = await _escalations.latestOpen();
    if (!isClosed) emit(state.copyWith(escalation: () => open));
  }

  Future<void> _loadConnections() async {
    try {
      final List<ConnectionModel> all = await _connections.connections();
      if (isClosed) return;
      emit(
        state.copyWith(
          connectionsFailed: false,
          connected: <HelpConnection>[
            for (final ConnectionModel c in all)
              if (c.isActive) HelpConnection(c.displayName),
          ],
        ),
      );
    } on ConnectionFailure {
      if (!isClosed) emit(state.copyWith(connectionsFailed: true));
    }
  }

  Future<void> _loadSaved() async {
    try {
      final List<TrustedContactModel> all = await _contacts.contacts();
      _numbers
        ..clear()
        ..addAll(<String, String>{
          for (final TrustedContactModel c in all) c.id: c.phone,
        });
      if (isClosed) return;
      emit(
        state.copyWith(
          savedFailed: false,
          saved: <HelpSavedContact>[
            for (final TrustedContactModel c in all)
              HelpSavedContact(
                id: c.id,
                name: c.fullName,
                relationship: c.relationship,
                reach: ContactReach.of(c.phone),
              ),
          ],
        ),
      );
    } on ContactFailure {
      if (!isClosed) emit(state.copyWith(savedFailed: true));
    }
  }

  /// "I'm okay", once.
  Future<ResolveOutcome?> resolve() async {
    final OpenEscalation? open = state.escalation;
    if (open == null || state.resolving) return null;
    emit(state.copyWith(resolving: true));
    final ResolveOutcome outcome = await _escalations.resolveSafe(open.checkId);
    if (!isClosed) emit(state.copyWith(resolving: false));
    await _loadEscalation();
    return outcome;
  }

  /// Opens the phone app with a saved contact's number; the user presses
  /// call. The outcome says only that; null: a duplicate tap, ignored.
  Future<DialOutcome?> call(String contactId) async {
    final String? number = _numbers[contactId];
    if (number == null) return DialOutcome.invalidNumber;
    return _reaching(contactId, () => _calls.open(number));
  }

  /// Opens the messaging app to a saved contact with [body], which the user
  /// can still change; they send it, or don't. No location is in it. The
  /// outcome says only that the app opened; null: a duplicate tap, ignored.
  Future<ComposeOutcome?> message(String contactId, String body) async {
    final String? number = _numbers[contactId];
    if (number == null) return ComposeOutcome.invalidNumber;
    return _reaching(contactId, () => _calls.message(number, body));
  }

  Future<T?> _reaching<T>(String contactId, Future<T?> Function() open) async {
    if (state.reaching != null) return null;
    emit(state.copyWith(reaching: () => contactId));
    try {
      return await open();
    } finally {
      if (!isClosed) emit(state.copyWith(reaching: () => null));
    }
  }

  @override
  Future<void> close() async {
    for (final StreamSubscription<void> s in _subscriptions) {
      await s.cancel();
    }
    return super.close();
  }
}
