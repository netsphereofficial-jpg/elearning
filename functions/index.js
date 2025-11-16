const { onCall, onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const axios = require("axios");
const jwt = require("jsonwebtoken");
const { S3Client, PutObjectCommand, GetObjectCommand, HeadObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");

// Initialize Firebase Admin
admin.initializeApp();

// Set global options for all functions
setGlobalOptions({
  maxInstances: 10,
  region: "us-central1",
});

// Cloudflare R2 Configuration
const R2_ACCOUNT_ID = process.env.R2_ACCOUNT_ID;
const R2_ACCESS_KEY_ID = process.env.R2_ACCESS_KEY_ID;
const R2_SECRET_ACCESS_KEY = process.env.R2_SECRET_ACCESS_KEY;
const R2_BUCKET_NAME = process.env.R2_BUCKET_NAME || "nikhil-bucket";
const R2_PUBLIC_DOMAIN = process.env.R2_PUBLIC_DOMAIN; // Optional: Custom domain for R2

// Initialize R2 Client
const r2Client = new S3Client({
  region: "auto",
  endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: R2_ACCESS_KEY_ID,
    secretAccessKey: R2_SECRET_ACCESS_KEY,
  },
});

/**
 * Generate signed URL for R2 video
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

    // Get R2 video key
    const r2VideoKey = videoData.r2VideoKey;

    if (!r2VideoKey) {
      throw new Error("Video not properly configured in R2 storage.");
    }

    // Generate signed URL for R2 video (4 hours expiration)
    const command = new GetObjectCommand({
      Bucket: R2_BUCKET_NAME,
      Key: r2VideoKey,
    });

    const signedUrl = await getSignedUrl(r2Client, command, { expiresIn: 4 * 60 * 60 });
    const expirationTime = Math.floor(Date.now() / 1000) + 4 * 60 * 60;

    // Generate token for additional security
    const token = jwt.sign(
      {
        userId: userId,
        videoId: videoId,
        r2VideoKey: r2VideoKey,
        exp: expirationTime,
      },
      process.env.JWT_SECRET || "your-secret-key-change-this"
    );

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
      videoKey: r2VideoKey,
    };
  } catch (error) {
    console.error("Error generating signed URL:", error);
    throw new Error(`Failed to generate video URL: ${error.message}`);
  }
});

/**
 * Generate presigned upload URL for R2 (Admin only)
 */
exports.getUploadUrl = onCall(async (request) => {
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

    if (!userDoc.exists || userDoc.data().role !== "admin") {
      throw new Error("User does not have admin privileges.");
    }

    const { fileName, contentType } = request.data;

    if (!fileName) {
      throw new Error("File name is required.");
    }

    // Generate unique key for R2
    const timestamp = Date.now();
    const randomId = Math.random().toString(36).substring(7);
    const r2VideoKey = `videos/${timestamp}-${randomId}-${fileName}`;

    // Generate presigned URL for upload (valid for 1 hour)
    const command = new PutObjectCommand({
      Bucket: R2_BUCKET_NAME,
      Key: r2VideoKey,
      ContentType: contentType || "video/mp4",
    });

    const uploadUrl = await getSignedUrl(r2Client, command, { expiresIn: 3600 });

    return {
      success: true,
      uploadUrl: uploadUrl,
      r2VideoKey: r2VideoKey,
      expiresIn: 3600,
    };
  } catch (error) {
    console.error("Error generating upload URL:", error);
    throw new Error(`Failed to generate upload URL: ${error.message}`);
  }
});

/**
 * Create R2 video entry and return upload URL (Admin only)
 */
