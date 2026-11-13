import 'dart:convert';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/assistant/data/models/ai_failure.dart';
import 'package:safe_ride/features/assistant/data/models/ai_message.dart';
import 'package:safe_ride/features/assistant/data/models/ai_reply.dart';
import 'package:safe_ride/features/assistant/data/models/ai_request.dart';
import 'package:safe_ride/features/assistant/data/models/assistant_limits.dart';
import 'package:safe_ride/features/assistant/data/models/emergency_signal.dart';
import 'package:safe_ride/features/assistant/data/repository/assistant_repository.dart';
import 'package:safe_ride/features/assistant/data/repository/conversation_store.dart';
import 'package:safe_ride/features/assistant/logic/states/assistant_state.dart';

/// The SafeRide AI conversation for the signed-in account: loads it from the
/// phone, asks one question at a time, keeps a failed question for Retry
/// (same request id, so it is never counted twice), and clears it.
///
/// Emergency words show Get help before the question is even sent, and
/// nothing here waits on the AI to do so. Nothing is called, sent or shared
/// on the user's behalf. One per screen.
class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit(
    this._session,
    this._store,
    this._assistant, {
    DateTime Function()? clock,
    String Function()? newId,
  }) : _clock = clock ?? DateTime.now,
       _newId = newId ?? _randomId,
       super(const AssistantState());

  final SessionReader _session;
  final ConversationStore _store;
  final AssistantRepository _assistant;
  final DateTime Function() _clock;
  final String Function() _newId;

  Future<void> load() async {
    final String? uid = await _uid();
    if (uid == null) {
      _emit(
        state.copyWith(
          loading: false,
          failure: () => AiFailureCode.unauthenticated,
        ),
      );
      return;
    }
    final List<AiMessage> messages = await _store.load(uid);
    _emit(state.copyWith(loading: false, messages: messages));
    try {
      final AiUsage usage = await _assistant.usage();
      _emit(state.copyWith(usage: usage));
    } on Object {
      // Any failure here only hides the count; it shows once a question has
      // been answered.
    }
  }

  /// Asks [raw]. Blank text and taps while a question is on its way are
  /// ignored; a question over the limit is refused here, before sending.
  Future<void> send(String raw) async {
    final String text = raw.trim();
    if (text.isEmpty || state.sending) return;
    if (text.length > AssistantLimits.maxMessageChars) {
      _emit(state.copyWith(failure: () => AiFailureCode.tooLong));
      return;
    }
    final String? uid = await _uid();
    if (uid == null) {
      _emit(state.copyWith(failure: () => AiFailureCode.unauthenticated));
      return;
    }
    final AiRequest request = AiRequest(
      requestId: _newId(),
      text: text,
      history: AssistantLimits.historyFor(state.messages),
      language: state.language,
    );
    final AiMessage question = AiMessage(
      id: request.requestId,
      role: AiRole.user,
      text: text,
      at: _clock().toUtc(),
    );
    final List<AiMessage> messages = <AiMessage>[...state.messages, question];
    _emit(
      state.copyWith(
        messages: messages,
        sending: true,
        failure: () => null,
        pending: () => request,
        getHelp: state.getHelp || EmergencySignal.detect(text),
      ),
    );
    await _store.save(uid, messages);
    await _deliver(uid, request);
  }

  /// Asks the failed question again, with its own request id.
  Future<void> retry() async {
    final AiRequest? request = state.pending;
    if (!state.canRetry || request == null) return;
    final String? uid = await _uid();
    if (uid == null) return;
    _emit(state.copyWith(sending: true, failure: () => null));
    await _deliver(uid, request);
  }

  Future<void> _deliver(String uid, AiRequest request) async {
    try {
      final AiReply reply = await _assistant.send(request);
      final List<AiMessage> messages = <AiMessage>[
        ...state.messages,
        reply.message,
      ];
      _emit(
        state.copyWith(
          messages: messages,
          sending: false,
          pending: () => null,
          usage: reply.usage,
          getHelp: state.getHelp || reply.suggestGetHelp,
        ),
      );
      await _store.save(uid, messages);
    } on AiFailure catch (e) {
      _failed(e.code);
    } on Object {
      _failed(AiFailureCode.unknown);
    }
  }

  void _failed(AiFailureCode code) => _emit(
    state.copyWith(
      sending: false,
      failure: () => code,
      pending: code.retryable ? null : () => null,
    ),
  );

  /// Empties the conversation, on the screen and on the phone.
  Future<void> clear() async {
    if (state.sending) return;
    final String? uid = await _uid();
    if (uid != null) await _store.clear(uid);
    _emit(
      state.copyWith(
        messages: const <AiMessage>[],
        failure: () => null,
        pending: () => null,
        getHelp: false,
      ),
    );
  }

  void setLanguage(AiLanguage language) =>
      _emit(state.copyWith(language: language));

  /// The user closed the Get help offer; Get help itself stays on the screen.
  void dismissGetHelp() => _emit(state.copyWith(getHelp: false));

  Future<String?> _uid() async => (await _session.signedInUser())?.id;

  void _emit(AssistantState next) {
    if (!isClosed) emit(next);
  }

  static String _randomId() {
    final Random random = Random.secure();
    return base64Url
        .encode(<int>[for (int i = 0; i < 16; i++) random.nextInt(256)])
        .replaceAll('=', '');
  }
}
