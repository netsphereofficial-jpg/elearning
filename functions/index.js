const { onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const axios = require("axios");
const jwt = require("jsonwebtoken");

// Initialize Firebase Admin
admin.initializeApp();

// Set global options for all functions
setGlobalOptions({
  maxInstances: 10,
  region: "us-central1",
});

// Configuration - Replace with your Cloudflare credentials
// Or set via: firebase functions:config:set cloudflare.account_id="xxx"
const CLOUDFLARE_ACCOUNT_ID = process.env.CLOUDFLARE_ACCOUNT_ID || "YOUR_ACCOUNT_ID";
const CLOUDFLARE_API_TOKEN = process.env.CLOUDFLARE_API_TOKEN || "YOUR_API_TOKEN";
const CLOUDFLARE_STREAM_URL = `https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream`;

/**
 * Generate a signed URL for video streaming (Cloudflare Stream)
 * This function:
 * 1. Validates user authentication
 * 2. Checks if user has access to the video
 * 3. Generates a time-limited signed URL from Cloudflare Stream
 * 4. Tracks the access in Firestore
 */
exports.generateSignedVideoUrl = onCall(async (request) => {
  try {
    // Check if user is authenticated
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

    // Generate signed URL from Cloudflare Stream
    const cloudflareVideoId = videoData.cloudflareVideoId;

    // For Cloudflare Stream, we can use signed URLs with tokens
    // This is a simplified version - in production, use Cloudflare's signing mechanism
    const expirationTime = Math.floor(Date.now() / 1000) + 4 * 60 * 60; // 4 hours

    // Create a JWT token for additional security
    const token = jwt.sign(
      {
        userId: userId,
        videoId: videoId,
        exp: expirationTime,
      },
      process.env.JWT_SECRET || "your-secret-key-change-this"
    );

    // Cloudflare Stream URL format
    // Replace with actual Cloudflare Stream signed URL generation
    const signedUrl = `https://customer-${CLOUDFLARE_ACCOUNT_ID}.cloudflarestream.com/${cloudflareVideoId}/manifest/video.m3u8?token=${token}`;

    // Log the access
    await admin.firestore().collection("videoAccess").add({
      userId: userId,
      videoId: videoId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ipAddress: request.rawRequest?.ip || "unknown",
      userAgent: request.rawRequest?.headers["user-agent"] || "unknown",
    });

    // Return the signed URL
    return {
      signedUrl: signedUrl,
      expiresAt: expirationTime,
      token: token,
    };
  } catch (error) {
    console.error("Error generating signed URL:", error);
    throw new Error(`Failed to generate video URL: ${error.message}`);
  }
});

/**
 * Validate video access token
 * Used to verify tokens before streaming
 */
exports.validateVideoToken = onCall(async (request) => {
  try {
    const { token } = request.data;

    if (!token) {
      throw new Error("Token is required.");
    }

    // Verify JWT token
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
    console.error("Token validation error:", error);

    return {
      valid: false,
      error: error.message,
    };
  }
});

/**
 * Clean up expired sessions
 * Runs every hour to remove inactive sessions
 */
exports.cleanupExpiredSessions = onSchedule("every 1 hours", async (event) => {
  const expirationTime = new Date(Date.now() - 4 * 60 * 60 * 1000); // 4 hours ago

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
 * Detects if users are trying to speed through videos or download content
 */
exports.detectAbnormalPlayback = onDocumentUpdated(
  "users/{userId}/watchHistory/{videoId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    const timeDiff = after.lastWatchedPosition - before.lastWatchedPosition;
    const realTimeDiff =
      (after.lastWatchedAt.toMillis() - before.lastWatchedAt.toMillis()) / 1000;

    // If video position changed by more than 2x real time, flag as suspicious
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

/**
 * Upload video to Cloudflare Stream (Admin function)
 * This can be called from an admin panel
 */
exports.uploadVideoToCloudflare = onCall(async (request) => {
  try {
    // Check if user is authenticated and is admin
    if (!request.auth) {
      throw new Error("User must be authenticated.");
    }

    // Check if user is admin (you should implement proper admin check)
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(request.auth.uid)
      .get();
    if (!userDoc.exists || !userDoc.data().isAdmin) {
      throw new Error("User does not have admin privileges.");
    }

    const { videoUrl, title, description, category } = request.data;

    // Upload to Cloudflare Stream
    const response = await axios.post(
      CLOUDFLARE_STREAM_URL,
      {
        url: videoUrl,
        meta: {
          name: title,
        },
      },
      {
        headers: {
          Authorization: `Bearer ${CLOUDFLARE_API_TOKEN}`,
        },
      }
    );

    const cloudflareVideoId = response.data.result.uid;
    const thumbnailUrl = response.data.result.thumbnail;

    // Create video document in Firestore
    const videoRef = await admin
      .firestore()
      .collection("videos")
      .add({
        title: title,
        description: description || "",
        cloudflareVideoId: cloudflareVideoId,
        thumbnailUrl: thumbnailUrl,
        category: category || "General",
        isPremium: false,
        uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
        viewCount: 0,
        tags: [],
        durationInSeconds: 0, // Update this after Cloudflare processing
      });

    return {
      success: true,
      videoId: videoRef.id,
      cloudflareVideoId: cloudflareVideoId,
    };
  } catch (error) {
    console.error("Error uploading video:", error);
    throw new Error(`Failed to upload video to Cloudflare Stream: ${error.message}`);
  }
});