exports.createR2VideoForUpload = onCall(async (request) => {
  try {
    console.log("createR2VideoForUpload called");

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

    const { title, fileName, contentType } = request.data;

    if (!title) {
      console.error("No title provided");
      throw new Error("Video title is required.");
    }

    if (!fileName) {
      console.error("No file name provided");
      throw new Error("File name is required.");
    }

    console.log("Creating R2 video entry with title:", title);

    // Generate unique key for R2
    const timestamp = Date.now();
    const randomId = Math.random().toString(36).substring(7);
    const r2VideoKey = `videos/${timestamp}-${randomId}-${fileName}`;

    // Generate presigned URL for upload (valid for 1 hour)
    const command = new PutObjectCommand({
      Bucket: R2_BUCKET_NAME,
      Key: r2VideoKey,
      ContentType: contentType || "video/mp4",
    });

    const uploadUrl = await getSignedUrl(r2Client, command, { expiresIn: 3600 });

    console.log("R2 video entry created successfully. Key:", r2VideoKey);

    return {
      success: true,
      r2VideoKey: r2VideoKey,
      uploadUrl: uploadUrl,
      expiresIn: 3600,
      // Placeholder thumbnail - you can implement thumbnail generation later
      thumbnailUrl: "",
    };
  } catch (error) {
    console.error("Error in createR2VideoForUpload:", error);
    console.error("Error details:", error.message, error.stack);
    throw new Error(`Failed to create video entry: ${error.message}`);
  }
});

/**
 * Check R2 video upload status
 */
exports.checkR2VideoStatus = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new Error("User must be authenticated.");
    }

    const { r2VideoKey } = request.data;

    if (!r2VideoKey) {
      throw new Error("R2 video key is required.");
    }

    // Check if video exists in R2
    const command = new HeadObjectCommand({
      Bucket: R2_BUCKET_NAME,
      Key: r2VideoKey,
    });

    try {
      const response = await r2Client.send(command);

      return {
        exists: true,
        size: response.ContentLength,
        contentType: response.ContentType,
        lastModified: response.LastModified,
        message: "Video uploaded successfully and ready to stream",
      };
    } catch (error) {
      if (error.name === 'NotFound') {
        return {
          exists: false,
          message: "Video not found in R2 storage",
        };
      }
      throw error;
    }
  } catch (error) {
    console.error("Error checking video status:", error);
    throw new Error(`Failed to check status: ${error.message}`);
  }
});

/**
 * Check video upload status by videoId
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
    const r2VideoKey = videoData.r2VideoKey;

    if (!r2VideoKey) {
      throw new Error("Video key not found.");
    }

    // Check if video exists in R2
    const command = new HeadObjectCommand({
      Bucket: R2_BUCKET_NAME,
      Key: r2VideoKey,
    });

    try {
      const response = await r2Client.send(command);

      // Update Firestore if not already marked as completed
      if (videoData.processingStatus !== "completed") {
        await admin.firestore().collection("videos").doc(videoId).update({
          processingStatus: "completed",
        });
      }

      return {
        exists: true,
        size: response.ContentLength,
        contentType: response.ContentType,
        message: "Video ready to stream",
      };
    } catch (error) {
      if (error.name === 'NotFound') {
        return {
          exists: false,
          message: "Video not yet uploaded",
        };
      }
      throw error;
    }
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
 * Confirm video upload to R2 and update Firestore (Admin only)
 */
