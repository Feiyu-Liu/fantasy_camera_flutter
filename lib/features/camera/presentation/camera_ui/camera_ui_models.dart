class CameraUiMode {
  const CameraUiMode({required this.id, required this.label});

  final String id;
  final String label;
}

class CameraZoomOption {
  const CameraZoomOption({required this.id, required this.label});

  final String id;
  final String label;
}

class CameraZoomStop {
  const CameraZoomStop({required this.factor, required this.label});

  final double factor;
  final String label;
}

enum CameraFlashUiMode { off, on, unavailable }

enum CameraFacingUi { rear, front, unknown }
