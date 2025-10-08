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

// Bunny.net Stream Configuration
const BUNNY_LIBRARY_ID = process.env.BUNNY_LIBRARY_ID || "506127";
const BUNNY_API_KEY = process.env.BUNNY_API_KEY || "fcb219ae-cdd0-4d5e-84bab396f607-ac7e-45c2";
const BUNNY_CDN_HOSTNAME = process.env.BUNNY_CDN_HOSTNAME || "vz-d86440c8-58b.b-cdn.net";

/**
 * Generate signed URL for Bunny Stream video
 */
exports.generateSignedVideoUrl = onCall(async (request) => {
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
      throw new Error("Video not properly configured in Bunny Stream.");
    }

    // Generate token for additional security
    const expirationTime = Math.floor(Date.now() / 1000) + 4 * 60 * 60; // 4 hours

    const token = jwt.sign(
      {
        userId: userId,
        videoId: videoId,
        bunnyVideoGuid: bunnyVideoGuid,
        exp: expirationTime,
      },
      process.env.JWT_SECRET || "your-secret-key-change-this"
    );

    // Bunny Stream HLS URL format
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
 * Upload video to Bunny Stream (Admin only) - Legacy function
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

    const { title, collectionId } = request.data;

    if (!title) {
      throw new Error("Title is required.");
    }

    // Create video in Bunny Stream
    const response = await axios.post(
      `https://video.bunnycdn.com/library/${BUNNY_LIBRARY_ID}/videos`,
      {
        title: title,
        collectionId: collectionId || "",
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

    // Create video document in Firestore
    const videoRef = await admin
      .firestore()
      .collection("videos")
      .add({
        title: title,
        description: "",
        bunnyVideoGuid: bunnyVideoGuid,
        bunnyVideoId: bunnyVideoId,
        thumbnailUrl: `https://${BUNNY_CDN_HOSTNAME}/${bunnyVideoGuid}/thumbnail.jpg`,
        category: "General",
        isPremium: false,
        uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
        viewCount: 0,
        tags: [],
        durationInSeconds: 0,
        processingStatus: "pending",
      });

    return {
      success: true,
      videoId: videoRef.id,
      bunnyVideoGuid: bunnyVideoGuid,
      uploadUrl: `https://video.bunnycdn.com/library/${BUNNY_LIBRARY_ID}/videos/${bunnyVideoGuid}`,
      message: "Video created. You can now upload the file via Bunny dashboard or API.",
    };
  } catch (error) {
    console.error("Error creating video in Bunny:", error);
    throw new Error(`Failed to create video: ${error.message}`);
  }
});

/**
 * Create video in Bunny Stream and return upload credentials (Admin only)
 */
exports.createBunnyVideoForUpload = onCall(async (request) => {
  try {
    console.log("createBunnyVideoForUpload called");

    // Check authentication and admin status
    if (!request.auth) {
      console.error("No authentication");
      throw new Error("User must be authenticated.");
    }

    console.log("User authenticated:", request.auth.uid);

    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(request.auth.uid)
      .get();

    if (!userDoc.exists) {
      console.error("User document not found");
      throw new Error("User document not found.");
    }

    const userData = userDoc.data();
    console.log("User data:", { role: userData.role, email: userData.email });

    // Check if user has admin role
    if (userData.role !== 'admin') {
      console.error("User is not admin. Role:", userData.role);
      throw new Error("User does not have admin privileges.");
    }

    const { title } = request.data;

    if (!title) {
      console.error("No title provided");
      throw new Error("Video title is required.");
    }

    console.log("Creating video in Bunny with title:", title);

    // Create video in Bunny Stream
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
    console.log("Video created successfully. GUID:", bunnyVideoGuid);

    return {
      success: true,
      bunnyVideoGuid: bunnyVideoGuid,
      libraryId: BUNNY_LIBRARY_ID,
      uploadApiKey: BUNNY_API_KEY,
      uploadUrl: `https://video.bunnycdn.com/library/${BUNNY_LIBRARY_ID}/videos/${bunnyVideoGuid}`,
      thumbnailUrl: `https://${BUNNY_CDN_HOSTNAME}/${bunnyVideoGuid}/thumbnail.jpg`,
    };
  } catch (error) {
    console.error("Error in createBunnyVideoForUpload:", error);
    console.error("Error details:", error.message, error.stack);
    throw new Error(`Failed to create video: ${error.message}`);
  }
});

/**
 * Check Bunny video processing status by GUID
 */
exports.checkBunnyVideoStatus = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new Error("User must be authenticated.");
    }

    const { videoGuid } = request.data;

    if (!videoGuid) {
      throw new Error("Video GUID is required.");
    }

    // Get video status from Bunny
    const response = await axios.get(
      `https://video.bunnycdn.com/library/${BUNNY_LIBRARY_ID}/videos/${videoGuid}`,
      {
        headers: {
          AccessKey: BUNNY_API_KEY,
        },
      }
    );

    const status = response.data;

    return {
      status: status.status, // 0-5
      progress: status.encodeProgress || 0,
      duration: status.length || 0,
      availableResolutions: status.availableResolutions || [],
      message: status.status === 4 || status.status === 5 ? "Ready to stream" : "Processing...",
    };
  } catch (error) {
    console.error("Error checking video status:", error);
    throw new Error(`Failed to check status: ${error.message}`);
  }
});

