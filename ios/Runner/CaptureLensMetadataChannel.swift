import AVFoundation
import Flutter

final class CaptureLensMetadataChannel {
  private let channel: FlutterMethodChannel

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "fantasy_camera/capture_lens_metadata",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "readNominalFocalLength35mm":
      guard
        let args = call.arguments as? [String: Any],
        let cameraName = args["cameraName"] as? String,
        let lensDirection = args["lensDirection"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "Missing lens metadata arguments.", details: nil))
        return
      }
      result(readNominalFocalLength35mm(cameraName: cameraName, lensDirection: lensDirection))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func readNominalFocalLength35mm(cameraName: String, lensDirection: String) -> Double? {
    guard #available(iOS 26.0, *) else {
      return nil
    }

    let requestedPosition = captureDevicePosition(lensDirection: lensDirection)
    let allVideoDevices = AVCaptureDevice.DiscoverySession(
      deviceTypes: [
        .builtInTripleCamera,
        .builtInDualWideCamera,
        .builtInDualCamera,
        .builtInWideAngleCamera,
        .builtInUltraWideCamera,
        .builtInTelephotoCamera,
        .builtInTrueDepthCamera
      ],
      mediaType: .video,
      position: .unspecified
    ).devices
    if let matchedDevice = allVideoDevices.first(where: { device in
      device.uniqueID == cameraName || device.localizedName == cameraName
    }) {
      let focalLength = Double(matchedDevice.nominalFocalLengthIn35mmFilm)
      if focalLength > 0 {
        return focalLength
      }
    }

    let discoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: [
        .builtInTripleCamera,
        .builtInDualWideCamera,
        .builtInDualCamera,
        .builtInWideAngleCamera,
        .builtInUltraWideCamera,
        .builtInTelephotoCamera,
        .builtInTrueDepthCamera
      ],
      mediaType: .video,
      position: requestedPosition
    )
    let fallback = discoverySession.devices
      .map { Double($0.nominalFocalLengthIn35mmFilm) }
      .first(where: { $0 > 0 })
    return fallback
  }

  private func captureDevicePosition(lensDirection: String) -> AVCaptureDevice.Position {
    switch lensDirection {
    case "front":
      return .front
    case "back":
      return .back
    default:
      return .unspecified
    }
  }
}
