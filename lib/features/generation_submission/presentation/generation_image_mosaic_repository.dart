import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:material_color_utilities/hct/hct.dart';

import '../../../shared/core/app_logger.dart';
import '../../../theme/app_colors.dart';

const int _mosaicSamplesPerCell = 8;
const double _mosaicWhiteBlend = 0.08;
const double generationImageMosaicBaseAlpha = 0.1;

@immutable
class GenerationImageMosaic {
  GenerationImageMosaic({
    required this.rows,
    required this.columns,
    required Iterable<Color> cellColors,
  }) : assert(rows > 0),
       assert(columns > 0),
       assert(cellColors.length == rows * columns),
       cellColors = List<Color>.unmodifiable(cellColors);

  final int rows;
  final int columns;
  final List<Color> cellColors;

  factory GenerationImageMosaic.fallback({
    required int rows,
    required int columns,
  }) {
    final Hct yellow = Hct.fromInt(AppColors.accentYellow.toARGB32());
    final List<Color> tonalColors = <double>[72, 80, 88]
        .map(
          (double tone) => Color(
            Hct.from(yellow.hue, math.min(yellow.chroma, 56), tone).toInt(),
          ).withValues(alpha: 1),
        )
        .toList(growable: false);
    final int diagonalSpan = math.max(1, rows + columns - 2);
    return GenerationImageMosaic(
      rows: rows,
      columns: columns,
      cellColors: <Color>[
        for (int row = 0; row < rows; row += 1)
          for (int column = 0; column < columns; column += 1)
            tonalColors[((row + column) * tonalColors.length ~/ diagonalSpan)
                .clamp(0, tonalColors.length - 1)],
      ],
    );
  }
}

abstract interface class GenerationImageMosaicRepository {
  Future<GenerationImageMosaic> extract(
    String imagePath, {
    required int rows,
    required int columns,
  });
}

@immutable
class GenerationImagePixelBuffer {
  GenerationImagePixelBuffer({
    required this.width,
    required this.height,
    required Uint8List rgbaBytes,
  }) : assert(width > 0),
       assert(height > 0),
       assert(rgbaBytes.lengthInBytes == width * height * 4),
       rgbaBytes = Uint8List.fromList(rgbaBytes);

  final int width;
  final int height;
  final Uint8List rgbaBytes;
}

typedef GenerationImagePixelLoader =
    Future<GenerationImagePixelBuffer> Function(
      String imagePath, {
      required int targetWidth,
      required int targetHeight,
    });
typedef GenerationImageFingerprintLoader =
    Future<String> Function(String imagePath);

@immutable
class _MosaicRequestKey {
  const _MosaicRequestKey(this.imagePath, this.rows, this.columns);

  final String imagePath;
  final int rows;
  final int columns;

  @override
  bool operator ==(Object other) {
    return other is _MosaicRequestKey &&
        other.imagePath == imagePath &&
        other.rows == rows &&
        other.columns == columns;
  }

  @override
  int get hashCode => Object.hash(imagePath, rows, columns);
}

@immutable
class _CachedMosaic {
  const _CachedMosaic({required this.fingerprint, required this.mosaic});

  final String fingerprint;
  final GenerationImageMosaic mosaic;
}

