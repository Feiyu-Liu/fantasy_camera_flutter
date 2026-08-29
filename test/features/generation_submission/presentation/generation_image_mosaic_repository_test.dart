import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_image_mosaic_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('samples image regions in row-major spatial order', () {
    final GenerationImagePixelBuffer pixels = _quadrantBuffer();

    final List<Color> colors = sampleGenerationImageMosaicColors(
      pixels,
      rows: 2,
      columns: 2,
    );

    expect(colors, hasLength(4));
    _expectDominant(colors[0], red: true);
    _expectDominant(colors[1], green: true);
    _expectDominant(colors[2], blue: true);
    expect(colors[3].r, greaterThan(colors[3].b));
    expect(colors[3].g, greaterThan(colors[3].b));
    expect(colors.every((Color color) => color.a == 1), isTrue);
  });

  test('uses the centered BoxFit.cover crop before sampling', () {
    final List<Color> source = <Color>[
      for (int row = 0; row < 4; row += 1) ...<Color>[
        const Color(0xFFFF0000),
        const Color(0xFF00FF00),
        const Color(0xFF00FF00),
        const Color(0xFF00FF00),
        const Color(0xFF00FF00),
        const Color(0xFF0000FF),
      ],
    ];
    final GenerationImagePixelBuffer pixels = _bufferFromColors(
      width: 6,
      height: 4,
      colors: source,
    );

    final List<Color> colors = sampleGenerationImageMosaicColors(
      pixels,
      rows: 2,
      columns: 2,
    );

    expect(colors, hasLength(4));
    for (final Color color in colors) {
      _expectDominant(color, green: true);
    }
  });

  test('averages regions in linear RGB instead of gamma-encoded RGB', () {
    final GenerationImagePixelBuffer pixels = _bufferFromColors(
      width: 2,
      height: 1,
      colors: const <Color>[Color(0xFF000000), Color(0xFFFFFFFF)],
    );

    final Color average = averageGenerationImageRegion(
      pixels,
      const Rect.fromLTWH(0, 0, 2, 1),
    );

    expect((average.r * 255).round(), inInclusiveRange(187, 189));
    expect((average.g * 255).round(), inInclusiveRange(187, 189));
    expect((average.b * 255).round(), inInclusiveRange(187, 189));
    expect(average.a, 1);
  });

  test('composites transparent source pixels onto white and stays opaque', () {
    final GenerationImagePixelBuffer pixels = GenerationImagePixelBuffer(
      width: 1,
      height: 1,
      rgbaBytes: Uint8List.fromList(<int>[0xFF, 0x00, 0x00, 0x00]),
    );

    final Color average = averageGenerationImageRegion(
      pixels,
      const Rect.fromLTWH(0, 0, 1, 1),
    );

    expect(average, const Color(0xFFFFFFFF));
  });

  test('fallback contains one fully opaque color per cell', () {
    final GenerationImageMosaic fallback = GenerationImageMosaic.fallback(
      rows: 8,
      columns: 6,
    );

    expect(fallback.cellColors, hasLength(48));
    expect(fallback.cellColors.toSet().length, greaterThan(1));
    expect(fallback.cellColors.every((Color color) => color.a == 1), isTrue);
  });

  test('returns and caches the fallback when extraction fails', () async {
    int loadCount = 0;
    final CachedGenerationImageMosaicRepository repository =
        CachedGenerationImageMosaicRepository(
          fingerprintLoader: (_) async => 'v1',
          pixelLoader:
              (_, {required int targetWidth, required int targetHeight}) async {
                loadCount += 1;
                throw const FormatException('invalid');
              },
        );

    final GenerationImageMosaic mosaic = await repository.extract(
      'bad',
      rows: 8,
      columns: 6,
    );
    await repository.extract('bad', rows: 8, columns: 6);

    expect(mosaic.cellColors, hasLength(48));
    expect(loadCount, 1);
  });

  test('deduplicates concurrent extraction and reuses the cache', () async {
    final Completer<GenerationImagePixelBuffer> pixels =
        Completer<GenerationImagePixelBuffer>();
    int loadCount = 0;
    final CachedGenerationImageMosaicRepository repository =
        CachedGenerationImageMosaicRepository(
          fingerprintLoader: (_) async => 'v1',
          pixelLoader:
              (_, {required int targetWidth, required int targetHeight}) {
                loadCount += 1;
                return pixels.future;
              },
        );

    final Future<GenerationImageMosaic> first = repository.extract(
      'same',
      rows: 2,
      columns: 2,
    );
    final Future<GenerationImageMosaic> second = repository.extract(
      'same',
      rows: 2,
      columns: 2,
    );
    expect(identical(first, second), isTrue);

    pixels.complete(_solidBuffer(const Color(0xFF336699)));
    await Future.wait(<Future<GenerationImageMosaic>>[first, second]);
    await repository.extract('same', rows: 2, columns: 2);

    expect(loadCount, 1);
  });

  test(
    'invalidates a cached mosaic when the file fingerprint changes',
    () async {
      String fingerprint = 'v1';
      int loadCount = 0;
      final CachedGenerationImageMosaicRepository repository =
          CachedGenerationImageMosaicRepository(
            fingerprintLoader: (_) async => fingerprint,
            pixelLoader:
                (
                  _, {
                  required int targetWidth,
                  required int targetHeight,
                }) async {
                  loadCount += 1;
                  return _solidBuffer(const Color(0xFF336699));
                },
          );

      await repository.extract('same', rows: 2, columns: 2);
      fingerprint = 'v2';
      await repository.extract('same', rows: 2, columns: 2);

      expect(loadCount, 2);
    },
  );

  test('evicts the least recently used request at capacity', () async {
    final Map<String, int> loads = <String, int>{};
    final CachedGenerationImageMosaicRepository repository =
        CachedGenerationImageMosaicRepository(
          capacity: 2,
          fingerprintLoader: (String path) async => '$path-v1',
          pixelLoader:
              (
                String path, {
                required int targetWidth,
                required int targetHeight,
              }) async {
                loads.update(path, (int count) => count + 1, ifAbsent: () => 1);
                return _solidBuffer(const Color(0xFF336699));
              },
        );

    await repository.extract('a', rows: 2, columns: 2);
    await repository.extract('b', rows: 2, columns: 2);
    await repository.extract('a', rows: 2, columns: 2);
    await repository.extract('c', rows: 2, columns: 2);
    await repository.extract('b', rows: 2, columns: 2);

    expect(loads, <String, int>{'a': 1, 'b': 2, 'c': 1});
  });

  test('uses grid dimensions as part of the cache request', () async {
    int loadCount = 0;
    final CachedGenerationImageMosaicRepository repository =
        CachedGenerationImageMosaicRepository(
          fingerprintLoader: (_) async => 'v1',
          pixelLoader:
              (_, {required int targetWidth, required int targetHeight}) async {
                loadCount += 1;
                return _solidBuffer(const Color(0xFF336699));
              },
        );

    await repository.extract('same', rows: 2, columns: 2);
    await repository.extract('same', rows: 3, columns: 2);

    expect(loadCount, 2);
  });

  test('decodes the existing PNG fixture into a sampled mosaic', () async {
    final GenerationImagePixelBuffer pixels =
        await loadGenerationImagePixelBuffer(
          'test/fixtures/image_pipeline/res.png',
          targetWidth: 48,
          targetHeight: 64,
        );
    final List<Color> colors = sampleGenerationImageMosaicColors(
      pixels,
      rows: 8,
      columns: 6,
    );

    expect(pixels.width, greaterThan(0));
    expect(pixels.height, greaterThan(0));
    expect(pixels.width, greaterThanOrEqualTo(48));
    expect(pixels.height, greaterThanOrEqualTo(64));
    expect(colors, hasLength(48));
    expect(colors.every((Color color) => color.a == 1), isTrue);
  });

  test('decodes the existing HEIC fixture into a sampled mosaic', () async {
    final GenerationImagePixelBuffer pixels =
        await loadGenerationImagePixelBuffer(
          'test/fixtures/image_pipeline/raw.HEIC',
          targetWidth: 48,
          targetHeight: 64,
        );
    final List<Color> colors = sampleGenerationImageMosaicColors(
      pixels,
      rows: 8,
      columns: 6,
    );

    expect(pixels.width, greaterThanOrEqualTo(48));
    expect(pixels.height, greaterThanOrEqualTo(64));
    expect(colors, hasLength(48));
    expect(colors.every((Color color) => color.a == 1), isTrue);
  });

  test('creates translucent base colors without changing sampled RGB', () {
    final List<Color> colors = generationImageMosaicBaseColors(const <Color>[
      Color(0x80336699),
      Color(0xFF112233),
    ]);

    expect(colors, hasLength(2));
    expect(
      colors.every((Color color) => color.a == generationImageMosaicBaseAlpha),
      isTrue,
    );
    expect(colors[0].withValues(alpha: 1), const Color(0xFF336699));
    expect(colors[1].withValues(alpha: 1), const Color(0xFF112233));
  });

  test('uses the sampled colors unchanged as fully opaque light-up colors', () {
    final List<Color> colors = generationImageMosaicLightUpColors(const <Color>[
      Color(0x80336699),
      Color(0xFF112233),
    ]);

    expect(colors, const <Color>[Color(0xFF336699), Color(0xFF112233)]);
  });
}

