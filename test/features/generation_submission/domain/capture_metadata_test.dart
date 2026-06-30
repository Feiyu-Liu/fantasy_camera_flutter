import 'package:fantasy_camera_flutter/features/generation_submission/domain/capture_metadata.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera lens metadata uses raw zoom and display multiplier', () {
    expect(
      cameraCaptureMetadataSnapshotFromLens(
        nominalFocalLength35mm: 26,
        currentRawZoom: 1,
        displayZoomMultiplier: 0.5,
      )?.focalLength35mmEquivalentMm,
      13,
    );
    expect(
      cameraCaptureMetadataSnapshotFromLens(
        nominalFocalLength35mm: 26,
        currentRawZoom: 1,
        displayZoomMultiplier: 1,
      )?.focalLength35mmEquivalentMm,
      26,
    );
    expect(
      cameraCaptureMetadataSnapshotFromLens(
        nominalFocalLength35mm: 26,
        currentRawZoom: 2,
        displayZoomMultiplier: 1,
      )?.focalLength35mmEquivalentMm,
      52,
    );
  });

  test('camera capture prefers AVCapture metadata over EXIF', () {
    final CaptureMetadata? metadata = resolveCaptureMetadata(
      originalSourceType: GenerationRecordOriginalSourceType.camera,
      sourceExif: const <String, Object>{'FocalLenIn35mmFilm': 35},
      cameraCaptureMetadataSnapshot: const CameraCaptureMetadataSnapshot(
        focalLength35mmEquivalentMm: 26,
      ),
    );

    expect(metadata?.toJson(), <String, Object?>{
      'focalLength35mmEquivalentMm': 26,
      'focalLengthSource': 'avcapture_nominal',
    });
  });

  test('gallery import falls back to EXIF focal length', () {
    final CaptureMetadata? metadata = resolveCaptureMetadata(
      originalSourceType: GenerationRecordOriginalSourceType.gallery,
      sourceExif: const <String, Object>{'FocalLengthIn35mmFilm': '52'},
      cameraCaptureMetadataSnapshot: const CameraCaptureMetadataSnapshot(
        focalLength35mmEquivalentMm: 26,
      ),
    );

    expect(metadata?.toJson(), <String, Object?>{
      'focalLength35mmEquivalentMm': 52,
      'focalLengthSource': 'exif',
    });
  });

  test('missing or unusable focal metadata resolves to null', () {
    expect(
      resolveCaptureMetadata(
        originalSourceType: GenerationRecordOriginalSourceType.gallery,
        sourceExif: const <String, Object>{},
      ),
      isNull,
    );
    expect(
      cameraCaptureMetadataSnapshotFromLens(
        nominalFocalLength35mm: 26,
        currentRawZoom: 100,
        displayZoomMultiplier: 1,
      ),
      isNull,
    );
  });
}
