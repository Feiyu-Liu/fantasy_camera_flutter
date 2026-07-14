import Flutter
import ImageIO
import UniformTypeIdentifiers

final class CapturedPhotoProcessingChannel {
  private let channel: FlutterMethodChannel
  private let processingQueue = DispatchQueue(
    label: "fantasy_camera.captured_photo_processing",
    qos: .userInitiated
  )

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "fantasy_camera/captured_photo_processing",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "cropSquare" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let sourcePath = arguments["sourcePath"] as? String,
      let outputPath = arguments["outputPath"] as? String
    else {
      result(
        FlutterError(
          code: "bad_args",
          message: "Missing square crop paths.",
          details: nil
        )
      )
      return
    }

    processingQueue.async {
      let response: Result<CapturedPhotoCropResult, Error> = Result {
        try autoreleasepool {
          try CapturedPhotoSquareCropper().crop(
            sourceURL: URL(fileURLWithPath: sourcePath),
            outputURL: URL(fileURLWithPath: outputPath)
          )
        }
      }
      DispatchQueue.main.async {
        switch response {
        case .success(let cropResult):
          result([
            "path": cropResult.path,
            "width": cropResult.width,
            "height": cropResult.height,
          ])
        case .failure(let error):
          result(
            FlutterError(
              code: "crop_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }
}

struct CapturedPhotoCropResult {
  let path: String
  let width: Int
  let height: Int
}

struct CapturedPhotoSquareCropper {
  func crop(sourceURL: URL, outputURL: URL) throws -> CapturedPhotoCropResult {
    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
      throw CapturedPhotoProcessingError.sourceMissing
    }
    guard
      let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let sourceTypeIdentifier = CGImageSourceGetType(source),
      let sourceImage = CGImageSourceCreateImageAtIndex(
        source,
        0,
        [kCGImageSourceShouldCache: false] as CFDictionary
      )
    else {
      throw CapturedPhotoProcessingError.sourceUnreadable
    }
    guard
      let destinationFormat = CapturedPhotoDestinationFormat.resolve(
        sourceTypeIdentifier: sourceTypeIdentifier
      )
    else {
      throw CapturedPhotoProcessingError.destinationUnavailable(
        sourceTypeIdentifier: sourceTypeIdentifier as String
      )
    }

    let side = min(sourceImage.width, sourceImage.height)
    guard side > 0 else {
      throw CapturedPhotoProcessingError.invalidDimensions
    }
    let cropRect = CGRect(
      x: (sourceImage.width - side) / 2,
      y: (sourceImage.height - side) / 2,
      width: side,
      height: side
    )
    guard let croppedImage = sourceImage.cropping(to: cropRect) else {
      throw CapturedPhotoProcessingError.cropUnavailable
    }

    let destinationURL = destinationFormat.outputURL(for: outputURL)
    let fileManager = FileManager.default
    try fileManager.createDirectory(
      at: destinationURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let partialURL = destinationURL
      .deletingPathExtension()
      .appendingPathExtension("partial-\(UUID().uuidString)")
      .appendingPathExtension(destinationURL.pathExtension)
    try? fileManager.removeItem(at: partialURL)
    defer { try? fileManager.removeItem(at: partialURL) }

    guard
      let destination = CGImageDestinationCreateWithURL(
        partialURL as CFURL,
        destinationFormat.typeIdentifier as CFString,
        1,
        nil
      )
    else {
      throw CapturedPhotoProcessingError.destinationUnavailable(
        sourceTypeIdentifier: sourceTypeIdentifier as String
      )
    }

    var properties =
      CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ??
      [:]
    properties[kCGImagePropertyPixelWidth] = side
    properties[kCGImagePropertyPixelHeight] = side
    properties[kCGImageDestinationLossyCompressionQuality] = 1.0
    if var exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
      exif[kCGImagePropertyExifPixelXDimension] = side
      exif[kCGImagePropertyExifPixelYDimension] = side
      properties[kCGImagePropertyExifDictionary] = exif
    }

    CGImageDestinationAddImage(destination, croppedImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw CapturedPhotoProcessingError.encodingFailed
    }

    try? fileManager.removeItem(at: destinationURL)
    try fileManager.moveItem(at: partialURL, to: destinationURL)
    return CapturedPhotoCropResult(path: destinationURL.path, width: side, height: side)
  }
}

struct CapturedPhotoDestinationFormat {
  let typeIdentifier: String
  let fileExtension: String

  static func resolve(
    sourceTypeIdentifier: CFString,
    writableTypeIdentifiers: Set<String>? = nil
  ) -> CapturedPhotoDestinationFormat? {
    let systemWritableTypes = CGImageDestinationCopyTypeIdentifiers() as NSArray
    let writableTypes = writableTypeIdentifiers ?? Set(
      systemWritableTypes.compactMap { $0 as? String }
    )
    let sourceIdentifier = sourceTypeIdentifier as String
    let sourceType = UTType(sourceIdentifier)

    if sourceIdentifier == UTType.heif.identifier
      || sourceType?.conforms(to: .heif) == true
    {
      let heicIdentifier = UTType.heic.identifier
      if writableTypes.contains(heicIdentifier) {
        return CapturedPhotoDestinationFormat(
          typeIdentifier: heicIdentifier,
          fileExtension: "heic"
        )
      }
    }

    if writableTypes.contains(sourceIdentifier) {
      return CapturedPhotoDestinationFormat(
        typeIdentifier: sourceIdentifier,
        fileExtension: preferredFileExtension(for: sourceIdentifier)
      )
    }

    let jpegIdentifier = UTType.jpeg.identifier
    guard writableTypes.contains(jpegIdentifier) else {
      return nil
    }
    return CapturedPhotoDestinationFormat(
      typeIdentifier: jpegIdentifier,
      fileExtension: "jpg"
    )
  }

  func outputURL(for requestedURL: URL) -> URL {
    guard
      let requestedType = UTType(filenameExtension: requestedURL.pathExtension),
      requestedType.identifier == typeIdentifier
    else {
      return requestedURL
        .deletingPathExtension()
        .appendingPathExtension(fileExtension)
    }
    return requestedURL
  }

  private static func preferredFileExtension(for typeIdentifier: String) -> String {
    switch typeIdentifier {
    case UTType.heic.identifier:
      return "heic"
    case UTType.jpeg.identifier:
      return "jpg"
    default:
      return UTType(typeIdentifier)?.preferredFilenameExtension ?? "jpg"
    }
  }
}

private enum CapturedPhotoProcessingError: LocalizedError {
  case sourceMissing
  case sourceUnreadable
  case invalidDimensions
  case cropUnavailable
  case destinationUnavailable(sourceTypeIdentifier: String)
  case encodingFailed

  var errorDescription: String? {
    switch self {
    case .sourceMissing:
      return "The captured photo no longer exists."
    case .sourceUnreadable:
      return "The captured photo could not be decoded."
    case .invalidDimensions:
      return "The captured photo has invalid dimensions."
    case .cropUnavailable:
      return "The captured photo could not be cropped."
    case .destinationUnavailable(let sourceTypeIdentifier):
      return "The cropped photo output could not be created for \(sourceTypeIdentifier)."
    case .encodingFailed:
      return "The cropped photo could not be encoded."
    }
  }
}
