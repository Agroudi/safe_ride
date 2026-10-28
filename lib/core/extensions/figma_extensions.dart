import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:safe_ride/core/constants/app_constants.dart';

/// Converts a number read off the Figma board into a responsive size.
///
/// Write the value that is literally in the design and append `.fx` / `.fsp`.
/// Never pre-multiply by hand: that hides the source value and puts the scale
/// factor in two places.
const double _figmaToDesign = AppDesign.width / AppDesign.figmaFrameWidth;

extension FigmaNum on num {
  /// A Figma size / spacing value as a responsive logical pixel.
  double get fx => (this * _figmaToDesign).r;

  /// A Figma font size as a responsive font size.
  double get fsp => (this * _figmaToDesign).sp;
}
