import 'package:flutter/widgets.dart';

class CameraPhotoOverlayPanel extends InheritedWidget {
  const CameraPhotoOverlayPanel({
    required this.enabled,
    required super.child,
    super.key,
  });

  final bool enabled;

  static bool maybeOf(BuildContext context) {
    final CameraPhotoOverlayPanel? panel = context
        .dependOnInheritedWidgetOfExactType<CameraPhotoOverlayPanel>();
    return panel?.enabled ?? false;
  }

  @override
  bool updateShouldNotify(CameraPhotoOverlayPanel oldWidget) {
    return enabled != oldWidget.enabled;
  }
}
