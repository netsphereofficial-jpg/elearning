import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Simple Firebase Storage service - no complex signing needed!
class SimpleStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload video to Firebase Storage
  Future<String?> uploadVideo({
    required Uint8List fileBytes,
    required String fileName,
    required Function(double) onProgress,
  }) async {
    try {
      // Generate unique path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'videos/$timestamp-$fileName';

      print('📤 Uploading to Firebase Storage: $storagePath');
      print('📦 File size: ${fileBytes.length} bytes');

      // Create reference
      final storageRef = _storage.ref().child(storagePath);

      // Upload with metadata
      final uploadTask = storageRef.putData(
        fileBytes,
        SettableMetadata(
          contentType: _getContentType(fileName),
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Track progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
        print('📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      // Wait for completion
      final snapshot = await uploadTask;
      print('✅ Upload complete!');

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('🔗 Download URL: $downloadUrl');

      return storagePath; // Return the path, not URL
    } catch (e) {
      print('❌ Error uploading: $e');
      return null;
    }
  }

  /// Get download URL for a video
  Future<String?> getDownloadUrl(String storagePath) async {
    try {
      final ref = _storage.ref().child(storagePath);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error getting download URL: $e');
      return null;
    }
  }

  /// Delete video from Firebase Storage
  Future<bool> deleteVideo(String storagePath) async {
    try {
      final ref = _storage.ref().child(storagePath);
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting video: $e');
      return false;
    }
  }

  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case 'webm':
        return 'video/webm';
      default:
        return 'video/mp4';
    }
  }
}
