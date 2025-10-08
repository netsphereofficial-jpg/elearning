const { onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const axios = require("axios");
const jwt = require("jsonwebtoken");

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp();
}

// Set global options
setGlobalOptions({
  maxInstances: 10,
  region: "us-central1",
});

// Bunny.net Configuration
// Set these via: firebase functions:config:set bunny.library_id="xxx" bunny.api_key="xxx"
const BUNNY_LIBRARY_ID = process.env.BUNNY_LIBRARY_ID || "YOUR_LIBRARY_ID";
const BUNNY_API_KEY = process.env.BUNNY_API_KEY || "YOUR_API_KEY";
const BUNNY_CDN_HOSTNAME = process.env.BUNNY_CDN_HOSTNAME || "vz-xxxxx.b-cdn.net"; // From Bunny dashboard

/**
 * Generate signed URL for Bunny Stream video
 */
exports.generateSignedVideoUrlBunny = onCall(async (request) => {
  try {
    // Check authentication
    if (!request.auth) {
      throw new Error("User must be authenticated to access videos.");
    }

    const userId = request.auth.uid;
    const { videoId } = request.data;

    if (!videoId) {
      throw new Error("Video ID is required.");
    }

    // Get video document from Firestore
    const videoDoc = await admin.firestore().collection("videos").doc(videoId).get();

    if (!videoDoc.exists) {
      throw new Error("Video not found.");
    }

    const videoData = videoDoc.data();

    // Check if user has access (premium check)
    if (videoData.isPremium) {
      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      const userData = userDoc.data();

      if (!userData || !userData.isPremium) {
        throw new Error("User does not have access to premium content.");
      }
    }

    // Check concurrent sessions
    const activeSessions = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("sessions")
      .where("isActive", "==", true)
      .get();

    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const maxSessions = userDoc.data()?.maxConcurrentSessions || 2;

    if (activeSessions.size >= maxSessions) {
      throw new Error("Maximum concurrent sessions reached.");
    }

    // Get Bunny video GUID
    const bunnyVideoGuid = videoData.bunnyVideoGuid;

    if (!bunnyVideoGuid) {
      throw new Error("Video not properly configured.");
    }

    // Generate token-protected URL
    const expirationTime = Math.floor(Date.now() / 1000) + 4 * 60 * 60; // 4 hours

    // Create JWT token for additional security
    const token = jwt.sign(
      {
        userId: userId,
        videoId: videoId,
        bunnyVideoGuid: bunnyVideoGuid,
        exp: expirationTime,
      },
      process.env.JWT_SECRET || "your-secret-key-change-this"
    );

    // Bunny Stream URL format (with token protection if enabled in Bunny dashboard)
    // Standard format: https://vz-xxxxx.b-cdn.net/{videoGuid}/playlist.m3u8
    const signedUrl = `https://${BUNNY_CDN_HOSTNAME}/${bunnyVideoGuid}/playlist.m3u8`;

    // Log the access
    await admin.firestore().collection("videoAccess").add({
      userId: userId,
      videoId: videoId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ipAddress: request.rawRequest?.ip || "unknown",
      userAgent: request.rawRequest?.headers["user-agent"] || "unknown",
    });

    return {
      signedUrl: signedUrl,
      expiresAt: expirationTime,
      token: token,
      videoGuid: bunnyVideoGuid,
    };
  } catch (error) {
    console.error("Error generating signed URL:", error);
    throw new Error(`Failed to generate video URL: ${error.message}`);
  }
});

/**
 * Upload video to Bunny Stream (Admin only)
 */
exports.uploadVideoToBunny = onCall(async (request) => {
  try {
    // Check authentication and admin status
    if (!request.auth) {
      throw new Error("User must be authenticated.");
    }

    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(request.auth.uid)
      .get();

    if (!userDoc.exists || !userDoc.data().isAdmin) {
      throw new Error("User does not have admin privileges.");
    }

    const { videoUrl, title, description, category } = request.data;

    if (!videoUrl || !title) {
      throw new Error("Video URL and title are required.");
    }

    // Create video in Bunny Stream via their API
    const response = await axios.post(
      `https://video.bunnycdn.com/library/${BUNNY_LIBRARY_ID}/videos`,
      {
        title: title,
      },
      {
        headers: {
          AccessKey: BUNNY_API_KEY,
          "Content-Type": "application/json",
        },
      }
    );

    const bunnyVideoGuid = response.data.guid;
    const bunnyVideoId = response.data.videoLibraryId;

    // Upload video file from URL
    await axios.put(
      `https://video.bunnycdn.com/library/${BUNNY_LIBRARY_ID}/videos/${bunnyVideoGuid}`,
      {
        videoUrl: videoUrl,
      },
      {
        headers: {
          AccessKey: BUNNY_API_KEY,
          "Content-Type": "application/json",
        },
      }
    );

    // Get video details (after processing starts)
    const videoDetails = await axios.get(
      `https://video.bunnycdn.com/library/${BUNNY_LIBRARY_ID}/videos/${bunnyVideoGuid}`,
      {
        headers: {
          AccessKey: BUNNY_API_KEY,
        },
      }
    );

    // Create video document in Firestore
    const videoRef = await admin
      .firestore()
      .collection("videos")
      .add({
        title: title,
        description: description || "",
        bunnyVideoGuid: bunnyVideoGuid,
        bunnyVideoId: bunnyVideoId,
        thumbnailUrl: `https://${BUNNY_CDN_HOSTNAME}/${bunnyVideoGuid}/thumbnail.jpg`,
        category: category || "General",
        isPremium: false,
        uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
        viewCount: 0,
        tags: [],
        durationInSeconds: 0, // Will be updated after Bunny processes the video
        processingStatus: "processing",
      });

    return {
      success: true,
      videoId: videoRef.id,
      bunnyVideoGuid: bunnyVideoGuid,
      message: "Video is being processed. This may take 5-30 minutes.",
    };
  } catch (error) {
    console.error("Error uploading video to Bunny:", error);
    throw new Error(`Failed to upload video: ${error.message}`);
  }
});

