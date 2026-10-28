/// Every asset path in one place, so a renamed file breaks one line, not ten.
abstract final class AppAssets {
  static const String _icons = 'assets/icons';
  static const String _images = 'assets/images';

  /// The SafeRide shield-and-road mark: the source of truth for its shape.
  /// The app paints it from `BrandMarkGeometry`, a hand transcription that
  /// `brand_mark_test` compares against this file pixel for pixel.
  static const String logoMark = '$_images/logo_mark.svg';

  /// A `<`, drawn for left-to-right — `DirectionalSvg` mirrors it in Arabic.
  static const String chevronLeft = '$_icons/chevron_left.svg';

  static const String eyeOff = '$_icons/eye_off.svg';
}
