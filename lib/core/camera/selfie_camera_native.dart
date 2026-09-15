import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<Uint8List?> captureSelfie(BuildContext context) async {
  final photo = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    maxWidth: 1000,
    maxHeight: 1000,
    imageQuality: 80,
  );
  return photo?.readAsBytes();
}
