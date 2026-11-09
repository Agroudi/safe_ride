/// Every Firestore path the app uses, in one place
/// (docs/firebase-architecture.md §5). Each account's data lives under its
/// own `users/{uid}`; the security rules allow only that account there.
abstract final class FirestorePaths {
  static String user(String uid) => 'users/$uid';

  static String journeys(String uid) => '${user(uid)}/journeys';

  /// A journey's pre-journey safety checklist: one record per journey, made
  /// when it starts and never changed.
  static String journeyChecklist(String uid, String journeyId) =>
      '${journeys(uid)}/$journeyId/checklists/preJourney';

  /// A journey's recorded route, in chunks of points.
  static String journeyRoute(String uid, String journeyId) =>
      '${journeys(uid)}/$journeyId/route';

  /// A journey's route summary: distance, point count, times.
  static String journeyTracking(String uid, String journeyId) =>
      '${journeys(uid)}/$journeyId/tracking/summary';

  static String contacts(String uid) => '${user(uid)}/contacts';

  /// A safety check nobody answered, as the phone reports it.
  static String safetyChecks(String uid) => '${user(uid)}/safetyChecks';

  /// The potential incident such a check asked about.
  static String incidents(String uid) => '${user(uid)}/incidents';

  /// What the backend did about a safety check (written by it alone).
  static String escalations(String uid) => '${user(uid)}/escalations';

  /// The contacts who accepted an invite (written by the backend alone).
  static String contactLinks(String uid) => '${user(uid)}/contactLinks';

  /// Alerts received as someone's trusted contact (the backend's alone).
  static String receivedAlerts(String uid) => '${user(uid)}/receivedAlerts';

  /// This account's shares: the proof each is theirs, and how to find it.
  static String shareRecords(String uid) => '${user(uid)}/shares';

  /// What a share's link shows. Public to whoever holds the token, so it holds
  /// no owner.
  static String share(String token) => 'shares/$token';

  /// A shared journey's route, in chunks.
  static String shareRoute(String token) => '${share(token)}/route';

  /// Who this account is connected to: one record per side, the id being the
  /// other account.
  static String connections(String uid) => '${user(uid)}/connections';

  static String connection(String uid, String contactUid) =>
      '${connections(uid)}/$contactUid';

  /// Invitations to connect, by token. Top level: the person accepting has no
  /// way into the inviter's own paths.
  static const String connectionInvites = 'connectionInvites';

  static String connectionInvite(String token) => '$connectionInvites/$token';

  /// One document per install that receives push notifications.
  static String devices(String uid) => '${user(uid)}/devices';
}
