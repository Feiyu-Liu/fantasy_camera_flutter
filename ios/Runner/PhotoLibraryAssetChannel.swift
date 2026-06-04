import Flutter
import Photos
import PhotosUI
import UIKit

final class PhotoLibraryAssetChannel: NSObject {
  private let channel: FlutterMethodChannel
  private var galleryPickerDelegate: AnyObject?

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "fantasy_camera/photo_library_assets",
      binaryMessenger: binaryMessenger
    )
    super.init()
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "saveImage":
      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String,
        let album = args["album"] as? String,
        let fileName = args["fileName"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "Missing image save arguments.", details: nil))
        return
      }
      saveImage(path: path, album: album, fileName: fileName, result: result)
    case "pickImage":
      pickImage(result: result)
    case "resolveImagePath":
      guard
        let args = call.arguments as? [String: Any],
        let assetId = args["assetId"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "Missing assetId.", details: nil))
        return
      }
      resolveImagePath(assetId: assetId, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func pickImage(result: @escaping FlutterResult) {
    requestReadWriteAccess { granted in
      DispatchQueue.main.async {
        guard granted else {
          result(FlutterError(code: "access_denied", message: "Photo library access denied.", details: nil))
          return
        }
        guard self.galleryPickerDelegate == nil else {
          result(FlutterError(code: "picker_active", message: "Photo picker is already active.", details: nil))
          return
        }
        guard let rootViewController = self.rootViewController() else {
          result(FlutterError(code: "missing_root_view_controller", message: "Unable to present photo picker.", details: nil))
          return
        }

        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        let delegate = GalleryImagePickerDelegate(
          exportAssetForDisplay: self.exportAssetForDisplay(assetId:completion:),
          makeFlutterError: self.flutterError(code:error:),
          finish: { [weak self] response in
            self?.galleryPickerDelegate = nil
            result(response)
          }
        )
        picker.delegate = delegate
        picker.presentationController?.delegate = delegate
        self.galleryPickerDelegate = delegate
        rootViewController.present(picker, animated: true)
      }
    }
  }

  private func saveImage(
    path: String,
    album: String,
    fileName: String,
    result: @escaping FlutterResult
  ) {
    requestReadWriteAccess { granted in
      guard granted else {
        result(FlutterError(code: "access_denied", message: "Photo library access denied.", details: nil))
        return
      }

      self.getOrCreateAlbum(named: album) { collection, error in
        if let error = error {
          result(self.flutterError(code: "album_error", error: error))
          return
        }
        guard let collection = collection else {
          result(FlutterError(code: "album_error", message: "Photo album is unavailable.", details: nil))
          return
        }

        let url = URL(fileURLWithPath: path)
        var placeholderId: String?
        PHPhotoLibrary.shared().performChanges({
          let creationRequest = PHAssetCreationRequest.forAsset()
          let options = PHAssetResourceCreationOptions()
          options.originalFilename = fileName
          creationRequest.addResource(with: .photo, fileURL: url, options: options)
          placeholderId = creationRequest.placeholderForCreatedAsset?.localIdentifier

          if let placeholder = creationRequest.placeholderForCreatedAsset,
             let albumRequest = PHAssetCollectionChangeRequest(for: collection) {
            albumRequest.addAssets([placeholder] as NSArray)
          }
        }, completionHandler: { success, error in
          DispatchQueue.main.async {
            if let error = error {
              result(self.flutterError(code: "save_failed", error: error))
              return
            }
            guard success, let placeholderId = placeholderId, !placeholderId.isEmpty else {
              result(FlutterError(code: "missing_asset_id", message: "Photo save did not return an asset id.", details: nil))
              return
            }
            result(placeholderId)
          }
        })
      }
    }
  }

  private func resolveImagePath(assetId: String, result: @escaping FlutterResult) {
    requestReadWriteAccess { granted in
      guard granted else {
        result(FlutterError(code: "access_denied", message: "Photo library access denied.", details: nil))
        return
      }

      self.exportAssetForDisplay(assetId: assetId) { path, error in
        DispatchQueue.main.async {
          if let error = error {
            result(self.flutterError(code: "export_failed", error: error))
            return
          }
          result(path)
        }
      }
    }
  }

  private func exportAssetForDisplay(
    assetId: String,
    completion: @escaping (String?, Error?) -> Void
  ) {
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = assets.firstObject else {
      completion(nil, nil)
      return
    }
    let resources = PHAssetResource.assetResources(for: asset)
    guard let resource = resources.first(where: { $0.type == .photo }) ?? resources.first else {
      completion(nil, nil)
      return
    }

    let fileName = exportFileName(for: resource, assetId: assetId)
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("TesserCamPhotoAssets", isDirectory: true)
      .appendingPathComponent(fileName)

    do {
      try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      if FileManager.default.fileExists(atPath: outputURL.path) {
        completion(outputURL.path, nil)
        return
      }
    } catch {
      completion(nil, error)
      return
    }

    PHAssetResourceManager.default().writeData(for: resource, toFile: outputURL, options: nil) { error in
      if let error = error {
        completion(nil, error)
        return
      }
      completion(outputURL.path, nil)
    }
  }

  private func requestReadWriteAccess(completion: @escaping (Bool) -> Void) {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    if status == .authorized || status == .limited {
      completion(true)
      return
    }
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
      completion(newStatus == .authorized || newStatus == .limited)
    }
  }

  private func getOrCreateAlbum(
    named name: String,
    completion: @escaping (PHAssetCollection?, Error?) -> Void
  ) {
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "title = %@", name)
    let collections = PHAssetCollection.fetchAssetCollections(
      with: .album,
      subtype: .any,
      options: options
    )
    if let collection = collections.firstObject {
      completion(collection, nil)
      return
    }

    PHPhotoLibrary.shared().performChanges({
      PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
    }, completionHandler: { success, error in
      DispatchQueue.main.async {
        if let error = error {
          completion(nil, error)
          return
        }
        if success {
          self.getOrCreateAlbum(named: name, completion: completion)
        } else {
          completion(nil, nil)
        }
      }
    })
  }

  private func exportFileName(for resource: PHAssetResource, assetId: String) -> String {
    let originalName = resource.originalFilename
    let ext = URL(fileURLWithPath: originalName).pathExtension
    let safeAssetId = assetId
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: ":", with: "_")
    if ext.isEmpty {
      return "\(safeAssetId).heic"
    }
    return "\(safeAssetId).\(ext)"
  }

  private func rootViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    return window?.rootViewController
  }

  private func flutterError(code: String, error: Error) -> FlutterError {
    let nsError = error as NSError
    return FlutterError(
      code: code,
      message: nsError.localizedDescription,
      details: nsError.userInfo
    )
  }
}