/**
 * Check video processing status
 */
exports.checkBunnyVideoStatus = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new Error("User must be authenticated.");
    }

    const { videoId } = request.data;

    const videoDoc = await admin.firestore().collection("videos").doc(videoId).get();

    if (!videoDoc.exists) {
      throw new Error("Video not found.");
    }

    const videoData = videoDoc.data();
    const bunnyVideoGuid = videoData.bunnyVideoGuid;

    // Get video status from Bunny
    const response = await axios.get(
      `https://video.bunnycdn.com/library/${BUNNY_LIBRARY_ID}/videos/${bunnyVideoGuid}`,
      {
        headers: {
          AccessKey: BUNNY_API_KEY,
        },
      }
    );

    const status = response.data;

    // Update Firestore if processing is complete
    if (status.status === 4) {
      // 4 = Finished
      await admin.firestore().collection("videos").doc(videoId).update({
        processingStatus: "completed",
        durationInSeconds: status.length || 0,
      });
    }

    return {
      status: status.status, // 0=Queued, 1=Processing, 2=Encoding, 3=Finished, 4=Ready
      progress: status.encodeProgress || 0,
      duration: status.length || 0,
      message:
        status.status === 4 ? "Ready to stream" : "Processing...",
    };
  } catch (error) {
    console.error("Error checking video status:", error);
    throw new Error(`Failed to check status: ${error.message}`);
  }
});

/**
 * Validate video access token
 */
exports.validateVideoToken = onCall(async (request) => {
  try {
    const { token } = request.data;

    if (!token) {
      throw new Error("Token is required.");
    }

    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET || "your-secret-key-change-this"
    );

    return {
      valid: true,
      userId: decoded.userId,
      videoId: decoded.videoId,
    };
  } catch (error) {
    return {
      valid: false,
      error: error.message,
    };
  }
});

/**
 * Clean up expired sessions
 */
exports.cleanupExpiredSessions = onSchedule("every 1 hours", async (event) => {
  const expirationTime = new Date(Date.now() - 4 * 60 * 60 * 1000);
  const usersSnapshot = await admin.firestore().collection("users").get();

  let cleanedCount = 0;

  for (const userDoc of usersSnapshot.docs) {
    const sessionsSnapshot = await userDoc.ref
      .collection("sessions")
      .where("isActive", "==", true)
      .get();

    for (const sessionDoc of sessionsSnapshot.docs) {
      const lastActive = sessionDoc.data().lastActiveAt?.toDate();
      if (lastActive && lastActive < expirationTime) {
        await sessionDoc.ref.update({ isActive: false });
        cleanedCount++;
      }
    }
  }

  console.log(`Cleaned up ${cleanedCount} expired sessions`);
  return { cleanedCount };
});

/**
 * Monitor abnormal playback patterns
 */
exports.detectAbnormalPlayback = onDocumentUpdated(
  "users/{userId}/watchHistory/{videoId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    const timeDiff = after.lastWatchedPosition - before.lastWatchedPosition;
    const realTimeDiff =
      (after.lastWatchedAt.toMillis() - before.lastWatchedAt.toMillis()) / 1000;

    if (timeDiff > realTimeDiff * 2 && timeDiff > 30) {
      await admin
        .firestore()
        .collection("suspiciousActivity")
        .add({
          userId: event.params.userId,
          videoId: event.params.videoId,
          type: "ABNORMAL_PLAYBACK_SPEED",
          details: {
            positionDiff: timeDiff,
            timeDiff: realTimeDiff,
            ratio: timeDiff / realTimeDiff,
          },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log(`Suspicious activity detected for user ${event.params.userId}`);
    }
  }
);
