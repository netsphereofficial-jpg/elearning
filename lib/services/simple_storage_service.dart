import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Simple Firebase Storage service - no complex signing needed!
class SimpleStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload video to Firebase Storage
  /// Returns storage path on success, null on failure
  /// Throws detailed error messages for better error handling
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
      print('📦 File size: ${(fileBytes.length / 1024 / 1024).toStringAsFixed(2)} MB');

      // Create reference
      final storageRef = _storage.ref().child(storagePath);

      // Upload with metadata
      final uploadTask = storageRef.putData(
        fileBytes,
        SettableMetadata(
          contentType: _getContentType(fileName),
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'originalFileName': fileName,
          },
        ),
      );

      // Track progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
        print('📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      // Wait for completion with timeout
      final snapshot = await uploadTask.timeout(
        const Duration(minutes: 30),
        onTimeout: () {
          throw Exception('Upload timeout: The upload took too long (>30 minutes). Please try a smaller file or check your internet connection.');
        },
      );

      print('✅ Upload complete!');

      // Verify upload success
      if (snapshot.state != TaskState.success) {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }

      // Get download URL to verify file is accessible
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('🔗 Download URL: $downloadUrl');

      return storagePath; // Return the path, not URL
    } on FirebaseException catch (e) {
      print('❌ Firebase Storage Error: ${e.code} - ${e.message}');

      // Provide user-friendly error messages
      String errorMessage;
      switch (e.code) {
        case 'unauthorized':
          errorMessage = 'Permission denied. Please ensure you are logged in as an admin.';
          break;
        case 'canceled':
          errorMessage = 'Upload was canceled.';
          break;
        case 'unknown':
          errorMessage = 'An unknown error occurred. Please check your internet connection and try again.';
          break;
        case 'quota-exceeded':
          errorMessage = 'Storage quota exceeded. Please contact the administrator.';
          break;
        case 'unauthenticated':
          errorMessage = 'You must be logged in to upload videos.';
          break;
        default:
          errorMessage = 'Upload failed: ${e.message ?? e.code}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      print('❌ Error uploading: $e');
      rethrow;
    }
  }

  /// Get download URL for a video
  Future<String?> getDownloadUrl(String storagePath) async {
    try {
      final ref = _storage.ref().child(storagePath);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      print('❌ Firebase Storage Error getting URL: ${e.code} - ${e.message}');
      if (e.code == 'object-not-found') {
        throw Exception('Video not found. It may have been deleted.');
      } else if (e.code == 'unauthorized') {
        throw Exception('Permission denied. Please ensure you are enrolled in this course.');
      }
      throw Exception('Failed to load video: ${e.message ?? e.code}');
    } catch (e) {
      print('❌ Error getting download URL: $e');
      rethrow;
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
