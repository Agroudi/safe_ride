import 'package:flutter/material.dart';

/// The five curves every animation in the app uses.
///
/// Opacity always runs **linear** inside its own `Interval` and is never
/// curved twice. No curve here overshoots — elastic, bounce and back curves
/// are banned, and so is linear for anything that moves (`app_motion_test`
/// samples every one).
abstract final class AppCurves {
  /// The splash morph. Also the curve `Hero` hard-codes for its flights, so
  /// the mark moves on one curve from the system splash to its last screen.
  static const Curve seal = Curves.fastOutSlowIn;

  /// Between two resting places: Next / back `animateToPage`, press down,
  /// `AnimatedSize`, the theme crossfade. A page passes halfway at 80 ms of
  /// 400.
  static const Curve move = Easing.standard;

  /// Arrivals: entrance rises and scales, rings opening, the orbit settle,
  /// a task route sliding in, a label in, press release, the splash rules.
  static const Curve enter = Easing.emphasizedDecelerate;

  /// Departures: the outgoing route's fade, a label out.
  static const Curve exit = Easing.emphasizedAccelerate;

  /// The splash lane dashes only: pull away, then brake. Peak speed comes at
  /// 320 ms, when the morph is already 78 % done, so the road reads as a beat
  /// of its own.
  static const Curve drive = Curves.easeInOutCubic;
}

/// Schedule offsets, distances and factors for motion. Distances are raw
/// design units — apply `.fx` at the use site — except the two marked **dp**.
abstract final class AppMotion {
  /// Beat 0 of a destination's entrance: when the incoming page's fade is
  /// under way (= [fadeOutEnd] × `AppDurations.medium`).
  static const Duration arrivalBeat = Duration(milliseconds: 140);

  /// One beat. Beat n = [arrivalBeat] + n × [stagger] (0..4 → 140, 200, 260,
  /// 320, 380 ms).
  static const Duration stagger = Duration(milliseconds: 60);

  /// When beat [n] of an entrance starts.
  static Duration beat(int n) => arrivalBeat + stagger * n;

  /// The splash morph and lane travel, on the 600 ms intro.
  static const Duration introMorphStart = Duration(milliseconds: 120);
  static const Duration introMorphEnd = Duration(milliseconds: 520);

  /// The tile fill reaches its gradient (it starts at [introMorphStart]).
  static const Duration introFillEnd = Duration(milliseconds: 360);

  /// The mark's colour, `onLaunchTile` → `onPrimary`.
  static const Duration introGlyphStart = Duration(milliseconds: 180);
  static const Duration introGlyphEnd = Duration(milliseconds: 360);

  /// The splash branding's offsets.
  static const Duration introTitleAt = Duration(milliseconds: 200);
  static const Duration introTaglineAt = Duration(milliseconds: 260);
  static const Duration introRulesAt = Duration(milliseconds: 320);

  /// When a seal flight lands (= `AppDurations.medium`); the onboarding
  /// badge's shadow ramps in over the following `AppDurations.short`.
  static const Duration sealLanding = Duration(milliseconds: 400);

  /// How far headlines, body copy and buttons rise into place.
  static const double rise = 16;

  /// How far the eyebrow label, tagline, footer and pill rise into place.
  static const double riseSmall = 8;

  /// How far a button label travels when it swaps.
  static const double labelShift = 6;

  /// How far a task route travels in from the reading direction's end side.
  static const double axis = 30;

  /// The onboarding scene's parallax per page (≈ 0.12 × width; never above
  /// 0.16 × width). Text never gets parallax.
  static const double sceneLag = 48;

  /// An item's opacity completes halfway through its own length.
  static const double fadeLead = 0.5;

  /// The outgoing page is gone by 140 ms of 400.
  static const double fadeOutEnd = 0.35;

  /// The incoming page fades in from 120 ms — a 20 ms overlap with
  /// [fadeOutEnd], so no frame is ever only background.
  static const double fadeInStart = 0.30;

  /// Onboarding copy is fully faded 60 % of a page away, so two paragraphs
  /// never compete.
  static const double copyFadeSpan = 0.6;

  /// The scale the decorative rings open from.
  static const double ringFrom = 0.72;

  /// Breaths per `AppDurations.haloCycle` — a whole number, so the loop has
  /// no seam (40 s / 8 = one breath every 5 s).
  static const int haloBreaths = 8;

  /// How far, in breaths, each ring trails the one inside it: the wave rolls
  /// outward from the logo.
  static const double haloLag = 0.12;

  /// How much a ring grows at the top of its breath (4 %).
  static const double haloSwell = 0.04;

  /// How much stronger a ring's colour is at the top of its breath (+60 %).
  static const double haloGlow = 0.6;

  /// The dots on a dotted orbit.
  static const int haloDots = 48;

  /// A button's scale while pressed.
  static const double pressScale = 0.98;

  /// Degrees the step-1 accent chips slide along their ring into place.
  static const double orbitSettle = 20;

  /// The glyph crossfade inside a tile ↔ badge seal flight.
  static const Interval shuttleCrossfade = Interval(0.3, 0.7);

  /// **dp**, not `.fx`: the diameter of the Android 12+ system-splash icon
  /// circle. Measured with [launchGlyph] on an API 36 emulator (420 dpi), in
  /// system light and dark: the held system splash and the Flutter splash's
  /// frame 0 coincide within 1 px. OEM icon masks may differ.
  static const double launchDisc = 160;

  /// **dp**: the mark's 48-unit box on the system splash (the 108-unit
  /// launcher canvas drawn at 240 dp, the mark scaled 1.2 → 57.6 / 108 × 240).
  static const double launchGlyph = 128;
}
