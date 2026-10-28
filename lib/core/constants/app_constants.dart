import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// The frame the UI is designed against.
///
/// ⚠️ **Set these three per project.** [width] / [height] are the logical size
/// the app lays out at; [figmaFrameWidth] is how wide the phone frame is *in the
/// Figma file*. Boards are often drawn at a scale (PrepAI's was 168.8pt wide for
/// a 390pt phone), and `.fx` / `.fsp` convert between the two so every screen
/// can be written with the numbers that are literally in the design.
abstract final class AppDesign {
  static const double width = 390;
  static const double height = 844;

  /// Equal to [width] when the Figma frame is drawn at real size.
  static const double figmaFrameWidth = 390;
}

/// The screen insets every page shares. Responsive, so getters rather than
/// constants.
abstract final class AppSpacing {
  /// Breathing room between the status bar and the first thing on a screen.
  /// Every screen opens on the same inset, so they line up when swiped between.
  static double get screenTop => 42.fx;

  /// The side gutter every form screen uses.
  static double get screenSide => 24.fx;
}

/// The shared corner radii: sheets, dialogs and tab highlights ([lg]), and
/// fully rounded ends ([pill]).
abstract final class AppRadius {
  static double get lg => 20.r;
  static double get pill => 999.r;
}

/// Animation and timing durations: three lengths for motion (touch, change in
/// place, movement) plus the schedules built from them. Offsets inside a
/// schedule, curves and distances live in `AppMotion` / `AppCurves`
/// (`app_motion.dart`); no screen writes a literal duration.
abstract final class AppDurations {
  /// A finger going down (`PressScale` in).
  static const Duration press = Duration(milliseconds: 100);

  /// A change in place: label swap, Skip fade, spinner / failure fade-in,
  /// `AnimatedSize`, press release, theme crossfade, badge shadow landing.
  static const Duration short = Duration(milliseconds: 200);

  /// Movement or arrival: every route transition and Hero flight, Next / back
  /// slide, each entrance item, the splash morph.
  static const Duration medium = Duration(milliseconds: 400);

  /// The still start of the splash intro, counted from the launch hand-off
  /// (`LaunchHandoff`): the system splash's image is seen to rest for a beat
  /// before it moves, so the hand-off itself is never part of the motion.
  static const Duration splashHold = Duration(milliseconds: 120);

  /// The splash logo's entrance: [splashHold] + the morph ([medium]) + 80 ms
  /// for the tagline and rules to land. Navigation waits for the later of
  /// this and the startup decision, so the brand is seen without padding a
  /// fast start; skipped entirely under reduced motion. ⚠️ Never lengthen it.
  static const Duration splashIntro = Duration(milliseconds: 600);

  /// One full loop of the rings around the logo (`HaloRings`): the dotted
  /// orbit turns once and `AppMotion.haloBreaths` breaths roll outward. The
  /// one animation in the app that never ends — calm by design, never a pulse.
  static const Duration haloCycle = Duration(seconds: 40);

  /// One screen's staged entrance: `AppMotion.arrivalBeat` (140) + 4 ×
  /// `AppMotion.stagger` (60) + [medium] (400). Derived — `app_motion_test`
  /// pins the sum, so change the parts, not this.
  static const Duration entrance = Duration(milliseconds: 780);

  /// The longest the startup session check may take before the splash offers
  /// a retry — the guarantee that it never spins forever.
  static const Duration startupTimeout = Duration(seconds: 8);

  /// The shortest a retried startup check shows its spinner. A check that
  /// fails again at once would otherwise change nothing on screen, and the
  /// retry would look — and, to a screen reader, sound — ignored.
  static const Duration startupRetryMinimum = Duration(milliseconds: 500);

  /// How long "press back again to leave" stays true, and how long the line
  /// saying so stays on screen — the two must be the same number, or the offer
  /// expires while it is still being made.
  static const Duration exitWindow = Duration(seconds: 2);

  /// How long a confirmation or a tip stays up (`AppNotification.success`,
  /// `.info`) before it leaves on its own.
  static const Duration noticeShort = Duration(seconds: 4);

  /// How long a warning or an error stays up — long enough to read twice.
  /// Under TalkBack every notification stays until dismissed.
  static const Duration noticeLong = Duration(seconds: 8);
}
