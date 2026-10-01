import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload task image and return download URL
  Future<String> uploadTaskImage({
    required String taskId,
    required dynamic imageFile, // File on mobile, Uint8List on web
  }) async {
    final ref = _storage.ref().child('tasks/$taskId/image.jpg');

    UploadTask uploadTask;
    if (kIsWeb && imageFile is Uint8List) {
      uploadTask = ref.putData(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else if (imageFile is File) {
      uploadTask = ref.putFile(imageFile);
    } else {
      throw Exception('Unsupported image type');
    }

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Upload user avatar and return download URL
  Future<String> uploadUserAvatar({
    required String uid,
    required dynamic imageFile,
  }) async {
    final ref = _storage.ref().child('avatars/$uid/avatar.jpg');

    UploadTask uploadTask;
    if (kIsWeb && imageFile is Uint8List) {
      uploadTask = ref.putData(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else if (imageFile is File) {
      uploadTask = ref.putFile(imageFile);
    } else {
      throw Exception('Unsupported image type');
    }

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Delete a file from storage
  Future<void> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }
}
