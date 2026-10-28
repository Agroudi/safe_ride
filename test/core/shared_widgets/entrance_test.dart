import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/shared_widgets/entrance_item.dart';
import 'package:safe_ride/core/shared_widgets/entrance_scope.dart';

/// A screen's entrance plays once, never blocks, never replays, and is at
/// rest on frame one when the system asks for no animations.
void main() {
  const Key first = Key('first');
  const Key last = Key('last');

  /// An entrance with an item on beat 0 and one on beat 4 (the last).
  Widget entrance({VoidCallback? onComplete, MediaQueryData? media}) {
    final Widget scope = EntranceScope(
      duration: AppDurations.entrance,
      onComplete: onComplete,
      child: const Column(
        children: <Widget>[
          EntranceItem.beat(
            0,
            rise: AppMotion.rise,
            scaleFrom: AppMotion.ringFrom,
            child: Text('Welcome', key: first),
          ),
          EntranceItem.beat(
            4,
            rise: AppMotion.riseSmall,
            child: Text('Log in', key: last),
          ),
        ],
      ),
    );
    return ScreenUtilInit(
      designSize: const Size(AppDesign.width, AppDesign.height),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: media == null ? scope : MediaQuery(data: media, child: scope),
        ),
      ),
    );
  }

  /// [key]'s opacity: every fade between it and its item, multiplied.
  double opacity(WidgetTester tester, Key key) => tester
      .widgetList<FadeTransition>(
        find.ancestor(
          of: find.byKey(key),
          matching: find.byType(FadeTransition),
        ),
      )
      .fold(1, (double o, FadeTransition fade) => o * fade.opacity.value);

  /// True when nothing between [key] and the screen moves or scales it.
  bool atRest(WidgetTester tester, Key key) => tester
      .widgetList<Transform>(
        find.ancestor(of: find.byKey(key), matching: find.byType(Transform)),
      )
      .every((Transform t) => t.transform.isIdentity());

  Animation<double> clock(WidgetTester tester) =>
      EntranceScope.maybeOf(tester.element(find.byKey(first)))!;

  group('under reduced motion, frame one is the final state', () {
    Future<void> expectFinalOnFrameOne(
      WidgetTester tester,
      Widget app,
      List<SchedulerPhase> completions,
    ) async {
      await tester.pumpWidget(app);

      for (final Key key in <Key>[first, last]) {
        expect(opacity(tester, key), 1);
        expect(atRest(tester, key), isTrue);
      }
      expect(completions, <SchedulerPhase>[SchedulerPhase.postFrameCallbacks]);
      // Any first frame of this harness schedules one more; after that,
      // nothing ticks.
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(completions, hasLength(1));
    }

    testWidgets('from a MediaQuery', (WidgetTester tester) async {
      final List<SchedulerPhase> completions = <SchedulerPhase>[];
      await expectFinalOnFrameOne(
        tester,
        entrance(
          media: const MediaQueryData(disableAnimations: true),
          onComplete: () =>
              completions.add(SchedulerBinding.instance.schedulerPhase),
        ),
        completions,
      );
    });

    testWidgets('from the system setting', (WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final List<SchedulerPhase> completions = <SchedulerPhase>[];
      await expectFinalOnFrameOne(
        tester,
        entrance(
          onComplete: () =>
              completions.add(SchedulerBinding.instance.schedulerPhase),
        ),
        completions,
      );
    });
  });

  testWidgets('with motion: invisible but announced at 0, at rest by 780', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(entrance());

    expect(opacity(tester, first), 0);
    expect(opacity(tester, last), 0);
    expect(atRest(tester, first), isFalse);
    expect(find.bySemanticsLabel('Welcome'), findsOneWidget);
    expect(find.bySemanticsLabel('Log in'), findsOneWidget);

    // Beat 0 is opaque halfway through its 400 ms; beat 4 has not started.
    await tester.pump(AppMotion.beat(0) + AppDurations.short);
    expect(opacity(tester, first), moreOrLessEquals(1));
    expect(opacity(tester, last), 0);

    await tester.pump(
      AppDurations.entrance - AppMotion.beat(0) - AppDurations.short,
    );
    for (final Key key in <Key>[first, last]) {
      expect(opacity(tester, key), 1);
      expect(atRest(tester, key), isTrue);
    }
    // The controller reports completed on the first tick past its end; then
    // the settled screen schedules nothing.
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);
    semantics.dispose();
  });

  testWidgets('a MediaQuery change mid-run does not restart it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(entrance(media: const MediaQueryData()));
    await tester.pump(const Duration(milliseconds: 300));
    final double before = clock(tester).value;
    expect(before, greaterThan(0));

    await tester.pumpWidget(
      entrance(media: const MediaQueryData(textScaler: TextScaler.linear(2))),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(clock(tester).value, greaterThan(before));
    await tester.pumpAndSettle();
  });

  testWidgets('onComplete fires once, after the frame it ends in', (
    WidgetTester tester,
  ) async {
    final List<SchedulerPhase> completions = <SchedulerPhase>[];
    // A MediaQuery from the start, so the change below keeps the tree's
    // shape and reaches the same scope.
    await tester.pumpWidget(
      entrance(
        media: const MediaQueryData(),
        onComplete: () =>
            completions.add(SchedulerBinding.instance.schedulerPhase),
      ),
    );

    await tester.pump(AppDurations.entrance - const Duration(milliseconds: 1));
    expect(completions, isEmpty);
    // The first frame past the end — a controller completes on the tick
    // after its last value.
    await tester.pump(const Duration(milliseconds: 16));
    expect(completions, <SchedulerPhase>[SchedulerPhase.postFrameCallbacks]);

    // Nothing later fires it again — not a rebuild, not a MediaQuery change.
    await tester.pumpWidget(
      entrance(
        media: const MediaQueryData(textScaler: TextScaler.linear(2)),
        onComplete: () =>
            completions.add(SchedulerBinding.instance.schedulerPhase),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(completions, hasLength(1));
  });

  testWidgets('reduced motion turned on mid-run jumps to the end', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(entrance(media: const MediaQueryData()));
    await tester.pump(const Duration(milliseconds: 150));
    final Animation<double> entranceClock = clock(tester);
    expect(entranceClock.value, lessThan(1));

    await tester.pumpWidget(
      entrance(media: const MediaQueryData(disableAnimations: true)),
    );

    expect(entranceClock.value, 1);
    expect(opacity(tester, last), 1);
    expect(atRest(tester, last), isTrue);
  });

  // The splash places items by time and shortens them to end with its
  // intro: opacity over the first half of the item's own length.
  testWidgets('an item placed by time runs over its own length', (
    WidgetTester tester,
  ) async {
    const Key tagline = Key('tagline');
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(AppDesign.width, AppDesign.height),
        builder: (_, _) => const MaterialApp(
          home: EntranceScope(
            duration: AppDurations.splashIntro,
            child: EntranceItem(
              at: AppMotion.introTaglineAt,
              length: Duration(milliseconds: 340),
              rise: AppMotion.riseSmall,
              child: Text('Tagline', key: tagline),
            ),
          ),
        ),
      ),
    );

    await tester.pump(AppMotion.introTaglineAt);
    expect(opacity(tester, tagline), 0);
    await tester.pump(const Duration(milliseconds: 170));
    expect(opacity(tester, tagline), moreOrLessEquals(1));
    expect(atRest(tester, tagline), isFalse);
    await tester.pump(const Duration(milliseconds: 170));
    expect(atRest(tester, tagline), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('onComplete never fires when disposed mid-run', (
    WidgetTester tester,
  ) async {
    int completions = 0;
    await tester.pumpWidget(entrance(onComplete: () => completions++));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));

    expect(completions, 0);
  });

  testWidgets('covered by a push mid-run, it jumps to its end', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(entrance());
    await tester.pump(const Duration(milliseconds: 150));
    final NavigatorState navigator = tester.state(find.byType(Navigator));
    final Animation<double> entranceClock = clock(tester);
    expect(entranceClock.value, lessThan(1));

    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const Text('Login')),
    );
    await tester.pump();
    expect(entranceClock.value, 1);

    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();

    // Back on the screen: complete, not replaying.
    expect(clock(tester).value, 1);
    expect(opacity(tester, last), 1);
    expect(atRest(tester, last), isTrue);
  });
}
