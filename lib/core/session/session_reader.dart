import 'package:flutter/foundation.dart';

/// Who is signed in, as every feature but authentication may see it: an id
/// and a name, nothing secret.
@immutable
class SessionUser {
  const SessionUser({required this.id, required this.fullName});

  /// Stable per account — the key a feature stores the account's data under.
  final String id;
  final String fullName;

  /// Name parts that are only half a first name: «عبد الرحمن» is greeted as
  /// «عبد الرحمن», never «عبد». Compared case-insensitively.
  static const Set<String> _joinedPrefixes = <String>{
    'عبد',
    'أبو',
    'ابو',
    'abd',
    'abdel',
    'abdul',
    'abdal',
    'abu',
  };

  /// The name to greet: the first word, joined to the next when it is one of
  /// the [_joinedPrefixes]. Null when there is no name at all.
  String? get firstName {
    final List<String> words = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;
    if (words.length > 1 &&
        _joinedPrefixes.contains(words.first.toLowerCase())) {
      return '${words[0]} ${words[1]}';
    }
    return words.first;
  }
}

/// The read-only view of the session that features other than
/// authentication depend on (CLAUDE.md §2: what two features share lives in
/// `core/`). The authentication repository implements it; the service
/// locator hands the same instance out under both types.
abstract interface class SessionReader {
  /// The signed-in user, or null. Throws nothing: a storage failure reads as
  /// nobody signed in to the caller, which then shows its signed-out state.
  Future<SessionUser?> signedInUser();

  /// Fires when who is signed in, or their details, change — so a greeting
  /// shows a new name at once.
  Stream<void> get changes;
}
