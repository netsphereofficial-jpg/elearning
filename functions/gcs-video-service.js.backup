const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { Storage } = require('@google-cloud/storage');
const { TranscoderServiceClient } = require('@google-cloud/video-transcoder');
const jwt = require('jsonwebtoken');

// Initialize Google Cloud Storage
const storage = new Storage();
const transcoder = new TranscoderServiceClient();

// Configuration
const BUCKET_NAME = 'your-project-id-videos'; // Change this
const CDN_URL = 'https://cdn.yourdomain.com'; // Optional custom domain
const PROJECT_ID = process.env.GCLOUD_PROJECT;
const LOCATION = 'us-central1';

/**
 * Generate signed URL for video streaming with Google Cloud Storage
 */
exports.generateSignedVideoUrlGCS = functions.https.onCall(async (data, context) => {
  try {
    // Authentication check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to access videos.'
      );
    }

    const userId = context.auth.uid;
    const { videoId } = data;

    if (!videoId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Video ID is required.'
      );
    }

    // Get video document from Firestore
    const videoDoc = await admin.firestore().collection('videos').doc(videoId).get();

    if (!videoDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Video not found.');
    }

    const videoData = videoDoc.data();

    // Check premium access
    if (videoData.isPremium) {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      const userData = userDoc.data();

      if (!userData || !userData.isPremium) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'User does not have access to premium content.'
        );
      }
    }

    // Check concurrent sessions
    const activeSessions = await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('sessions')
      .where('isActive', '==', true)
      .get();

    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const maxSessions = userDoc.data()?.maxConcurrentSessions || 2;

    if (activeSessions.size >= maxSessions) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Maximum concurrent sessions reached.'
      );
    }

    // Generate signed URL for HLS manifest
    const gcsVideoPath = videoData.gcsVideoPath; // e.g., "videos/abc123/master.m3u8"
    const bucket = storage.bucket(BUCKET_NAME);
    const file = bucket.file(gcsVideoPath);

    // Create signed URL valid for 4 hours
    const expirationTime = Date.now() + 4 * 60 * 60 * 1000; // 4 hours
    const [signedUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'read',
      expires: expirationTime,
    });

    // Create JWT token for additional security
    const token = jwt.sign(
      {
        userId: userId,
        videoId: videoId,
        exp: Math.floor(expirationTime / 1000),
      },
      process.env.JWT_SECRET || 'your-secret-key-change-this'
    );

    // Log the access
    await admin.firestore().collection('videoAccess').add({
      userId: userId,
      videoId: videoId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ipAddress: context.rawRequest?.ip || 'unknown',
      userAgent: context.rawRequest?.headers['user-agent'] || 'unknown',
    });

    return {
      signedUrl: signedUrl,
      expiresAt: Math.floor(expirationTime / 1000),
      token: token,
    };

  } catch (error) {
    console.error('Error generating signed URL:', error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while generating the video URL.'
    );
  }
});

/**
 * Upload and transcode video to HLS format
 * Admin only function
 */