GenerationImagePixelBuffer _quadrantBuffer() {
  return _bufferFromColors(
    width: 4,
    height: 4,
    colors: <Color>[
      for (int row = 0; row < 4; row += 1)
        for (int column = 0; column < 4; column += 1)
          if (row < 2 && column < 2)
            const Color(0xFFFF0000)
          else if (row < 2)
            const Color(0xFF00FF00)
          else if (column < 2)
            const Color(0xFF0000FF)
          else
            const Color(0xFFFFFF00),
    ],
  );
}

GenerationImagePixelBuffer _solidBuffer(Color color) {
  return _bufferFromColors(
    width: 4,
    height: 4,
    colors: List<Color>.filled(16, color),
  );
}

GenerationImagePixelBuffer _bufferFromColors({
  required int width,
  required int height,
  required List<Color> colors,
}) {
  expect(colors, hasLength(width * height));
  final Uint8List bytes = Uint8List(width * height * 4);
  for (int index = 0; index < colors.length; index += 1) {
    final int argb = colors[index].toARGB32();
    final int offset = index * 4;
    bytes[offset] = (argb >> 16) & 0xFF;
    bytes[offset + 1] = (argb >> 8) & 0xFF;
    bytes[offset + 2] = argb & 0xFF;
    bytes[offset + 3] = (argb >> 24) & 0xFF;
  }
  return GenerationImagePixelBuffer(
    width: width,
    height: height,
    rgbaBytes: bytes,
  );
}

void _expectDominant(
  Color color, {
  bool red = false,
  bool green = false,
  bool blue = false,
}) {
  final int redChannel = (color.r * 255).round();
  final int greenChannel = (color.g * 255).round();
  final int blueChannel = (color.b * 255).round();
  if (red) {
    expect(redChannel, greaterThan(greenChannel + 40));
    expect(redChannel, greaterThan(blueChannel + 40));
  }
  if (green) {
    expect(greenChannel, greaterThan(redChannel + 40));
    expect(greenChannel, greaterThan(blueChannel + 40));
  }
  if (blue) {
    expect(blueChannel, greaterThan(redChannel + 40));
    expect(blueChannel, greaterThan(greenChannel + 40));
  }
}
