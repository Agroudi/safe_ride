/// Every threshold the potential-incident detection uses, in one place.
///
/// **These are engineering starting points, chosen to be conservative —
/// not medically or scientifically validated accident-detection
/// parameters.** Phone GPS reports one fix every couple of seconds with
/// metres of error; a crash lasts a fraction of a second. What GPS can see is
/// the consequence — a fast drop from driving speed to standing still that
/// then lasts — and that is what these values look for, while staying
/// clear of ordinary braking, traffic lights and GPS noise. Tune them only
/// with recorded journeys, and keep the tests in step.
final class IncidentDetectionConfig {
  const IncidentDetectionConfig({
    this.maxSpeedAccuracy = 20,
    this.maxPositionAccuracy = 25,
    this.goodAccuracy = 10,
    this.mediumAccuracy = 15,
    this.maxFixAge = const Duration(seconds: 10),
    this.maxSpeedError = 2,
    this.preciseSpeedError = 1,
    this.movingSpeed = 8.3,
    this.stoppedSpeed = 1.4,
    this.resumeSpeed = 2.8,
    this.stillSpeed = 1.0,
    this.decelerationWindow = const Duration(seconds: 4),
    this.minDeceleration = 4.0,
    this.mediumDeceleration = 5.5,
    this.highDeceleration = 7.0,
    this.sustainWindow = const Duration(seconds: 15),
    this.confirmStill = const Duration(seconds: 15),
    this.confirmStillUnsure = const Duration(seconds: 45),
    this.confirmTimeout = const Duration(seconds: 30),
    this.confirmRadius = 15,
    this.confirmFixes = 5,
    this.confirmGap = const Duration(seconds: 6),
    this.agreeingFixes = 2,
    this.movedDistance = 200,
    this.stopRadius = 30,
    this.resumeDistance = 50,
    this.stopDuration = const Duration(minutes: 5),
    this.maxFixGap = const Duration(seconds: 60),
    this.steadyFixGap = const Duration(seconds: 30),
    this.stopAfterDeceleration = const Duration(seconds: 60),
    this.queueCreeps = 2,
    this.arrivalRadius = 150,
    this.signalLostAfter = const Duration(seconds: 60),
    this.suspendedGap = const Duration(seconds: 30),
  });

  // Which readings are trusted.

  /// A speed counts only from a fix this accurate (metres). GPS speed comes
  /// from Doppler shift and holds up better than position, but a poor fix
  /// usually means poor speed too.
  final double maxSpeedAccuracy;

  /// A position counts for a stop only this accurate (metres): the
  /// tracker's own limit for a route point (50 m) halved.
  final double maxPositionAccuracy;

  /// "Good" accuracy (metres), needed for high confidence; "fair", needed
  /// for medium.
  final double goodAccuracy;
  final double mediumAccuracy;

  /// A fix older than this on arrival is stale and ignored.
  final Duration maxFixAge;

  /// A speed whose own error is above this (m/s) is ignored; when the phone
  /// does not report the error, confidence is capped at medium.
  final double maxSpeedError;

  /// Speed error (m/s) needed for high confidence.
  final double preciseSpeedError;

  // Speeds (m/s).

  /// "Driving": 30 km/h. Below it a quick stop is no surprise (walking,
  /// parking, a slow street).
  final double movingSpeed;

  /// "Stopped": 5 km/h — GPS rarely reads exactly 0 when still.
  final double stoppedSpeed;

  /// "Moving again": 10 km/h, well above GPS jitter while still.
  final double resumeSpeed;

  /// "Still", for a long stop: 3.6 km/h.
  final double stillSpeed;

  // Sudden deceleration.

  /// The drop must happen between two readings at most this far apart —
  /// with fixes every ~2 s, one or two intervals.
  final Duration decelerationWindow;

  /// Least deceleration (m/s²): 4.0 ≈ 0.4 g. Ordinary braking to a light is
  /// around 1.5–3 m/s²; firm braking reaches 4–6; an emergency stop on dry
  /// road 7–9. Below 4 is never reported.
  final double minDeceleration;

  /// Deceleration (m/s²) needed for medium (≈0.56 g) and high (≈0.7 g)
  /// confidence — only together with good, consistent data.
  final double mediumDeceleration;
  final double highDeceleration;

  /// "Was really driving": at least two readings at driving speed within
  /// this window before the drop, so one wild reading cannot start it.
  final Duration sustainWindow;

  /// The drop is reported only after staying put this long — a hard brake
  /// that drives on is not an incident — and then only when its evidence is
  /// strong enough for high confidence.
  final Duration confirmStill;

  /// Weaker evidence must stay put this long before it is reported at all. A
  /// hard brake for a red light shows the same GPS drop as a collision; what
  /// tells them apart is that the light turns green. 45 s outlasts most
  /// waits, and costs a real event 30 s.
  final Duration confirmStillUnsure;

  /// No fix for this long while waiting, and the drop is dropped: missing
  /// data is never treated as confirmation. Counted from the last fix, not
  /// from the drop.
  final Duration confirmTimeout;

  /// "Staying put" (metres; or twice the fix's accuracy, if larger). A
  /// stopped car's fixes wander a few metres; a queue crawls further.
  final double confirmRadius;

  /// Fixes needed while staying put, at most [confirmGap] apart, for high
  /// confidence: with a fix every 2 s, 15 s gives about seven.
  final int confirmFixes;
  final Duration confirmGap;

  /// Fixes in a row that must agree before the engine believes a change —
  /// moving away, creeping, having set off. One reading can be a glitch.
  final int agreeingFixes;

  // Prolonged stop.

  /// The journey must first have moved this far (metres) or reached driving
  /// speed: waiting before setting off is not unusual.
  final double movedDistance;

  /// Staying within this radius (metres; or twice the fix's accuracy, if
  /// larger) counts as still.
  final double stopRadius;

  /// Leaving by this much (metres) counts as moving again.
  final double resumeDistance;

  /// Still for this long during a journey is reported: 5 minutes, beyond a
  /// red light or a level crossing; a fuel stop or a shop still reaches it,
  /// which is why a stop alone is at most medium confidence.
  final Duration stopDuration;

  /// A gap between fixes longer than this restarts the stop count: no data
  /// is not "still".
  final Duration maxFixGap;

  /// Fixes at most this far apart throughout make a stop's data "steady"
  /// (needed for medium).
  final Duration steadyFixGap;

  /// A stop that begins within this time of a sudden deceleration of medium
  /// or high confidence is high confidence (when its data is good).
  final Duration stopAfterDeceleration;

  /// Inching forward this many times during a stop makes it a queue: low.
  final int queueCreeps;

  /// A stop this close (metres, plus the fix's accuracy) to the journey's
  /// planned destination has arrived: low. The same reach Batch 15 uses for
  /// "on the planned route".
  final double arrivalRadius;

  // Tracking interruption.

  /// No usable fix for this long, with permission and services on, is a
  /// signal loss — reported as tracking interrupted, never as an incident
  /// of movement.
  final Duration signalLostAfter;

  /// The tracker ticks every 5 s; a gap this long between ticks means the
  /// app was suspended.
  final Duration suspendedGap;
}
