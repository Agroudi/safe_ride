import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:safe_ride/core/constants/public_links.dart';
import 'package:safe_ride/core/security/bearer_token.dart';

/// What a share shows: where the phone is, or a journey in progress.
enum ShareKind { location, journey }

/// How long a share lasts. The rules allow at most 12 hours; "until the
/// journey finishes" stays a little under it, so a phone whose clock runs a few
/// minutes fast is not refused.
enum ShareDuration {
  minutes15(Duration(minutes: 15)),
  minutes30(Duration(minutes: 30)),
  hour1(Duration(hours: 1)),
  hours3(Duration(hours: 3)),
  untilFinished(Duration(hours: 11, minutes: 55));

  const ShareDuration(this.length);

  final Duration length;

  /// What each kind of share offers, the default first.
  static const List<ShareDuration> forLocation = <ShareDuration>[
    minutes30,
    minutes15,
    hour1,
    hours3,
  ];

  static const List<ShareDuration> forJourney = <ShareDuration>[
    untilFinished,
    minutes15,
    minutes30,
    hour1,
    hours3,
  ];
}

/// Where a share can be reached. Build-time, like the map providers: the token
/// goes after `#`, which browsers never send to a server or in a Referer.
abstract final class ShareLinks {
  static const String base = PublicLinks.base;

  /// Firestore's public REST address: what the web viewer reads, and how the
  /// app checks a link really works before showing it.
  static const String firestore = String.fromEnvironment(
    'SHARE_FIRESTORE_URL',
    defaultValue:
        'https://firestore.googleapis.com/v1/projects/saferide-a9d9f/databases/(default)/documents',
  );

  /// In the viewer page, so a page of another site is never taken for it.
  static const String viewerMarker = 'saferide-share-viewer';

  static String link(String token) => '$base/s#$token';

  /// The token of a link, when it holds a well-formed one.
  static String? tokenOf(Uri uri) =>
      BearerToken.isValid(uri.fragment) ? uri.fragment : null;
}

/// The owner's own record of a share, at `users/{uid}/shares/{token}`: what
/// proves it is theirs, and finds it again after a restart, on another phone,
/// or when the account is deleted.
final class ShareRecord extends Equatable {
  const ShareRecord({
    required this.token,
    required this.kind,
    required this.expiresAt,
    this.journeyId,
  });

  /// Null when the stored document cannot be read: skipped, never guessed.
  static ShareRecord? read(String token, Map<String, dynamic> data) {
    final Object? expires = data['expiresAt'];
    final Object? kind = data['kind'];
    if (expires is! Timestamp || kind is! String) return null;
    final ShareKind? known = ShareKind.values.asNameMap()[kind];
    if (known == null) return null;
    final Object? journeyId = data['journeyId'];
    return ShareRecord(
      token: token,
      kind: known,
      expiresAt: expires.toDate().toUtc(),
      journeyId: journeyId is String ? journeyId : null,
    );
  }

  final String token;
  final ShareKind kind;
  final DateTime expiresAt;
  final String? journeyId;

  String get link => ShareLinks.link(token);

  ShareRecord copyWith({DateTime? expiresAt}) => ShareRecord(
    token: token,
    kind: kind,
    expiresAt: expiresAt ?? this.expiresAt,
    journeyId: journeyId,
  );

  @override
  List<Object?> get props => <Object?>[token, kind, expiresAt, journeyId];
}

/// Where a share stands, as far as this phone can tell. "Reaching" means the
/// server has the latest position: nothing here knows whether anyone looked.
enum ShareDelivery {
  /// No position sent yet.
  waiting,

  /// The server confirmed the latest position.
  reaching,

  /// A position could not be sent; the next one is tried soon.
  notReaching,

  /// Location is unavailable, so nothing new can be sent.
  paused,
}

final class ShareStatus extends Equatable {
  const ShareStatus({
    required this.record,
    required this.delivery,
    this.lastDeliveredAt,
  });

  final ShareRecord record;
  final ShareDelivery delivery;
  final DateTime? lastDeliveredAt;

  @override
  List<Object?> get props => <Object?>[record, delivery, lastDeliveredAt];
}

enum ShareFailureCode {
  /// Not signed in.
  signedOut,

  /// A share needs the server to confirm it, and it cannot be reached.
  offline,

  /// The viewer or the public read does not work, so a link would be dead:
  /// no link is shown (the rules or Hosting are not deployed yet).
  unavailable,

  /// The server refused it: the rules, or a wrong phone clock.
  refused,

  /// Location access is missing.
  noAccess,

  /// One share at a time.
  alreadySharing,

  /// The journey is not in progress.
  notActive,
}

/// The one error sharing throws.
final class ShareFailure implements Exception {
  const ShareFailure(this.code);

  final ShareFailureCode code;

  @override
  String toString() => 'ShareFailure(${code.name})';
}

/// The share is over on the server: stopped elsewhere, or expired.
final class ShareGone implements Exception {
  const ShareGone();
}
