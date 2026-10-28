import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/journeys/data/models/journey_draft.dart';

/// The plan travels to review as a JSON-safe map, and anything else is no
/// draft at all (the route then redirects to planning).
void main() {
  test('a draft survives the trip through `extra`', () {
    final JourneyDraft draft = JourneyDraft(
      origin: 'Home',
      destination: 'Work',
      departsAt: DateTime.utc(2026, 11, 2, 8, 30),
    );
    final JourneyDraft back = JourneyDraft.from(draft.toExtra())!;
    expect(back.origin, 'Home');
    expect(back.destination, 'Work');
    expect(back.departsAt, DateTime.utc(2026, 11, 2, 8, 30));
  });

  test('missing or broken parts are no draft', () {
    expect(JourneyDraft.from(null), isNull);
    expect(JourneyDraft.from('x'), isNull);
    expect(
      JourneyDraft.from(<String, String>{'origin': 'A', 'destination': 'B'}),
      isNull,
    );
    expect(
      JourneyDraft.from(<String, String>{
        'origin': ' ',
        'destination': 'B',
        'departsAt': '2026-11-02T08:30:00Z',
      }),
      isNull,
    );
    expect(
      JourneyDraft.from(<String, String>{
        'origin': 'A',
        'destination': 'B',
        'departsAt': 'soon',
      }),
      isNull,
    );
  });
}
