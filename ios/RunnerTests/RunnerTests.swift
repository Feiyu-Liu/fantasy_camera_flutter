import Flutter
import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testSquareCropPreservesImageMetadata() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let sourceURL = directory.appendingPathComponent("source.jpg")
    let outputURL = directory.appendingPathComponent("square.jpg")
    try writeTestImage(to: sourceURL)

    let result = try CapturedPhotoSquareCropper().crop(
      sourceURL: sourceURL,
      outputURL: outputURL
    )

    XCTAssertEqual(result.width, 80)
    XCTAssertEqual(result.height, 80)
    let outputSource = try XCTUnwrap(
      CGImageSourceCreateWithURL(outputURL as CFURL, nil)
    )
    let outputImage = try XCTUnwrap(
      CGImageSourceCreateImageAtIndex(outputSource, 0, nil)
    )
    XCTAssertEqual(outputImage.width, 80)
    XCTAssertEqual(outputImage.height, 80)
    let properties = try XCTUnwrap(
      CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil)
        as? [CFString: Any]
    )
    XCTAssertEqual(properties[kCGImagePropertyOrientation] as? Int, 6)
    let exif = try XCTUnwrap(
      properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
    )
    XCTAssertEqual(
      exif[kCGImagePropertyExifDateTimeOriginal] as? String,
      "2026:07:14 12:34:56"
    )
  }

  func testHEIFSourceUsesWritableHEICDestination() throws {
    let format = try XCTUnwrap(
      CapturedPhotoDestinationFormat.resolve(
        sourceTypeIdentifier: UTType.heif.identifier as CFString,
        writableTypeIdentifiers: [
          UTType.heic.identifier,
          UTType.jpeg.identifier,
        ]
      )
    )

    XCTAssertEqual(format.typeIdentifier, UTType.heic.identifier)
    XCTAssertEqual(format.fileExtension, "heic")
    XCTAssertEqual(
      format.outputURL(for: URL(fileURLWithPath: "/tmp/square.heif")).path,
      "/tmp/square.heic"
    )
  }

  func testUnsupportedSourceFallsBackToJPEG() throws {
    let format = try XCTUnwrap(
      CapturedPhotoDestinationFormat.resolve(
        sourceTypeIdentifier: "com.adobe.raw-image" as CFString,
        writableTypeIdentifiers: [UTType.jpeg.identifier]
      )
    )

    XCTAssertEqual(format.typeIdentifier, UTType.jpeg.identifier)
    XCTAssertEqual(format.fileExtension, "jpg")
  }

  private func writeTestImage(to url: URL) throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(
      size: CGSize(width: 120, height: 80),
      format: format
    ).image { context in
        UIColor.red.setFill()
        context.cgContext.fill(CGRect(x: 0, y: 0, width: 60, height: 80))
        UIColor.blue.setFill()
        context.cgContext.fill(CGRect(x: 60, y: 0, width: 60, height: 80))
      }
    let cgImage = try XCTUnwrap(image.cgImage)
    let destination = try XCTUnwrap(
      CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.jpeg.identifier as CFString,
        1,
        nil
      )
    )
    let properties: [CFString: Any] = [
      kCGImagePropertyOrientation: 6,
      kCGImagePropertyExifDictionary: [
        kCGImagePropertyExifDateTimeOriginal: "2026:07:14 12:34:56"
      ],
    ]
    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
  }

}
