/// Why SafeRide AI did not answer. Provider-independent: a provider's own
/// errors become one of these at the server, and the app never sees more.
enum AiFailureCode {
  /// No connection, so nothing was sent.
  offline,

  /// Not signed in, or the session ended.
  unauthenticated,

  /// The account's questions for today are used up.
  dailyLimit,

  /// SafeRide AI cannot answer right now: the shared free capacity is used
  /// up, or the provider is busy or down. Never retried in a loop.
  unavailable,

  /// The question is longer than `AssistantLimits.maxMessageChars`.
  tooLong,

  /// The provider's safety filters refused the question or the answer.
  blocked,

  /// No answer in time.
  timeout,

  unknown;

  /// Worth trying the same question again (the user taps Retry).
  bool get retryable => switch (this) {
    offline || unavailable || timeout || unknown => true,
    unauthenticated || dailyLimit || tooLong || blocked => false,
  };
}

/// The one error an `AssistantRepository` throws.
final class AiFailure implements Exception {
  const AiFailure(this.code);

  final AiFailureCode code;

  @override
  String toString() => 'AiFailure(${code.name})';
}
