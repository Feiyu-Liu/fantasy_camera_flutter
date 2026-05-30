import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart' hide XFile;

abstract interface class GalleryImagePicker {
  Future<XFile?> pickImageFromGallery();
}

abstract interface class PhotoLibrarySaver {
  Future<void> saveImage(String path, {required String album});
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

class GalPhotoLibrarySaver implements PhotoLibrarySaver {
  const GalPhotoLibrarySaver();

  @override
  Future<void> saveImage(String path, {required String album}) {
    return Gal.putImage(path, album: album);
  }
}
