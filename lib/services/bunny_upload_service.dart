import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BunnyUploadService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Create a new video in Bunny.net and get upload credentials
  Future<BunnyVideoCreationResult?> createVideo(String title) async {
    try {
      print('Creating video in Bunny with title: $title');

      final callable = _functions.httpsCallable('createBunnyVideoForUpload');
      final result = await callable.call({
        'title': title,
      });

      print('Bunny video creation result: ${result.data}');

      return BunnyVideoCreationResult(
        bunnyVideoGuid: result.data['bunnyVideoGuid'],
        libraryId: result.data['libraryId'],
        apiKey: result.data['uploadApiKey'],
        uploadUrl: result.data['uploadUrl'],
      );
    } catch (e) {
      print('Error creating video in Bunny: $e');
      rethrow;
    }
  }

  /// Upload video file to Firebase Storage, then transfer to Bunny via Cloud Function
  Future<bool> uploadVideoViaStorage({
    required String title,
    required String bunnyVideoGuid,
    required Uint8List fileBytes,
    required String fileName,
    required Function(double) onProgress,
  }) async {
    try {
      print('Uploading to Firebase Storage. Size: ${fileBytes.length} bytes');

      // Upload to Firebase Storage
      final storageRef = _storage.ref().child('video_uploads/$bunnyVideoGuid/$fileName');
      final uploadTask = storageRef.putData(
        fileBytes,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'title': title,
            'bunnyVideoGuid': bunnyVideoGuid,
          },
        ),
      );

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress * 0.7); // Reserve 30% for Bunny transfer
        print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      // Wait for upload to complete
      await uploadTask;
      print('Firebase Storage upload complete');

      onProgress(0.75); // Upload done, starting transfer

      // Trigger Cloud Function to transfer to Bunny
      final callable = _functions.httpsCallable('transferVideoToBunny');
      final result = await callable.call({
        'bunnyVideoGuid': bunnyVideoGuid,
        'storagePath': 'video_uploads/$bunnyVideoGuid/$fileName',
        'title': title,
      });

      onProgress(1.0);

      if (result.data['success'] == true) {
        print('Video transferred to Bunny successfully');
        return true;
      } else {
        print('Transfer to Bunny failed: ${result.data['message']}');
        return false;
      }
    } catch (e) {
      print('Error uploading video: $e');
      return false;
    }
  }

  /// Old direct upload method - kept for backward compatibility
  Future<bool> uploadVideoFile({
    required String libraryId,
    required String videoGuid,
    required String apiKey,
    required Uint8List fileBytes,
    required Function(double) onProgress,
  }) async {
    try {
      print('Starting direct upload to Bunny. Size: ${fileBytes.length} bytes');

      final url = Uri.parse(
        'https://video.bunnycdn.com/library/$libraryId/videos/$videoGuid',
      );

      // Use regular PUT request for file upload
      final response = await http.put(
        url,
        headers: {
          'AccessKey': apiKey,
          'Content-Type': 'application/octet-stream',
        },
        body: fileBytes,
      );

      // Simulate progress (since we can't track it with simple PUT)
      onProgress(0.3);
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress(0.6);
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress(0.9);
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress(1.0);

      print('Upload response: ${response.statusCode}');
      print('Upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Video uploaded successfully');
        return true;
      } else {
        print('Upload failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error uploading video: $e');
      return false;
    }
  }

  /// Check video processing status
  Future<VideoProcessingStatus?> checkVideoStatus(String videoGuid) async {
    try {
      final callable = _functions.httpsCallable('checkBunnyVideoStatus');
      final result = await callable.call({'videoGuid': videoGuid});

      return VideoProcessingStatus(
        status: result.data['status'],
        progress: result.data['progress'] ?? 0,
        duration: result.data['duration'] ?? 0,
        isReady: result.data['status'] == 4 || result.data['status'] == 5,
        message: result.data['message'] ?? '',
      );
    } catch (e) {
      print('Error checking video status: $e');
      return null;
    }
  }
}

class BunnyVideoCreationResult {
  final String bunnyVideoGuid;
  final String libraryId;
  final String apiKey;
  final String uploadUrl;

  BunnyVideoCreationResult({
    required this.bunnyVideoGuid,
    required this.libraryId,
    required this.apiKey,
    required this.uploadUrl,
  });
}

class VideoProcessingStatus {
  final int status;
  final int progress;
  final int duration;
  final bool isReady;
  final String message;

  VideoProcessingStatus({
    required this.status,
    required this.progress,
    required this.duration,
    required this.isReady,
    required this.message,
  });
}
