import Flutter
import Photos
import PhotosUI
import UIKit
import UniformTypeIdentifiers

final class PhotoLibraryAssetChannel: NSObject {
  private let channel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var galleryPickerDelegate: GalleryImagePickerDelegate?
  private var eventSink: FlutterEventSink?

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "fantasy_camera/photo_library_assets",
      binaryMessenger: binaryMessenger
    )
    eventChannel = FlutterEventChannel(
      name: "fantasy_camera/photo_library_assets/events",
      binaryMessenger: binaryMessenger
    )
    super.init()
    channel.setMethodCallHandler(handle)
    eventChannel.setStreamHandler(self)
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
    case "saveImageToLibrary":
      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String,
        let fileName = args["fileName"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "Missing image save arguments.", details: nil))
        return
      }
      saveImageToLibrary(path: path, fileName: fileName, result: result)
    case "pickImage":
      pickImage(result: result)
    case "cancelActivePick":
      cancelActivePick(result: result)
    case "resolveImagePath":
      guard
        let args = call.arguments as? [String: Any],
        let assetId = args["assetId"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "Missing assetId.", details: nil))
        return
      }
      resolveImagePath(assetId: assetId, result: result)
    case "setFavorite":
      guard
        let args = call.arguments as? [String: Any],
        let assetId = args["assetId"] as? String,
        let isFavorite = args["isFavorite"] as? Bool
      else {
        result(FlutterError(code: "bad_args", message: "Missing favorite arguments.", details: nil))
        return
      }
      setFavorite(assetId: assetId, isFavorite: isFavorite, result: result)
    case "openPhotoLibrary":
      openPhotoLibrary(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func pickImage(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      self.clearStaleGalleryPickerIfNeeded()
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
        picker: picker,
        sendProgress: self.sendGalleryExportProgress(assetId:progress:),
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

  private func cancelActivePick(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let delegate = self.galleryPickerDelegate else {
        result(nil)
        return
      }
      delegate.cancel()
      self.galleryPickerDelegate = nil
      result(nil)
    }
  }

  private func clearStaleGalleryPickerIfNeeded() {
    guard let delegate = galleryPickerDelegate else {
      return
    }
    if delegate.isPickerPresented {
      return
    }
    delegate.cancel()
    galleryPickerDelegate = nil
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

  private func saveImageToLibrary(
    path: String,
    fileName: String,
    result: @escaping FlutterResult
  ) {
    requestReadWriteAccess { granted in
      guard granted else {
        result(FlutterError(code: "access_denied", message: "Photo library access denied.", details: nil))
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
    progress: ((Double) -> Void)? = nil,
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

    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = true
    options.progressHandler = { value in
      progress?(value)
      self.sendGalleryExportProgress(assetId: assetId, progress: value)
    }

    PHAssetResourceManager.default().writeData(for: resource, toFile: outputURL, options: options) { error in
      if let error = error {
        completion(nil, error)
        return
      }
      self.sendGalleryExportProgress(assetId: assetId, progress: 1)
      completion(outputURL.path, nil)
    }
  }

  private func sendGalleryExportProgress(assetId: String, progress: Double) {
    let clampedProgress = max(0, min(1, progress))
    DispatchQueue.main.async {
      self.eventSink?([
        "type": "galleryExportProgress",
        "assetId": assetId,
        "progress": clampedProgress
      ])
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

  private func setFavorite(assetId: String, isFavorite: Bool, result: @escaping FlutterResult) {
    requestReadWriteAccess { granted in
      guard granted else {
        result(FlutterError(code: "access_denied", message: "Photo library access denied.", details: nil))
        return
      }

      let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
      guard let asset = assets.firstObject else {
        result(FlutterError(code: "asset_not_found", message: "Photo asset was not found.", details: nil))
        return
      }

      PHPhotoLibrary.shared().performChanges({
        let changeRequest = PHAssetChangeRequest(for: asset)
        changeRequest.isFavorite = isFavorite
      }, completionHandler: { success, error in
        DispatchQueue.main.async {
          if let error = error {
            result(self.flutterError(code: "favorite_failed", error: error))
            return
          }
          guard success else {
            result(FlutterError(code: "favorite_failed", message: "Photo favorite update failed.", details: nil))
            return
          }
          result(nil)
        }
      })
    }
  }

  private func openPhotoLibrary(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let url = URL(string: "photos-redirect://") else {
        result(FlutterError(code: "bad_url", message: "Unable to create Photos URL.", details: nil))
        return
      }
      UIApplication.shared.open(url, options: [:]) { success in
        if success {
          result(nil)
        } else {
          result(FlutterError(code: "open_failed", message: "Photos app could not be opened.", details: nil))
        }
      }
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

extension PhotoLibraryAssetChannel: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

private final class GalleryImagePickerDelegate: NSObject, PHPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
  private weak var picker: PHPickerViewController?
  private let sendProgress: (String, Double) -> Void
  private let makeFlutterError: (String, Error) -> FlutterError
  private let finish: (Any?) -> Void
  private var didReceivePickerResult = false
  private var didFinish = false
  private var progressObservation: NSKeyValueObservation?

  var isPickerPresented: Bool {
    guard let picker = picker else {
      return false
    }
    return picker.presentingViewController != nil || picker.view.window != nil
  }

  init(
    picker: PHPickerViewController,
    sendProgress: @escaping (String, Double) -> Void,
    makeFlutterError: @escaping (String, Error) -> FlutterError,
    finish: @escaping (Any?) -> Void
  ) {
    self.picker = picker
    self.sendProgress = sendProgress
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

    let assetId = picked.assetIdentifier
    let progressId = assetId ?? UUID().uuidString
    guard let typeIdentifier = picked.itemProvider.registeredTypeIdentifiers.first(where: { identifier in
      UTType(identifier)?.conforms(to: .image) ?? false
    }) else {
      finishOnce(FlutterError(
        code: "missing_type_identifier",
        message: "Picked image did not provide an image representation.",
        details: nil
      ))
      return
    }

    sendProgress(progressId, 0)
    let progress = picked.itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
      guard let self = self else {
        return
      }
      if let error = error {
        DispatchQueue.main.async {
          self.finishOnce(self.makeFlutterError("export_failed", error))
        }
        return
      }
      guard let url = url else {
        DispatchQueue.main.async {
          self.finishOnce(FlutterError(
            code: "export_failed",
            message: "Picked image file was unavailable.",
            details: nil
          ))
        }
        return
      }
      do {
        let path = try self.copyPickedImageToTemporaryImportDirectory(
          sourceURL: url,
          typeIdentifier: typeIdentifier,
          progressId: progressId
        )
        DispatchQueue.main.async {
          var response: [String: Any] = ["path": path]
          if let assetId = assetId, !assetId.isEmpty {
            response["assetId"] = assetId
          }
          self.finishOnce(response)
        }
      } catch {
        DispatchQueue.main.async {
          self.finishOnce(self.makeFlutterError("export_failed", error))
        }
      }
    }
    progressObservation = progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
      self?.sendProgress(progressId, progress.fractionCompleted)
    }
  }

  private func copyPickedImageToTemporaryImportDirectory(
    sourceURL: URL,
    typeIdentifier: String,
    progressId: String
  ) throws -> String {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("TesserCamPhotoImports", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )

    let sourceExtension = sourceURL.pathExtension
    let preferredExtension = UTType(typeIdentifier)?.preferredFilenameExtension
    let fileExtension = sourceExtension.isEmpty
      ? (preferredExtension ?? "heic")
      : sourceExtension
    let destinationURL = directory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(fileExtension)

    if FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.removeItem(at: destinationURL)
    }
    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    sendProgress(progressId, 1)
    return destinationURL.path
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard !didReceivePickerResult else {
      return
    }
    finishOnce(nil)
  }

  func cancel() {
    if let picker = picker, isPickerPresented {
      picker.dismiss(animated: false)
    }
    progressObservation?.invalidate()
    progressObservation = nil
    finishOnce(nil)
  }

  private func finishOnce(_ response: Any?) {
    guard !didFinish else {
      return
    }
    didFinish = true
    progressObservation?.invalidate()
    progressObservation = nil
    finish(response)
  }
}
