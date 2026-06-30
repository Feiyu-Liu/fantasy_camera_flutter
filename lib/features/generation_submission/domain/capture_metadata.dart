import 'generation_record.dart';

enum CaptureFocalLengthSource {
  avcaptureNominal('avcapture_nominal'),
  exif('exif');

  const CaptureFocalLengthSource(this.wireValue);

  final String wireValue;
}

class CaptureMetadata {
  const CaptureMetadata({
    required this.focalLength35mmEquivalentMm,
    required this.focalLengthSource,
  });

  final int focalLength35mmEquivalentMm;
  final CaptureFocalLengthSource focalLengthSource;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'focalLength35mmEquivalentMm': focalLength35mmEquivalentMm,
      'focalLengthSource': focalLengthSource.wireValue,
    };
  }
}

class CameraCaptureMetadataSnapshot {
  const CameraCaptureMetadataSnapshot({
    required this.focalLength35mmEquivalentMm,
  });

  final int focalLength35mmEquivalentMm;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'focalLength35mmEquivalentMm': focalLength35mmEquivalentMm,
    };
  }

  static CameraCaptureMetadataSnapshot? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final int? focalLength = _readInt(value['focalLength35mmEquivalentMm']);
    if (!_isUsableFocalLength(focalLength)) {
      return null;
    }
    return CameraCaptureMetadataSnapshot(
      focalLength35mmEquivalentMm: focalLength!,
    );
  }
}

CaptureMetadata? resolveCaptureMetadata({
  required GenerationRecordOriginalSourceType originalSourceType,
  required Map<String, Object> sourceExif,
  CameraCaptureMetadataSnapshot? cameraCaptureMetadataSnapshot,
}) {
  if (originalSourceType == GenerationRecordOriginalSourceType.camera &&
      cameraCaptureMetadataSnapshot != null) {
    return CaptureMetadata(
      focalLength35mmEquivalentMm:
          cameraCaptureMetadataSnapshot.focalLength35mmEquivalentMm,
      focalLengthSource: CaptureFocalLengthSource.avcaptureNominal,
    );
  }

  final int? exifFocalLength = readExifFocalLength35mmEquivalent(sourceExif);
  if (!_isUsableFocalLength(exifFocalLength)) {
    return null;
  }
  return CaptureMetadata(
    focalLength35mmEquivalentMm: exifFocalLength!,
    focalLengthSource: CaptureFocalLengthSource.exif,
  );
}

int? readExifFocalLength35mmEquivalent(Map<String, Object> sourceExif) {
  return _readIntFromKeys(sourceExif, const <String>[
    'FocalLenIn35mmFilm',
    'FocalLengthIn35mmFilm',
  ]);
}

int? _readIntFromKeys(Map<String, Object> values, List<String> keys) {
  for (final String key in keys) {
    final int? parsed = _readInt(values[key]);
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double && value.isFinite) {
    return value.round();
  }
  if (value is String) {
    final int? parsedInt = int.tryParse(value.trim());
    if (parsedInt != null) {
      return parsedInt;
    }
    final double? parsedDouble = double.tryParse(value.trim());
    if (parsedDouble != null && parsedDouble.isFinite) {
      return parsedDouble.round();
    }
    final List<String> rationalParts = value.split('/');
    if (rationalParts.length == 2) {
      final double? numerator = double.tryParse(rationalParts[0].trim());
      final double? denominator = double.tryParse(rationalParts[1].trim());
      if (numerator != null &&
          denominator != null &&
          denominator != 0 &&
          numerator.isFinite &&
          denominator.isFinite) {
        return (numerator / denominator).round();
      }
    }
  }
  return null;
}

bool _isUsableFocalLength(int? value) {
  return value != null && value >= 5 && value <= 300;
}

CameraCaptureMetadataSnapshot? cameraCaptureMetadataSnapshotFromLens({
  required double? nominalFocalLength35mm,
  required double currentRawZoom,
  required double displayZoomMultiplier,
}) {
  if (nominalFocalLength35mm == null ||
      !nominalFocalLength35mm.isFinite ||
      nominalFocalLength35mm <= 0 ||
      !currentRawZoom.isFinite ||
      currentRawZoom <= 0 ||
      !displayZoomMultiplier.isFinite ||
      displayZoomMultiplier <= 0) {
    return null;
  }

  final int focalLength =
      (nominalFocalLength35mm * currentRawZoom * displayZoomMultiplier).round();
  if (!_isUsableFocalLength(focalLength)) {
    return null;
  }
  return CameraCaptureMetadataSnapshot(
    focalLength35mmEquivalentMm: focalLength,
  );
}
