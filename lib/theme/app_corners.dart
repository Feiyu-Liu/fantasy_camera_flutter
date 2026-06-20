import 'package:flutter/cupertino.dart';
import 'package:smooth_corner/smooth_corner.dart';

abstract final class AppCorners {
  static const double controlRadius = 10;
  static const double smoothness = 0.8;

  static BorderRadius get controlBorderRadius =>
      BorderRadius.circular(controlRadius);

  static SmoothRectangleBorder controlShape({
    BorderSide side = BorderSide.none,
    BorderRadiusGeometry? borderRadius,
  }) {
    return SmoothRectangleBorder(
      borderRadius: borderRadius ?? controlBorderRadius,
      smoothness: smoothness,
      side: side,
    );
  }

  static ShapeDecoration controlDecoration({
    required Color color,
    BorderSide side = BorderSide.none,
    BorderRadiusGeometry? borderRadius,
  }) {
    return ShapeDecoration(
      color: color,
      shape: controlShape(side: side, borderRadius: borderRadius),
    );
  }
}
