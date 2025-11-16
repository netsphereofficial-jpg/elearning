import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Bunny Stream service for video management
/// Provides secure video upload, playback, and management using Bunny.net Stream API
class BunnyStreamService {
  // Bunny Stream Configuration
  static const String _apiKey = '2441484c-b520-40ed-9a58462f58e0-e02f-4b0e';
  static const String _libraryId = '542653';
  static const String _cdnHostname = 'vz-bba76149-c05.b-cdn.net';

  // API Endpoints
  static const String _baseApiUrl = 'https://video.bunnycdn.com/library/$_libraryId';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload video to Bunny Stream
  /// Returns video GUID on success
  /// Bunny Stream automatically handles:
  /// - Video transcoding to multiple qualities (360p, 480p, 720p, 1080p)
  /// - Adaptive bitrate streaming (HLS)
  /// - CDN delivery for fast global playback
  /// - Download protection & DRM
  Future<String?> uploadVideo({
    required Uint8List fileBytes,
    required String fileName,
    required String title,
    required Function(double) onProgress,
  }) async {
    try {
      print('📤 Uploading to Bunny Stream: $fileName');
      print('📦 File size: ${(fileBytes.length / 1024 / 1024).toStringAsFixed(2)} MB');

      // Step 1: Create video object in Bunny Stream
      final createResponse = await http.post(
        Uri.parse('$_baseApiUrl/videos'),
        headers: {
          'AccessKey': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
        }),
      );

      if (createResponse.statusCode != 200) {
        throw Exception('Failed to create video: ${createResponse.body}');
      }

      final videoData = jsonDecode(createResponse.body);
      final videoGuid = videoData['guid'] as String;

      print('✅ Video created with GUID: $videoGuid');

      // Step 2: Upload video file
      print('📤 Uploading video file...');

      final uploadResponse = await http.put(
        Uri.parse('$_baseApiUrl/videos/$videoGuid'),
        headers: {
          'AccessKey': _apiKey,
          'Content-Type': 'application/octet-stream',
        },
        body: fileBytes,
      );

      if (uploadResponse.statusCode != 200) {
        // Delete the created video if upload fails
        await deleteVideo(videoGuid);
        throw Exception('Failed to upload video file: ${uploadResponse.body}');
      }

      print('✅ Video uploaded successfully!');
      print('🎬 Video GUID: $videoGuid');
      print('⏳ Video is now being transcoded by Bunny Stream...');
      print('📺 Playback URL: https://$_cdnHostname/$videoGuid/playlist.m3u8');

      // Simulate progress for user feedback
      onProgress(1.0);

      return videoGuid;
    } catch (e) {
      print('❌ Error uploading to Bunny Stream: $e');
      rethrow;
    }
  }

  /// Get playback URL for a video
  /// Returns HLS playlist URL for adaptive streaming
  /// Bunny Stream provides:
  /// - Automatic quality selection based on user's bandwidth
  /// - Multiple resolution options (360p to 1080p)
  /// - Built-in download protection
  String getPlaybackUrl(String videoGuid) {
    // Return HLS playlist URL for adaptive streaming
    return 'https://$_cdnHostname/$videoGuid/playlist.m3u8';
  }

  /// Get direct MP4 URL for specific quality
  /// Available qualities: 240p, 360p, 480p, 720p, 1080p, 1440p, 2160p
  String getDirectUrl(String videoGuid, {String quality = '720p'}) {
    return 'https://$_cdnHostname/$videoGuid/play_$quality.mp4';
  }

  /// Get thumbnail URL for a video
  /// Bunny Stream automatically generates thumbnails at various timestamps
  String getThumbnailUrl(String videoGuid) {
    // Get thumbnail at 5 seconds into the video
    return 'https://$_cdnHostname/$videoGuid/thumbnail.jpg';
  }

  /// Get video information from Bunny Stream
  /// Returns video metadata including:
  /// - Encoding status (queued, processing, finished, failed)
  /// - Available resolutions
  /// - Video duration
  /// - File size
  Future<Map<String, dynamic>?> getVideoInfo(String videoGuid) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseApiUrl/videos/$videoGuid'),
        headers: {
          'AccessKey': _apiKey,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get video info: ${response.body}');
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error getting video info: $e');
      return null;
    }
  }

  /// Check if video transcoding is complete
  /// Returns true if video is ready for playback
  Future<bool> isVideoReady(String videoGuid) async {
    try {
      final info = await getVideoInfo(videoGuid);
      if (info == null) return false;

      final status = info['status'] as int?;
      // Status codes: 0=Queued, 1=Processing, 2=Encoding, 3=Finished, 4=Resolution finished, 5=Failed
      return status == 3 || status == 4;
    } catch (e) {
      print('❌ Error checking video status: $e');
      return false;
    }
  }

  /// Delete video from Bunny Stream
  Future<bool> deleteVideo(String videoGuid) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseApiUrl/videos/$videoGuid'),
        headers: {
          'AccessKey': _apiKey,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete video: ${response.body}');
      }

      print('✅ Video deleted: $videoGuid');
      return true;
    } catch (e) {
      print('❌ Error deleting video: $e');
      return false;
    }
  }

  /// Update video metadata (title, description, etc.)
  Future<bool> updateVideoMetadata({
    required String videoGuid,
    String? title,
    Map<String, dynamic>? metaTags,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (metaTags != null) body['metaTags'] = metaTags;

      final response = await http.post(
        Uri.parse('$_baseApiUrl/videos/$videoGuid'),
        headers: {
          'AccessKey': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update video: ${response.body}');
      }

      return true;
    } catch (e) {
      print('❌ Error updating video metadata: $e');
      return false;
    }
  }

  /// Get secure signed URL for video playback (with expiration and security token)
  /// This is called via Cloud Function to add additional security checks
  Future<String?> getSecurePlaybackUrl({
    required String videoGuid,
    required String courseId,
    required String videoId,
  }) async {
    try {
      print('🔐 Requesting secure playback URL for: $videoGuid');

      // Get Firebase ID token for authentication
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to access videos');
      }

      final idToken = await user.getIdToken();
      if (idToken == null) {
        throw Exception('Failed to get authentication token');
      }

      // Call Cloud Function to get signed URL with enrollment validation
      final response = await http.post(
        Uri.parse('https://us-central1-website-sombo.cloudfunctions.net/getBunnySecureUrl'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'videoGuid': videoGuid,
          'courseId': courseId,
          'videoId': videoId,
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to generate secure URL');
      }

      final data = jsonDecode(response.body);
      final signedUrl = data['signedUrl'] as String?;

      if (signedUrl == null) {
        throw Exception('Failed to generate secure URL');
      }

      print('✅ Secure playback URL generated');
      return signedUrl;
    } catch (e) {
      print('❌ Error getting secure playback URL: $e');
      throw Exception('Failed to load video: $e');
    }
  }
}
