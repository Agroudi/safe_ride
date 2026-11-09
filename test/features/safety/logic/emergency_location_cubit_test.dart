import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/safety/emergency_position.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_location_cubit.dart';

import '../../../core/safety/position_fakes.dart';

/// A reader whose new reading waits until the test lets it go.
class _Slow extends FakePositionReader {
  _Slow(EmergencyPosition located) : super(located: located);

  final Completer<void> gate = Completer<void>();

  @override
  Future<EmergencyPosition> locateNow() async {
    readings++;
    await gate.future;
    return located;
  }
}

void main() {
  late DateTime now;
  final DateTime start = DateTime.utc(2026, 11, 8, 9);

  setUp(() => now = start);

  PositionReading reading({Duration ago = Duration.zero, double? accuracy}) =>
      PositionReading(
        latitude: 24.7136,
        longitude: 46.6753,
        at: start.subtract(ago),
        accuracy: accuracy,
      );

  EmergencyLocationCubit cubit(FakePositionReader reader) {
    final EmergencyLocationCubit c = stillLocationCubit(
      reader,
      clock: () => now,
    );
    addTearDown(c.close);
    return c;
  }

  test('opening takes no new reading: it shows what is known', () async {
    final FakePositionReader reader = FakePositionReader();
    final EmergencyLocationCubit c = cubit(reader);
    await c.load();
    expect(c.state.loading, isFalse);
    expect(c.state.reading, isNull);
    expect(reader.readings, 0);
  });

  test('a fresh reading is current, and becomes last known, then stale, as '
      'the clock moves — never shown as live once old', () async {
    final EmergencyLocationCubit c = cubit(
      FakePositionReader(
        known: EmergencyPosition(
          access: PositionAccess.allowed,
          reading: reading(accuracy: 8),
        ),
      ),
    );
    await c.load();
    expect(c.state.reading!.freshness(c.state.now), PositionFreshness.current);
    now = start.add(const Duration(seconds: 45));
    c.tick();
    expect(
      c.state.reading!.freshness(c.state.now),
      PositionFreshness.lastKnown,
    );
    now = start.add(const Duration(minutes: 6));
    c.tick();
    expect(c.state.reading!.freshness(c.state.now), PositionFreshness.stale);
  });

  test('poor accuracy is kept as reported', () async {
    final EmergencyLocationCubit c = cubit(
      FakePositionReader(
        known: EmergencyPosition(
          access: PositionAccess.allowed,
          reading: reading(accuracy: 350),
        ),
      ),
    );
    await c.load();
    expect(c.state.reading!.quality, PositionAccuracy.poor);
  });

  test('Find my location: one reading per tap, a second tap waits', () async {
    final _Slow reader = _Slow(
      EmergencyPosition(access: PositionAccess.allowed, reading: reading()),
    );
    final EmergencyLocationCubit c = cubit(reader);
    await c.load();
    final Future<void> first = c.locate();
    expect(c.state.locating, isTrue);
    await c.locate();
    reader.gate.complete();
    await first;
    expect(reader.readings, 1);
    expect(c.state.locating, isFalse);
    expect(c.state.reading?.latitude, 24.7136);
  });

  test('nothing new found: the last known location stays, labelled by its '
      'age, and the card says the phone gave none', () async {
    final PositionReading old = reading(ago: const Duration(minutes: 3));
    final EmergencyLocationCubit c = cubit(
      FakePositionReader(
        known: EmergencyPosition(access: PositionAccess.allowed, reading: old),
        located: const EmergencyPosition(access: PositionAccess.allowed),
      ),
    );
    await c.load();
    await c.locate();
    expect(c.state.notFound, isTrue);
    expect(c.state.reading?.at, old.at);
    expect(
      c.state.reading!.freshness(c.state.now),
      PositionFreshness.lastKnown,
    );
  });

  test('location not allowed or off: said, with no reading', () async {
    for (final PositionAccess access in <PositionAccess>[
      PositionAccess.notAllowed,
      PositionAccess.servicesOff,
    ]) {
      final EmergencyLocationCubit c = cubit(
        FakePositionReader(known: EmergencyPosition(access: access)),
      );
      await c.load();
      expect(c.state.position?.access, access);
      expect(c.state.reading, isNull);
    }
  });

  test('the journey in progress, or none', () async {
    final EmergencyLocationCubit c = cubit(
      FakePositionReader(
        known: const EmergencyPosition(
          access: PositionAccess.allowed,
          destination: 'Work',
        ),
      ),
    );
    await c.load();
    expect(c.state.position?.destination, 'Work');
  });
}