exports.confirmR2VideoUpload = onCall(async (request) => {
  try {
    console.log("confirmR2VideoUpload called");

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

    const { r2VideoKey } = request.data;

    if (!r2VideoKey) {
      throw new Error("R2 video key is required.");
    }

    console.log(`Confirming upload for video: ${r2VideoKey}`);

    // Verify video exists in R2
    const command = new HeadObjectCommand({
      Bucket: R2_BUCKET_NAME,
      Key: r2VideoKey,
    });

    try {
      const response = await r2Client.send(command);
      console.log(`Video confirmed in R2. Size: ${response.ContentLength} bytes`);

      return {
        success: true,
        message: "Video uploaded successfully to R2",
        r2VideoKey: r2VideoKey,
        size: response.ContentLength,
      };
    } catch (error) {
      if (error.name === 'NotFound') {
        throw new Error("Video not found in R2 storage. Upload may have failed.");
      }
      throw error;
    }
  } catch (error) {
    console.error("Error confirming video upload:", error);
    throw new Error(`Failed to confirm upload: ${error.message}`);
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

/**
 * Generate secure signed URL for Firebase Storage videos (HTTP version)
 * This prevents unauthorized video downloads
 */
exports.getSecureVideoUrl = onRequest(
  {
    cors: ["https://website-sombo.web.app", "https://website-sombo.firebaseapp.com", /localhost/],
  },
  async (req, res) => {
  try {
    // Only allow POST requests
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    // Verify Firebase ID token from Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      res.status(401).json({ error: "Unauthorized - No token provided" });
      return;
    }

    const idToken = authHeader.split("Bearer ")[1];
    let decodedToken;

    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      console.error("Token verification failed:", error);
      res.status(401).json({ error: "Unauthorized - Invalid token" });
      return;
    }

    const userId = decodedToken.uid;
    const { courseId, videoId, storagePath } = req.body;

    if (!courseId || !videoId || !storagePath) {
      throw new Error("Course ID, Video ID, and Storage Path are required.");
    }

    console.log(`🔐 Generating secure URL for user ${userId}, video ${videoId}`);

    // 1. Check if user is enrolled in the course
    const enrollmentQuery = await admin
      .firestore()
      .collection("enrollments")
      .where("userId", "==", userId)
      .where("courseId", "==", courseId)
      .where("status", "==", "approved")
      .limit(1)
      .get();

    if (enrollmentQuery.empty) {
      throw new Error("User is not enrolled in this course.");
    }

    const enrollment = enrollmentQuery.docs[0].data();

    // 2. Check if enrollment is still valid (not expired)
    if (enrollment.validUntil && enrollment.validUntil.toMillis() < Date.now()) {
      throw new Error("Your course enrollment has expired.");
    }

    // 3. Get course details to check if video is free or requires premium access
    const courseDoc = await admin
      .firestore()
      .collection("courses")
      .doc(courseId)
      .get();

    if (!courseDoc.exists) {
      throw new Error("Course not found.");
    }

    const courseData = courseDoc.data();

    // Find the video in course videos
    const video = courseData.videos?.find((v) => v.videoId === videoId);

    if (!video) {
      throw new Error("Video not found in course.");
    }

    // 4. If video is not free, check enrollment validity
    // Enrollment status is already checked above (must be "approved")
    // So if we reach here, the enrollment is valid

    // 5. Check concurrent sessions to prevent sharing (optional - disabled for now)
    // TODO: Create Firestore index for sessions collection to enable this
    // const activeSessions = await admin
    //   .firestore()
    //   .collection("users")
    //   .doc(userId)
    //   .collection("sessions")
    //   .where("isActive", "==", true)
    //   .where("lastActiveAt", ">", new Date(Date.now() - 4 * 60 * 60 * 1000))
    //   .get();

    // 6. Generate download URL from Firebase Storage
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);

    // Check if file exists
    const [exists] = await file.exists();
    if (!exists) {
      throw new Error("Video file not found in storage. Please contact support.");
    }

    // Get the public download URL with access token
    // This uses Firebase's built-in token system
    const [metadata] = await file.getMetadata();
    const token = metadata.metadata?.firebaseStorageDownloadTokens || metadata.metadata?.token;

    let signedUrl;
    if (token) {
      // Use token-based URL (works with storage rules)
      signedUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(storagePath)}?alt=media&token=${token}`;
    } else {
      // Fallback to basic URL (requires storage rules to allow authenticated access)
      signedUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(storagePath)}?alt=media`;
    }

    const expirationTime = Math.floor(Date.now() / 1000) + 15 * 60;

    // 7. Log video access for analytics and abuse detection
    await admin.firestore().collection("videoAccess").add({
      userId: userId,
      courseId: courseId,
      videoId: videoId,
      storagePath: storagePath,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ipAddress: req.ip || "unknown",
      userAgent: req.headers["user-agent"] || "unknown",
      expiresAt: new Date(expirationTime * 1000),
    });

    // 8. Generate access token for additional verification
    const accessToken = jwt.sign(
      {
        userId: userId,
        courseId: courseId,
        videoId: videoId,
        storagePath: storagePath,
        exp: expirationTime,
      },
      process.env.JWT_SECRET || "your-secret-key-change-this"
    );

    console.log(`✅ Secure URL generated for user ${userId}, video ${videoId}`);

    res.status(200).json({
      signedUrl: signedUrl,
      expiresAt: expirationTime,
      accessToken: accessToken,
      videoId: videoId,
    });
  } catch (error) {
    console.error("❌ Error generating secure video URL:", error);
    res.status(500).json({ error: `Failed to generate video URL: ${error.message}` });
  }
  }
);

