/// A safety check nobody answered, as every feature may see it: what was
/// asked and when — never where. The journeys feature keeps the record; the
/// safety feature's help screen reads it through [EscalationGate].
final class OpenEscalation {
  const OpenEscalation({
    required this.checkId,
    required this.journeyId,
    required this.timedOutAt,
    this.detectedAt,
  });

  final String checkId;
  final String journeyId;

  /// When the 15 seconds ran out (UTC).
  final DateTime timedOutAt;

  /// When the movement was noticed (UTC), when known.
  final DateTime? detectedAt;
}

/// What a late "I'm okay" did.
enum ResolveOutcome {
  /// Closed: the user said they are okay.
  resolved,

  /// Nothing open by that id (closed already, or never prepared).
  notOpen,
}

/// The read-and-close view of the escalation lifecycle that features other
/// than journeys depend on (CLAUDE.md §2: what two features share lives in
/// `core/`). `SafetyCheckService` implements it.
abstract interface class EscalationGate {
  /// Fires when any check changes.
  Stream<void> get changed;

  /// The signed-in account's newest open escalation, or null.
  Future<OpenEscalation?> latestOpen();

  /// [journeyId]'s open escalation, or null.
  Future<OpenEscalation?> openFor(String journeyId);

  /// The user's "I'm okay", after the deadline.
  Future<ResolveOutcome> resolveSafe(String checkId);
}
