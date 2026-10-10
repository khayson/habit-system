import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoSource { gallery, camera }

/// Picks and crops a profile photo: a square JPEG of at most 1024 px, or null when the user
/// backs out. A seam so widget tests use a fake.
abstract interface class PhotoPicker {
  Future<String?> pick(PhotoSource source, {required String cropTitle});
}

/// image_picker (the Android photo picker: no storage permission) and image_cropper (square).
class DevicePhotoPicker implements PhotoPicker {
  const DevicePhotoPicker();

  static const maxSide = 1024;

  @override
  Future<String?> pick(PhotoSource source, {required String cropTitle}) async {
    final picked = await ImagePicker().pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: maxSide,
      maxHeight: maxSide,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: cropTitle, lockAspectRatio: true, hideBottomControls: true),
        IOSUiSettings(
          title: cropTitle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    return cropped?.path;
  }
}
