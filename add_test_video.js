// Script to add test video to Firestore
// Run with: node add_test_video.js

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = {
  projectId: "website-sombo",
  // Note: In production, use a service account key file
};

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: "website-sombo",
});

const db = admin.firestore();

async function addTestVideo() {
  try {
    const videoData = {
      title: "Test Video - Introduction",
      description: "This is a test video for the e-learning platform",
      bunnyVideoGuid: "62d26a71-7b57-43c7-bdf2-8da954fc45c8",
      thumbnailUrl: "https://vz-d86440c8-58b.b-cdn.net/62d26a71-7b57-43c7-bdf2-8da954fc45c8/thumbnail.jpg",
      durationInSeconds: 300, // 5 minutes - update with actual duration
      category: "Programming",
      isPremium: false,
      uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
      viewCount: 0,
      tags: ["test", "demo", "introduction"],
      processingStatus: "completed",
    };

    const docRef = await db.collection("videos").add(videoData);
    console.log("✅ Video added successfully with ID:", docRef.id);
    console.log("📹 Video GUID:", videoData.bunnyVideoGuid);
    console.log("🔗 HLS URL: https://vz-d86440c8-58b.b-cdn.net/" + videoData.bunnyVideoGuid + "/playlist.m3u8");

    process.exit(0);
  } catch (error) {
    console.error("❌ Error adding video:", error);
    process.exit(1);
  }
}

addTestVideo();
