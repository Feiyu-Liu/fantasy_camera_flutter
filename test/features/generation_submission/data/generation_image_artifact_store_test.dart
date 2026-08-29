import 'dart:io';

import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_image_artifact_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late ApplicationCacheGenerationImageArtifactStore store;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'generation-image-artifact-store-',
    );
    store = ApplicationCacheGenerationImageArtifactStore(
      cacheDirectoryProvider: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('reuses only a valid JPEG with the same processing key', () async {
    final File source = File('${temporaryDirectory.path}/source.heic');
    await source.writeAsBytes(<int>[1, 2, 3, 4]);

    final GenerationUploadArtifactTarget initial = await store
        .resolveUploadTarget(
          recordId: 'record-1',
          sourcePath: source.path,
          maxSide: 2048,
          quality: 90,
          keepExif: false,
        );
    expect(initial.isReusable, isFalse);

    await File(initial.path).writeAsBytes(<int>[0xff, 0xd8, 0xff, 0xd9]);
    final GenerationUploadArtifactTarget reusable = await store
        .resolveUploadTarget(
          recordId: 'record-1',
          sourcePath: source.path,
          maxSide: 2048,
          quality: 90,
          keepExif: false,
        );
    expect(reusable.path, initial.path);
    expect(reusable.isReusable, isTrue);

    final GenerationUploadArtifactTarget changedQuality = await store
        .resolveUploadTarget(
          recordId: 'record-1',
          sourcePath: source.path,
          maxSide: 2048,
          quality: 85,
          keepExif: false,
        );
    expect(changedQuality.path, isNot(initial.path));
    expect(changedQuality.isReusable, isFalse);
  });

  test('rejects non-JPEG data at an upload cache path', () async {
    final File source = File('${temporaryDirectory.path}/source.heic');
    await source.writeAsBytes(<int>[1, 2, 3]);
    final GenerationUploadArtifactTarget target = await store
        .resolveUploadTarget(
          recordId: 'record-2',
          sourcePath: source.path,
          maxSide: 2048,
          quality: 90,
          keepExif: false,
        );
    await File(target.path).writeAsBytes(<int>[1, 2, 3, 4]);

    final GenerationUploadArtifactTarget resolved = await store
        .resolveUploadTarget(
          recordId: 'record-2',
          sourcePath: source.path,
          maxSide: 2048,
          quality: 90,
          keepExif: false,
        );

    expect(resolved.isReusable, isFalse);
  });

  test('commits a partial file and removes all record artifacts', () async {
    final String finalPath = await store.resultArtifactPath(
      'record/unsafe',
      suffix: 'heic',
    );
    final String partialPath = await store.createPartialPath(finalPath);
    await File(finalPath).writeAsBytes(<int>[1, 2, 3]);
    await File(partialPath).writeAsBytes(<int>[9, 8, 7]);

    await store.commitPartial(partialPath: partialPath, finalPath: finalPath);

    expect(await File(finalPath).readAsBytes(), <int>[9, 8, 7]);
    expect(await File(partialPath).exists(), isFalse);

    await store.deleteRecordArtifacts('record/unsafe');
    expect(await File(finalPath).exists(), isFalse);
  });
}