exports.uploadVideoToGCS = functions.https.onCall(async (data, context) => {
  try {
    // Check if user is authenticated and is admin
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    }

    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists || !userDoc.data().isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'User does not have admin privileges.'
      );
    }

    const { title, description, category, sourceGcsUri } = data;
    // sourceGcsUri should be like: gs://your-bucket/uploads/original-video.mp4

    const videoId = admin.firestore().collection('videos').doc().id;
    const outputUri = `gs://${BUCKET_NAME}/videos/${videoId}/`;

    // Create transcoding job
    const jobConfig = {
      inputUri: sourceGcsUri,
      outputUri: outputUri,
      config: {
        elementaryStreams: [
          // Video streams - 1080p
          {
            key: 'video-1080p',
            videoStream: {
              h264: {
                widthPixels: 1920,
                heightPixels: 1080,
                frameRate: 30,
                bitrateBps: 5000000,
              },
            },
          },
          // Video streams - 720p
          {
            key: 'video-720p',
            videoStream: {
              h264: {
                widthPixels: 1280,
                heightPixels: 720,
                frameRate: 30,
                bitrateBps: 2500000,
              },
            },
          },
          // Video streams - 480p
          {
            key: 'video-480p',
            videoStream: {
              h264: {
                widthPixels: 854,
                heightPixels: 480,
                frameRate: 30,
                bitrateBps: 1000000,
              },
            },
          },
          // Audio stream
          {
            key: 'audio',
            audioStream: {
              codec: 'aac',
              bitrateBps: 128000,
              channelCount: 2,
              sampleRateHertz: 48000,
            },
          },
        ],
        muxStreams: [
          { key: 'hls-1080p', container: 'ts', elementaryStreams: ['video-1080p', 'audio'] },
          { key: 'hls-720p', container: 'ts', elementaryStreams: ['video-720p', 'audio'] },
          { key: 'hls-480p', container: 'ts', elementaryStreams: ['video-480p', 'audio'] },
        ],
        manifests: [
          {
            fileName: 'master.m3u8',
            type: 'HLS',
            muxStreams: ['hls-1080p', 'hls-720p', 'hls-480p'],
          },
        ],
      },
    };

    // Submit transcoding job
    const [job] = await transcoder.createJob({
      parent: transcoder.locationPath(PROJECT_ID, LOCATION),
      job: jobConfig,
    });

    console.log(`Transcoding job created: ${job.name}`);

    // Generate thumbnail (simplified - you'd extract frame at 10 seconds)
    const thumbnailPath = `videos/${videoId}/thumbnail.jpg`;

    // Create video document in Firestore
    const videoRef = await admin.firestore().collection('videos').add({
      title: title,
      description: description || '',
      gcsVideoPath: `videos/${videoId}/master.m3u8`,
      thumbnailPath: thumbnailPath,
      thumbnailUrl: `https://storage.googleapis.com/${BUCKET_NAME}/${thumbnailPath}`,
      category: category || 'General',
      isPremium: false,
      uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
      viewCount: 0,
      tags: [],
      durationInSeconds: 0, // Update after transcoding completes
      transcodingJobName: job.name,
      transcodingStatus: 'PROCESSING',
    });

    return {
      success: true,
      videoId: videoRef.id,
      transcodingJobName: job.name,
      message: 'Video is being transcoded. This may take 10-30 minutes depending on video length.',
    };

  } catch (error) {
    console.error('Error uploading video:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Failed to upload video: ${error.message}`
    );
  }
});

/**
 * Check transcoding job status
 * This can be called periodically or set up as a Cloud Scheduler job
 */
exports.checkTranscodingStatus = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    }

    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists || !userDoc.data().isAdmin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required.');
    }

    const { videoId } = data;
    const videoDoc = await admin.firestore().collection('videos').doc(videoId).get();

    if (!videoDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Video not found.');
    }

    const videoData = videoDoc.data();
    const jobName = videoData.transcodingJobName;

    // Get job status from Transcoder API
    const [job] = await transcoder.getJob({ name: jobName });

    let status = 'UNKNOWN';
    if (job.state === 'SUCCEEDED') {
      status = 'COMPLETED';

      // Update video document with completion status
      await admin.firestore().collection('videos').doc(videoId).update({
        transcodingStatus: 'COMPLETED',
      });
    } else if (job.state === 'FAILED') {
      status = 'FAILED';

      await admin.firestore().collection('videos').doc(videoId).update({
        transcodingStatus: 'FAILED',
      });
    } else if (job.state === 'RUNNING') {
      status = 'PROCESSING';
    }

    return {
      videoId: videoId,
      status: status,
      progress: job.progress || 0,
      message: job.error ? job.error.message : 'Processing...',
    };

  } catch (error) {
    console.error('Error checking transcoding status:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Failed to check status: ${error.message}`
    );
  }
});

/**
 * Generate thumbnail from video
 * Triggered when transcoding completes
 */
exports.generateThumbnail = functions.storage.object().onFinalize(async (object) => {
  const filePath = object.name;

  // Only process master.m3u8 files
  if (!filePath.includes('master.m3u8')) {
    return null;
  }

  // Extract video ID from path (e.g., videos/abc123/master.m3u8)
  const pathParts = filePath.split('/');
  const videoId = pathParts[1];

  console.log(`Processing thumbnail for video ${videoId}`);

  // In a real implementation, you'd use ffmpeg via Cloud Run to extract a frame
  // For now, we'll just log that transcoding is complete

  // Update video status
  const videosRef = admin.firestore().collection('videos');
  const snapshot = await videosRef.where('gcsVideoPath', '==', filePath).get();

  if (!snapshot.empty) {
    const doc = snapshot.docs[0];
    await doc.ref.update({
      transcodingStatus: 'COMPLETED',
    });
    console.log(`Video ${doc.id} marked as completed`);
  }

  return null;
});