private final class GalleryImagePickerDelegate: NSObject, PHPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
  private let exportAssetForDisplay: (String, @escaping (String?, Error?) -> Void) -> Void
  private let makeFlutterError: (String, Error) -> FlutterError
  private let finish: (Any?) -> Void
  private var didReceivePickerResult = false
  private var didFinish = false

  init(
    exportAssetForDisplay: @escaping (String, @escaping (String?, Error?) -> Void) -> Void,
    makeFlutterError: @escaping (String, Error) -> FlutterError,
    finish: @escaping (Any?) -> Void
  ) {
    self.exportAssetForDisplay = exportAssetForDisplay
    self.makeFlutterError = makeFlutterError
    self.finish = finish
    super.init()
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    didReceivePickerResult = true
    picker.dismiss(animated: true)

    guard let picked = results.first else {
      finishOnce(nil)
      return
    }
    guard let assetId = picked.assetIdentifier else {
      finishOnce(FlutterError(
        code: "missing_asset_id",
        message: "Picked image did not return an asset id.",
        details: nil
      ))
      return
    }

    exportAssetForDisplay(assetId) { [weak self] path, error in
      DispatchQueue.main.async {
        guard let self = self else {
          return
        }
        if let error = error {
          self.finishOnce(self.makeFlutterError("export_failed", error))
          return
        }
        guard let path = path else {
          self.finishOnce(nil)
          return
        }
        self.finishOnce(["path": path, "assetId": assetId])
      }
    }
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard !didReceivePickerResult else {
      return
    }
    finishOnce(nil)
  }

  private func finishOnce(_ response: Any?) {
    guard !didFinish else {
      return
    }
    didFinish = true
    finish(response)
  }
}
