import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' hide XFile;

abstract interface class GalleryImagePicker {
  Future<XFile?> pickImageFromGallery();
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
}

class ImagePickerGalleryImagePicker implements GalleryImagePicker {
  const ImagePickerGalleryImagePicker(this._imagePicker);

  final ImagePicker _imagePicker;

  @override
  Future<XFile?> pickImageFromGallery() {
    return _imagePicker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: true,
    );
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
}
