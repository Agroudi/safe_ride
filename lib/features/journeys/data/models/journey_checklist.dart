/// The pre-journey safety checklist every journey must pass to start.
///
/// **Versioned.** A version's items never change once released: a new
/// requirement is a new version. A journey's record keeps the version and the
/// item ids it confirmed, so history always says exactly what was asked —
/// and the text of every version stays in the translation files
/// (`journeys.checklist.v<version>.<item>`), never deleted. The Security
/// Rules (`firestore.rules`) list each version's items too: a new version is
/// added in both places.
abstract final class JourneyChecklist {
  /// The version a journey started today uses.
  static const int current = 1;

  /// Each version's items, in the order they are shown.
  static const Map<int, List<String>> versions = <int, List<String>>{
    1: <String>[
      'vehicle',
      'energy',
      'tiresBrakes',
      'documents',
      'fitness',
      'sober',
      'phoneBattery',
      'contacts',
      'assistance',
    ],
  };

  /// [version]'s items; none for a version this build does not know.
  static List<String> itemsOf(int version) =>
      versions[version] ?? const <String>[];

  /// True when [confirmed] is exactly [version]'s items — every one, and
  /// nothing that is not on it.
  static bool isComplete(int version, Set<String> confirmed) {
    final List<String> items = itemsOf(version);
    return items.isNotEmpty &&
        confirmed.length == items.length &&
        confirmed.containsAll(items);
  }
}