class CachedGenerationImageMosaicRepository
    implements GenerationImageMosaicRepository {
  CachedGenerationImageMosaicRepository({
    GenerationImagePixelLoader? pixelLoader,
    GenerationImageFingerprintLoader? fingerprintLoader,
    this.capacity = 32,
  }) : assert(capacity > 0),
       _pixelLoader = pixelLoader ?? loadGenerationImagePixelBuffer,
       _fingerprintLoader = fingerprintLoader ?? generationImageFingerprint;

  final GenerationImagePixelLoader _pixelLoader;
  final GenerationImageFingerprintLoader _fingerprintLoader;
  final int capacity;
  final LinkedHashMap<_MosaicRequestKey, _CachedMosaic> _cache =
      LinkedHashMap<_MosaicRequestKey, _CachedMosaic>();
  final Map<_MosaicRequestKey, Future<GenerationImageMosaic>> _inFlight =
      <_MosaicRequestKey, Future<GenerationImageMosaic>>{};

  @override
  Future<GenerationImageMosaic> extract(
    String imagePath, {
    required int rows,
    required int columns,
  }) {
    if (rows <= 0 || columns <= 0) {
      return Future<GenerationImageMosaic>.error(
        ArgumentError('rows and columns must be greater than zero'),
      );
    }
    final _MosaicRequestKey key = _MosaicRequestKey(imagePath, rows, columns);
    final Future<GenerationImageMosaic>? existing = _inFlight[key];
    if (existing != null) {
      return existing;
    }
    final Future<GenerationImageMosaic> operation = _extractAndCache(key);
    _inFlight[key] = operation;
    return operation;
  }

  Future<GenerationImageMosaic> _extractAndCache(_MosaicRequestKey key) async {
    String fingerprint;
    try {
      fingerprint = await _fingerprintLoader(key.imagePath);
    } catch (_) {
      fingerprint = 'unavailable';
    }

    try {
      final _CachedMosaic? cached = _cache.remove(key);
      if (cached != null && cached.fingerprint == fingerprint) {
        _cache[key] = cached;
        return cached.mosaic;
      }

      final GenerationImagePixelBuffer pixels = await _pixelLoader(
        key.imagePath,
        targetWidth: key.columns * _mosaicSamplesPerCell,
        targetHeight: key.rows * _mosaicSamplesPerCell,
      );
      final GenerationImageMosaic mosaic = GenerationImageMosaic(
        rows: key.rows,
        columns: key.columns,
        cellColors: sampleGenerationImageMosaicColors(
          pixels,
          rows: key.rows,
          columns: key.columns,
        ),
      );
      _remember(key, _CachedMosaic(fingerprint: fingerprint, mosaic: mosaic));
      return mosaic;
    } catch (error) {
      appDebugLog(
        'GenerationImageMosaic',
        'extract failure path=${key.imagePath} error=$error',
      );
      final GenerationImageMosaic fallback = GenerationImageMosaic.fallback(
        rows: key.rows,
        columns: key.columns,
      );
      _remember(key, _CachedMosaic(fingerprint: fingerprint, mosaic: fallback));
      return fallback;
    } finally {
      _inFlight.remove(key);
    }
  }

  void _remember(_MosaicRequestKey key, _CachedMosaic cached) {
    _cache[key] = cached;
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
  }
}

Future<String> generationImageFingerprint(String imagePath) async {
  if (imagePath.isEmpty) {
    throw const FormatException('Image path is empty');
  }
  final FileStat stat = await File(imagePath).stat();
  if (stat.type != FileSystemEntityType.file) {
    throw FileSystemException('Image file does not exist', imagePath);
  }
  return '${stat.modified.microsecondsSinceEpoch}:${stat.size}';
}

Future<GenerationImagePixelBuffer> loadGenerationImagePixelBuffer(
  String imagePath, {
  required int targetWidth,
  required int targetHeight,
}) async {
  if (imagePath.isEmpty) {
    throw const FormatException('Image path is empty');
  }
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromFilePath(
    imagePath,
  );
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final Size sourceSize = Size(
      descriptor.width.toDouble(),
      descriptor.height.toDouble(),
    );
    final double coverScale = math.max(
      targetWidth / sourceSize.width,
      targetHeight / sourceSize.height,
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (sourceSize.width * coverScale).ceil()),
      targetHeight: math.max(1, (sourceSize.height * coverScale).ceil()),
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    image = frame.image;
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (data == null) {
      throw const FormatException('Unable to read decoded image pixels');
    }
    return GenerationImagePixelBuffer(
      width: image.width,
      height: image.height,
      rgbaBytes: data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      ),
    );
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

@visibleForTesting
List<Color> sampleGenerationImageMosaicColors(
  GenerationImagePixelBuffer pixels, {
  required int rows,
  required int columns,
}) {
  if (rows <= 0 || columns <= 0) {
    throw ArgumentError('rows and columns must be greater than zero');
  }
  final Size sourceSize = Size(
    pixels.width.toDouble(),
    pixels.height.toDouble(),
  );
  final FittedSizes fitted = applyBoxFit(
    BoxFit.cover,
    sourceSize,
    Size(columns.toDouble(), rows.toDouble()),
  );
  final Rect crop = Alignment.center.inscribe(
    fitted.source,
    Offset.zero & sourceSize,
  );

  return <Color>[
    for (int row = 0; row < rows; row += 1)
      for (int column = 0; column < columns; column += 1)
        _normalizeMosaicColor(
          _averageLinearColor(
            pixels,
            Rect.fromLTRB(
              crop.left + crop.width * column / columns,
              crop.top + crop.height * row / rows,
              crop.left + crop.width * (column + 1) / columns,
              crop.top + crop.height * (row + 1) / rows,
            ),
          ),
        ),
  ];
}

