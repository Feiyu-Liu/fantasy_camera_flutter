enum CameraCaptureAspectRatio {
  fourThree(
    storageValue: 'fourThree',
    label: '4:3',
    portraitWidthToHeight: 3 / 4,
    landscapeWidthToHeight: 4 / 3,
  ),
  square(
    storageValue: 'square',
    label: '1:1',
    portraitWidthToHeight: 1,
    landscapeWidthToHeight: 1,
  );

  const CameraCaptureAspectRatio({
    required this.storageValue,
    required this.label,
    required this.portraitWidthToHeight,
    required this.landscapeWidthToHeight,
  });

  final String storageValue;
  final String label;
  final double portraitWidthToHeight;
  final double landscapeWidthToHeight;

  double widthToHeight({required bool isLandscape}) {
    return isLandscape ? landscapeWidthToHeight : portraitWidthToHeight;
  }

  CameraCaptureAspectRatio get next => switch (this) {
    CameraCaptureAspectRatio.fourThree => CameraCaptureAspectRatio.square,
    CameraCaptureAspectRatio.square => CameraCaptureAspectRatio.fourThree,
  };

  static CameraCaptureAspectRatio fromStorageValue(String? value) {
    return CameraCaptureAspectRatio.values.firstWhere(
      (CameraCaptureAspectRatio ratio) => ratio.storageValue == value,
      orElse: () => CameraCaptureAspectRatio.fourThree,
    );
  }

  static CameraCaptureAspectRatio? fromNullableStorageValue(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final CameraCaptureAspectRatio ratio
        in CameraCaptureAspectRatio.values) {
      if (ratio.storageValue == value) {
        return ratio;
      }
    }
    return null;
  }
}