/**
 * Get Bunny Stream playback URL with enrollment verification
 * Bunny Stream handles video security, DRM, and download protection
 * This function only verifies user enrollment before returning the playback URL
 */
exports.getBunnySecureUrl = onRequest(
  {
    cors: ["https://website-sombo.web.app", "https://website-sombo.firebaseapp.com", /localhost/],
  },
  async (req, res) => {
  try {
    // Only allow POST requests
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    // Verify Firebase ID token from Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      res.status(401).json({ error: "Unauthorized - No token provided" });
      return;
    }

    const idToken = authHeader.split("Bearer ")[1];
    let decodedToken;

    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      console.error("Token verification failed:", error);
      res.status(401).json({ error: "Unauthorized - Invalid token" });
      return;
    }

    const userId = decodedToken.uid;
    const { courseId, videoId, videoGuid } = req.body;

    if (!courseId || !videoId || !videoGuid) {
      throw new Error("Course ID, Video ID, and Video GUID are required.");
    }

    console.log(`🔐 Generating Bunny Stream URL for user ${userId}, video ${videoId}`);

    // 1. Check if user is enrolled in the course
    const enrollmentQuery = await admin
      .firestore()
      .collection("enrollments")
      .where("userId", "==", userId)
      .where("courseId", "==", courseId)
      .where("status", "==", "approved")
      .limit(1)
      .get();

    if (enrollmentQuery.empty) {
      throw new Error("User is not enrolled in this course.");
    }

    const enrollment = enrollmentQuery.docs[0].data();

    // 2. Check if enrollment is still valid (not expired)
    if (enrollment.validUntil && enrollment.validUntil.toMillis() < Date.now()) {
      throw new Error("Your course enrollment has expired.");
    }

    // 3. Get course details to verify video exists
    const courseDoc = await admin
      .firestore()
      .collection("courses")
      .doc(courseId)
      .get();

    if (!courseDoc.exists) {
      throw new Error("Course not found.");
    }

    const courseData = courseDoc.data();

    // Find the video in course videos
    const video = courseData.videos?.find((v) => v.videoId === videoId);

    if (!video) {
      throw new Error("Video not found in course.");
    }

    // 4. Generate Bunny Stream playback URL
    // Bunny Stream CDN hostname and video GUID
    const CDN_HOSTNAME = "vz-bba76149-c05.b-cdn.net";
    const playbackUrl = `https://${CDN_HOSTNAME}/${videoGuid}/playlist.m3u8`;

    // 5. Log video access for analytics
    await admin.firestore().collection("videoAccess").add({
      userId: userId,
      courseId: courseId,
      videoId: videoId,
      videoGuid: videoGuid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ipAddress: req.ip || "unknown",
      userAgent: req.headers["user-agent"] || "unknown",
      platform: "bunny-stream",
    });

    console.log(`✅ Bunny Stream URL generated for user ${userId}, video ${videoId}`);

    res.status(200).json({
      signedUrl: playbackUrl,
      videoGuid: videoGuid,
      message: "Bunny Stream handles DRM and download protection automatically",
    });
  } catch (error) {
    console.error("❌ Error generating Bunny Stream URL:", error);
    res.status(500).json({ error: `Failed to generate video URL: ${error.message}` });
  }
  }
);
