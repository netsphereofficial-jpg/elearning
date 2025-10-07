# Google Cloud Storage Video Streaming Setup Guide

Complete guide to set up video streaming using Google Cloud Storage + Cloud CDN.

---

## 💰 **Cost Summary**

For **10GB content + 1,000 students watching 3 hours each:**

| Service | Cost |
|---------|------|
| **Storage (GCS)** | $0.20/month |
| **Transcoding (one-time)** | $3.00 |
| **CDN Delivery** | $8-12/month |
| **Cloud Functions** | Free tier |
| **TOTAL** | **~$12-15/month** 🎉 |

**Cheapest option that still gives professional features!**

---

## 🚀 **Step-by-Step Setup**

### **Step 1: Enable Required APIs**

Go to [Google Cloud Console](https://console.cloud.google.com/):

```bash
# Or use gcloud CLI:
gcloud services enable storage.googleapis.com
gcloud services enable transcoder.googleapis.com
gcloud services enable compute.googleapis.com
```

Enable:
1. ✅ Cloud Storage API
2. ✅ Transcoder API
3. ✅ Cloud CDN API (automatic with Load Balancer)
4. ✅ Cloud Functions API (already enabled)

---

### **Step 2: Create GCS Bucket**

```bash
# Via gcloud CLI
gsutil mb -c STANDARD -l us-central1 gs://your-project-id-videos

# Set uniform bucket-level access
gsutil uniformbucketlevelaccess set on gs://your-project-id-videos

# Enable versioning (optional)
gsutil versioning set on gs://your-project-id-videos
```

Or via Console:
1. Go to **Cloud Storage** → **Buckets** → **Create**
2. Name: `your-project-id-videos`
3. Location: `us-central1` (or nearest to your users)
4. Storage class: `Standard`
5. Access control: `Uniform`
6. Create bucket

---

### **Step 3: Configure CORS for Web Access**

Create a file `cors.json`:
```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type", "Range"],
    "maxAgeSeconds": 3600
  }
]
```

Apply CORS:
```bash
gsutil cors set cors.json gs://your-project-id-videos
```

For production, replace `"*"` with your actual domains:
```json
"origin": ["https://yourdomain.com", "https://www.yourdomain.com"]
```

---

### **Step 4: Enable Cloud CDN**

#### Option A: Via Load Balancer (Recommended for production)

1. **Cloud Console** → **Network Services** → **Load Balancing**
2. Click **Create Load Balancer**
3. Select **HTTP(S) Load Balancing**
4. **Backend configuration:**
   - Backend type: **Cloud Storage bucket**
   - Select your bucket: `your-project-id-videos`
   - ✅ Enable **Cloud CDN**
   - Cache mode: **Cache static content**
   - TTL: 3600 seconds (1 hour)
5. **Frontend configuration:**
   - Protocol: HTTPS
   - IP: Create new (ephemeral or static)
6. Create

This gives you a URL like: `https://35.201.xxx.xxx` or custom domain

#### Option B: Direct bucket URL with CDN (Simpler for testing)

```bash
# Make bucket publicly readable (or use signed URLs)
gsutil iam ch allUsers:objectViewer gs://your-project-id-videos
```

Access via: `https://storage.googleapis.com/your-project-id-videos/path/to/video.m3u8`

---

### **Step 5: Update Cloud Functions**

#### Install GCS Dependencies

In your `functions/` directory:

```bash
cd functions

# Backup original package.json
cp package.json package-original.json

# Replace with GCS version
cp package-gcs.json package.json

# Install dependencies
npm install
```

#### Update Environment Variables

```bash
# Set bucket name
firebase functions:config:set gcs.bucket="your-project-id-videos"

# Set JWT secret
firebase functions:config:set jwt.secret="your-random-secret-key-here"
```

#### Replace Functions

1. **Backup** your current `index.js`:
   ```bash
   cp index.js index-cloudflare-backup.js
   ```

2. **Use GCS version:**
   ```bash
   cp gcs-video-service.js index.js
   ```

3. **Update bucket name** in `index.js`:
   ```javascript
   const BUCKET_NAME = 'your-project-id-videos'; // Line 9
   ```

#### Deploy

```bash
firebase deploy --only functions
```

Wait 5-10 minutes for deployment.

---

### **Step 6: Update Flutter App**

Update `lib/services/video_service.dart`:

```dart
// Change the function name
Future<String?> generateSignedVideoUrl(String userId, String videoId) async {
  try {
    final callable = _functions.httpsCallable('generateSignedVideoUrlGCS'); // Changed
    final result = await callable.call({
      'userId': userId,
      'videoId': videoId,
    });

    return result.data['signedUrl'];
  } catch (e) {
    print('Error generating signed URL: $e');
    return null;
  }
}
```

That's it! Everything else stays the same.

---

## 📹 **Uploading Videos**

### **Method 1: Manual Upload + Transcoding**

#### Step 1: Upload Original Video

```bash
# Upload via gsutil
gsutil cp my-video.mp4 gs://your-project-id-videos/uploads/my-video.mp4

# Or via Console: Cloud Storage → your bucket → Upload files
```

#### Step 2: Trigger Transcoding via Admin Function

In your Flutter app (create admin panel):

```dart
final callable = FirebaseFunctions.instance.httpsCallable('uploadVideoToGCS');
final result = await callable.call({
  'title': 'Introduction to Flutter',
  'description': 'Learn Flutter basics',
  'category': 'Programming',
  'sourceGcsUri': 'gs://your-project-id-videos/uploads/my-video.mp4',
});

print('Video ID: ${result.data['videoId']}');
print('Transcoding job: ${result.data['transcodingJobName']}');
```

#### Step 3: Monitor Transcoding Status

```dart
// Check status (call every 30 seconds)
final statusCallable = FirebaseFunctions.instance.httpsCallable('checkTranscodingStatus');
final status = await statusCallable.call({'videoId': 'video-id-here'});

print('Status: ${status.data['status']}');
print('Progress: ${status.data['progress']}%');
```

Transcoding takes:
- 5 minutes video → ~2-3 minutes to transcode
- 30 minutes video → ~10-15 minutes
- 2 hours video → ~30-60 minutes

---

### **Method 2: Direct Upload via Flutter (Advanced)**

Create an upload endpoint:

```dart
// In your Flutter app
import 'package:firebase_storage/firebase_storage.dart';

Future<void> uploadVideo(File videoFile, String title) async {
  final storage = FirebaseStorage.instance;
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final fileName = '$timestamp-${videoFile.path.split('/').last}';

  // Upload to GCS via Firebase Storage
  final ref = storage.ref().child('uploads/$fileName');
  final uploadTask = ref.putFile(videoFile);

  // Show progress
  uploadTask.snapshotEvents.listen((snapshot) {
    double progress = snapshot.bytesTransferred / snapshot.totalBytes;
    print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
  });

  await uploadTask;
  final gcsUri = 'gs://your-bucket/uploads/$fileName';

  // Trigger transcoding
  final callable = FirebaseFunctions.instance.httpsCallable('uploadVideoToGCS');
  await callable.call({
    'title': title,
    'description': 'Video description',
    'category': 'Programming',
    'sourceGcsUri': gcsUri,
  });
}
```

---

## 🔐 **Firestore Video Document Structure**

After transcoding completes:

```json
{
  "title": "Introduction to Flutter",
  "description": "Learn Flutter basics",
  "gcsVideoPath": "videos/abc123/master.m3u8",
  "thumbnailPath": "videos/abc123/thumbnail.jpg",
  "thumbnailUrl": "https://storage.googleapis.com/your-bucket/videos/abc123/thumbnail.jpg",
  "durationInSeconds": 1800,
  "category": "Programming",
  "isPremium": false,
  "uploadedAt": "2025-01-15T10:00:00Z",
  "viewCount": 0,
  "tags": ["flutter", "mobile"],
  "transcodingJobName": "projects/.../locations/.../jobs/...",
  "transcodingStatus": "COMPLETED"
}
```

---

## 📊 **Monitoring & Analytics**

### View Storage Usage:
```bash
gsutil du -sh gs://your-project-id-videos
```

### View CDN Cache Hit Rate:
1. **Cloud Console** → **Network Services** → **Load Balancing**
2. Select your load balancer
3. View **Cache hit rate** (aim for >80%)

### View Bandwidth Usage:
1. **Cloud Console** → **Billing** → **Reports**
2. Filter by:
   - Service: Cloud Storage
   - SKU: Download

---

## 🎯 **Video Quality Levels Generated**

The transcoding automatically creates:
- **1080p** (1920×1080) @ 5 Mbps
- **720p** (1280×720) @ 2.5 Mbps
- **480p** (854×480) @ 1 Mbps
- **Audio** AAC @ 128 kbps

Player automatically switches based on bandwidth!

---

## 🔧 **Optimization Tips**

### 1. Enable Compression
```bash
# Set compression on HLS files
gsutil setmeta -h "Content-Encoding:gzip" \
  gs://your-bucket/videos/*/*.m3u8
```

### 2. Set Cache Headers
```bash
# Cache video segments for 1 year (they're immutable)
gsutil setmeta -h "Cache-Control:public, max-age=31536000" \
  gs://your-bucket/videos/*/*.ts
```

### 3. Use Cloud CDN
- Reduces bandwidth costs by 60-80%
- Faster loading (edge caching)
- Already included in setup above

### 4. Compress Videos Before Upload
```bash
# Use ffmpeg to compress before upload
ffmpeg -i input.mp4 -c:v libx264 -crf 23 -preset medium \
  -c:a aac -b:a 128k output.mp4
```

---

## 💸 **Detailed Cost Breakdown**

### Scenario: 1,000 Students, 10GB Content (300 minutes)

#### Storage Costs:
```
10GB × $0.020/GB = $0.20/month
```

#### Transcoding Costs (One-Time):
```
300 minutes × $0.01/minute = $3.00
```

#### Delivery Costs:
```
Assuming 30% cache hit rate on CDN:

1,000 students × 300 minutes × 0.7 (not cached) = 210,000 minutes
210,000 minutes ÷ 60 = 3,500 hours
3,500 hours × 1.5 GB/hour avg = 5,250 GB

With Cloud CDN:
5,250 GB × $0.008/GB (CDN pricing) = $42/month

Without CDN (direct GCS):
5,250 GB × $0.12/GB = $630/month 😱

Cache hit rate 70% saves you ~$588/month!
```

#### Cloud Functions:
```
100,000 invocations/month = FREE (2M free tier)
```

#### **Total with CDN: $42-45/month**
#### **Total without CDN: $630/month**

**Always use Cloud CDN!** ✅

---

## 🆚 **Comparison: GCS vs Others**

| Feature | GCS + CDN | Cloudflare | Bunny.net |
|---------|-----------|------------|-----------|
| **Storage (10GB)** | $0.20/mo | $1.50 | $0.05/mo |
| **Delivery (1K users)** | $8-12/mo | $180/mo | $10/mo |
| **Transcoding** | $3 one-time | Included | Included |
| **CDN Locations** | 200+ | 300+ | 100+ |
| **Firebase Integration** | ✅ Native | ❌ None | ❌ None |
| **Setup Complexity** | Medium | Easy | Easy |
| **DRM Support** | ✅ Yes | ✅ Yes | ✅ Yes |
| **TOTAL/MONTH** | **$12-15** | **$180** | **$15** |

**Winner: GCS + CDN** for Firebase users! 🏆

---

## 🐛 **Troubleshooting**

### Issue: "Permission denied" when accessing video
**Solution:** Check CORS settings and signed URL expiration

### Issue: Video not transcoding
**Solution:**
```bash
# Check Transcoder API is enabled
gcloud services list --enabled | grep transcoder

# Check job status
gcloud transcoder jobs list --location=us-central1
```

### Issue: Slow video loading
**Solution:** Verify Cloud CDN is enabled on Load Balancer

### Issue: High bandwidth costs
**Solution:**
- Enable Cloud CDN
- Set proper cache headers
- Compress videos before upload

---

## ✅ **Production Checklist**

Before going live:

- [ ] Cloud CDN enabled on Load Balancer
- [ ] CORS configured for your domains
- [ ] Signed URLs implemented (not public URLs)
- [ ] Cache headers set on video files
- [ ] Monitoring alerts set up (billing, errors)
- [ ] Firestore security rules deployed
- [ ] Custom domain configured (optional)
- [ ] Test video playback on mobile + desktop
- [ ] Verify cache hit rate >70%

---

## 🚀 **Next Steps**

1. **Create GCS bucket** (5 minutes)
2. **Enable APIs** (2 minutes)
3. **Deploy updated Cloud Functions** (10 minutes)
4. **Upload test video** (5 minutes)
5. **Test playback** (5 minutes)

**Total setup time: ~30 minutes**

Ready to implement? Let me know if you need help with any step!