/**
 * Check video processing status
 */
exports.checkVideoStatus = onCall(async (request) => {
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
    if (status.status === 4 || status.status === 5) {
      // 4 = Transcoding, 5 = Finished
      await admin.firestore().collection("videos").doc(videoId).update({
        processingStatus: "completed",
        durationInSeconds: status.length || 0,
      });
    }

    return {
      status: status.status, // Status codes: 0-6
      progress: status.encodeProgress || 0,
      duration: status.length || 0,
      availableResolutions: status.availableResolutions || [],
      message: status.status === 5 ? "Ready to stream" : "Processing...",
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
 * Clean up expired sessions (runs every hour)
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
 * Clean up old video upload files from Firebase Storage (runs every hour)
 */
exports.cleanupVideoUploads = onSchedule("every 1 hours", async (event) => {
  try {
    console.log("Starting video upload cleanup...");

    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
    const bucket = admin.storage().bucket();

    // Get all video upload records older than 30 minutes
    const uploadsSnapshot = await admin
      .firestore()
      .collection("videoUploads")
      .where("uploadedAt", "<", thirtyMinutesAgo)
      .get();

    let cleanedCount = 0;
    let errorCount = 0;

    for (const doc of uploadsSnapshot.docs) {
      const upload = doc.data();

      try {
        // Delete file from Firebase Storage
        const file = bucket.file(upload.storagePath);
        await file.delete();
        console.log(`Deleted file: ${upload.storagePath}`);

        // Delete the tracking document
        await doc.ref.delete();
        cleanedCount++;
      } catch (error) {
        // File might already be deleted or not exist
        console.warn(`Could not delete ${upload.storagePath}:`, error.message);

        // Delete tracking document anyway if file doesn't exist
        if (error.code === 404 || error.code === "storage/object-not-found") {
          await doc.ref.delete();
        } else {
          errorCount++;
        }
      }
    }

    console.log(`Cleanup complete. Deleted ${cleanedCount} files, ${errorCount} errors`);
    return { cleanedCount, errorCount };
  } catch (error) {
    console.error("Error in cleanup function:", error);
    return { error: error.message };
  }
});

/**
 * Transfer video from Firebase Storage to Bunny Stream
 */
exports.transferVideoToBunny = onCall({ timeoutSeconds: 540 }, async (request) => {
  try {
    console.log("transferVideoToBunny called");

    // Check authentication and admin status
    if (!request.auth) {
      throw new Error("User must be authenticated.");
    }

    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(request.auth.uid)
      .get();

    if (!userDoc.exists || userDoc.data().role !== "admin") {
      throw new Error("User does not have admin privileges.");
    }

    const { bunnyVideoGuid, storagePath, title } = request.data;

    if (!bunnyVideoGuid || !storagePath) {
      throw new Error("Missing required parameters.");
    }

    console.log(`Transferring video from ${storagePath} to Bunny GUID ${bunnyVideoGuid}`);

    // Download file from Firebase Storage
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);

    // Get file metadata
    const [metadata] = await file.getMetadata();
    console.log(`File size: ${metadata.size} bytes`);

    // Make file temporarily public so Bunny can access it
    await file.makePublic();
    console.log("File made temporarily public");

    // Get public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
    console.log(`Public URL: ${publicUrl}`);

    // Tell Bunny to fetch the video from the public URL
    const response = await axios.post(
      `https://video.bunnycdn.com/library/${BUNNY_LIBRARY_ID}/videos/${bunnyVideoGuid}/fetch`,
      {
        url: publicUrl,
        headers: {},
      },
      {
        headers: {
          AccessKey: BUNNY_API_KEY,
          "Content-Type": "application/json",
        },
      }
    );

    console.log("Bunny fetch response:", response.status, response.data);

    // NOTE: We don't delete the file immediately because Bunny needs time to download it.
    // The "fetch" API returns 200 OK immediately but downloads in background.
    // Files will be cleaned up by the scheduled cleanup function after 30 minutes.

    // Store metadata for cleanup
    await admin.firestore().collection("videoUploads").add({
      bunnyVideoGuid: bunnyVideoGuid,
      storagePath: storagePath,
      uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "transferred",
    });

    console.log("Video transfer initiated. File will be cleaned up automatically in 30 minutes.");

    return {
      success: true,
      message: "Video is being transferred to Bunny. Processing may take a few minutes.",
      bunnyVideoGuid: bunnyVideoGuid,
    };
  } catch (error) {
    console.error("Error transferring video to Bunny:", error);
    throw new Error(`Failed to transfer video: ${error.message}`);
  }
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
