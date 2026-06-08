import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' hide XFile;

abstract interface class GalleryImagePicker {
  Future<PickedGalleryImage?> pickImageFromGallery();

  Future<void> cancelActivePick();
}

class PickedGalleryImage {
  const PickedGalleryImage({required this.file, this.assetId});

  final XFile file;
  final String? assetId;
}

class SavedPhotoLibraryImage {
  const SavedPhotoLibraryImage({required this.assetId});

  final String assetId;
}

abstract interface class PhotoLibraryAssetStore {
  Future<SavedPhotoLibraryImage> saveImage(
    String path, {
    required String album,
    required String fileName,
  });

  Future<String?> resolveImagePath(String assetId);

  Future<void> setFavorite(String assetId, {required bool isFavorite});
}

class ImagePickerGalleryImagePicker implements GalleryImagePicker {
  const ImagePickerGalleryImagePicker(this._imagePicker);

  final ImagePicker _imagePicker;

  @override
  Future<PickedGalleryImage?> pickImageFromGallery() async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: true,
    );
    if (file == null) {
      return null;
    }
    return PickedGalleryImage(file: file);
  }

  @override
  Future<void> cancelActivePick() async {}
}

class PlatformGalleryImagePicker implements GalleryImagePicker {
  const PlatformGalleryImagePicker({required ImagePicker fallbackImagePicker})
    : _fallbackImagePicker = fallbackImagePicker;

  static const MethodChannel _channel = MethodChannel(
    'fantasy_camera/photo_library_assets',
  );

  final ImagePicker _fallbackImagePicker;

  @override
  Future<PickedGalleryImage?> pickImageFromGallery() async {
    if (!Platform.isIOS) {
      return ImagePickerGalleryImagePicker(
        _fallbackImagePicker,
      ).pickImageFromGallery();
    }

    final Map<Object?, Object?>? result = await _channel
        .invokeMethod<Map<Object?, Object?>>('pickImage');
    if (result == null) {
      return null;
    }
    final Object? path = result['path'];
    if (path is! String || path.isEmpty) {
      return null;
    }
    final Object? assetId = result['assetId'];
    return PickedGalleryImage(
      file: XFile(path),
      assetId: assetId is String && assetId.isNotEmpty ? assetId : null,
    );
  }

  @override
  Future<void> cancelActivePick() async {
    if (!Platform.isIOS) {
      return;
    }
    await _channel.invokeMethod<void>('cancelActivePick');
  }
}

class MethodChannelPhotoLibraryAssetStore implements PhotoLibraryAssetStore {
  const MethodChannelPhotoLibraryAssetStore();

  static const MethodChannel _channel = MethodChannel(
    'fantasy_camera/photo_library_assets',
  );

  @override
  Future<SavedPhotoLibraryImage> saveImage(
    String path, {
    required String album,
    required String fileName,
  }) async {
    final String? assetId = await _channel.invokeMethod<String>('saveImage', {
      'path': path,
      'album': album,
      'fileName': fileName,
    });
    if (assetId == null || assetId.isEmpty) {
      throw StateError('Photo library save did not return an asset id.');
    }
    return SavedPhotoLibraryImage(assetId: assetId);
  }

  @override
  Future<String?> resolveImagePath(String assetId) {
    return _channel.invokeMethod<String>('resolveImagePath', {
      'assetId': assetId,
    });
  }

  @override
  Future<void> setFavorite(String assetId, {required bool isFavorite}) {
    return _channel.invokeMethod<void>('setFavorite', {
      'assetId': assetId,
      'isFavorite': isFavorite,
    });
  }
}