@visibleForTesting
Color averageGenerationImageRegion(
  GenerationImagePixelBuffer pixels,
  Rect region,
) {
  return _averageLinearColor(pixels, region);
}

Color _averageLinearColor(GenerationImagePixelBuffer pixels, Rect region) {
  final Rect bounds =
      Offset.zero & Size(pixels.width.toDouble(), pixels.height.toDouble());
  final Rect clipped = region.intersect(bounds);
  if (clipped.isEmpty) {
    return AppColors.accentYellow.withValues(alpha: 1);
  }

  double red = 0;
  double green = 0;
  double blue = 0;
  double totalWeight = 0;
  final int firstX = clipped.left.floor().clamp(0, pixels.width - 1);
  final int lastX = (clipped.right.ceil() - 1).clamp(0, pixels.width - 1);
  final int firstY = clipped.top.floor().clamp(0, pixels.height - 1);
  final int lastY = (clipped.bottom.ceil() - 1).clamp(0, pixels.height - 1);

  for (int y = firstY; y <= lastY; y += 1) {
    final double verticalWeight =
        math.min(y + 1.0, clipped.bottom) - math.max(y.toDouble(), clipped.top);
    for (int x = firstX; x <= lastX; x += 1) {
      final double horizontalWeight =
          math.min(x + 1.0, clipped.right) -
          math.max(x.toDouble(), clipped.left);
      final double weight = horizontalWeight * verticalWeight;
      if (weight <= 0) {
        continue;
      }
      final int offset = (y * pixels.width + x) * 4;
      final double alpha = pixels.rgbaBytes[offset + 3] / 255;
      final double sourceRed = pixels.rgbaBytes[offset] / 255;
      final double sourceGreen = pixels.rgbaBytes[offset + 1] / 255;
      final double sourceBlue = pixels.rgbaBytes[offset + 2] / 255;
      red += _srgbToLinear(sourceRed * alpha + 1 - alpha) * weight;
      green += _srgbToLinear(sourceGreen * alpha + 1 - alpha) * weight;
      blue += _srgbToLinear(sourceBlue * alpha + 1 - alpha) * weight;
      totalWeight += weight;
    }
  }

  if (totalWeight <= 0) {
    return AppColors.accentYellow.withValues(alpha: 1);
  }
  return Color.fromARGB(
    255,
    (_linearToSrgb(red / totalWeight) * 255).round().clamp(0, 255),
    (_linearToSrgb(green / totalWeight) * 255).round().clamp(0, 255),
    (_linearToSrgb(blue / totalWeight) * 255).round().clamp(0, 255),
  );
}

double _srgbToLinear(double channel) {
  if (channel <= 0.04045) {
    return channel / 12.92;
  }
  return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

double _linearToSrgb(double channel) {
  if (channel <= 0.0031308) {
    return channel * 12.92;
  }
  return 1.055 * math.pow(channel, 1 / 2.4) - 0.055;
}

Color _normalizeMosaicColor(Color color) {
  final Hct source = Hct.fromInt(color.toARGB32());
  final Color bounded = Color(
    Hct.from(
      source.hue,
      math.min(source.chroma, 56),
      source.tone.clamp(18, 92).toDouble(),
    ).toInt(),
  );
  return Color.lerp(
    bounded,
    AppColors.white,
    _mosaicWhiteBlend,
  )!.withValues(alpha: 1);
}

List<Color> generationImageMosaicBaseColors(Iterable<Color> colors) {
  return colors
      .map(
        (Color color) =>
            color.withValues(alpha: generationImageMosaicBaseAlpha),
      )
      .toList(growable: false);
}

List<Color> generationImageMosaicLightUpColors(Iterable<Color> colors) {
  return colors
      .map((Color color) => color.withValues(alpha: 1))
      .toList(growable: false);
}
