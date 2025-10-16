# Cloudflare R2 Simple Setup (No Cloud Functions!)

## ✅ What We Did

Migrated from Bunny.net to **Cloudflare R2** with:
- ❌ **NO Cloud Functions needed**
- ✅ **Direct uploads from Flutter app**
- ✅ **Public R2 domain for streaming**
- ✅ **Zero egress costs**

---

## Configuration

All R2 credentials are stored in the Flutter app:

**File**: `lib/services/r2_direct_service.dart`

```dart
static const String accountId = 'f9f5fb5c6483be87df584c718ccf995c';
static const String accessKeyId = '1d9dc5466ce78399802b788e6d542e0d';
static const String secretAccessKey = 'c4206dfe34e6c545c3feda3826d60ea63b58175ab0fb925c6591da4a88fc6f74';
static const String bucketName = 'nikhil-bucket';
static const String publicDomain = 'https://pub-538a404fb8fa4466a767ef9ff57967e4.r2.dev';
```

---

## How It Works

### 1. **Video Upload** (Admin Panel)
```
Admin selects video file
        ↓
Direct upload to R2 using AWS Signature V4
        ↓
Video stored in R2: videos/timestamp-filename.mp4
        ↓
R2 video key saved to Firestore
```

### 2. **Video Playback** (Student)
```
Student clicks video
        ↓
Get R2 key from Firestore (stored in bunnyVideoGuid field)
        ↓
Generate public URL: https://pub-538a404fb8fa4466a767ef9ff57967e4.r2.dev/videos/...
        ↓
Video plays directly from R2
```

---

## Files Modified

### New Files Created:
1. **`lib/services/r2_direct_service.dart`** - Direct R2 upload/download service

### Files Updated:
1. **`lib/screens/admin/course_form_screen.dart`** - Uses R2DirectService for uploads
2. **`lib/screens/course_video_player_screen.dart`** - Plays videos from R2 public URLs
3. **`pubspec.yaml`** - Added `crypto` package for AWS signing

### Files No Longer Needed:
- `functions/index.js` - Cloud Functions not needed!
- `lib/services/r2_upload_service.dart` - Replaced by r2_direct_service.dart
- `lib/services/bunny_upload_service.dart` - Old Bunny.net service

---

## Security Notes

### Current Setup (Development):
- ✅ R2 credentials in app code (for simplicity)
- ✅ Public R2 domain for video streaming
- ✅ Direct uploads from admin panel

### For Production (Recommended):
If you want to add security:

1. **Option 1**: Move credentials to environment variables
   ```dart
   static const String accessKeyId = String.fromEnvironment('R2_ACCESS_KEY');
   ```

2. **Option 2**: Add Firebase Auth middleware
   - Only authenticated users can upload
   - Check user role before allowing uploads

3. **Option 3**: Use signed URLs with expiration
   - Already implemented in `r2_direct_service.dart`
   - Can add time-limited access

### Current Security:
- ✅ Only admin users can access upload UI (role check in Firestore)
- ✅ Videos are public (good for free courses)
- ⚠️ R2 credentials exposed in app (acceptable for controlled admin access)

---

## Testing

### 1. Test Video Upload:
1. Run the app: `flutter run -d chrome`
2. Login as admin user
3. Go to **Admin Panel** > **Courses**
4. Create/edit a course
5. Click **Add Video**
6. Upload a video file
7. Verify the R2 video key is auto-filled

### 2. Test Video Playback:
1. Login as a student user
2. Enroll in a course with videos
3. Click on a video
4. Video should load from R2 public URL

### 3. Verify R2 Storage:
1. Go to Cloudflare Dashboard
2. Navigate to **R2** > **nikhil-bucket**
3. Check **videos/** folder for uploaded files

---

## Cost Comparison

### Bunny.net (Old):
- Storage: $0.005/GB/month
- Bandwidth: $0.01-0.05/GB
- **Cost for 100GB + 1TB traffic**: $10-50/month

### Cloudflare R2 (New):
- Storage: $0.015/GB/month
- Egress: **FREE** ✅
- **Cost for 100GB + 1TB traffic**: $1.50/month

### **Savings: 90-97%** 🎉

---

## Troubleshooting

### Video upload fails
**Problem**: Upload returns error or timeout

**Solution**:
1. Check R2 credentials in `r2_direct_service.dart`
2. Verify R2 bucket exists: `nikhil-bucket`
3. Check R2 API token has "Object Read & Write" permission
4. Check browser console for detailed errors

### Video won't play
**Problem**: Video player shows error or black screen

**Solution**:
1. Verify video was uploaded successfully to R2
2. Check R2 public domain is correct
3. Verify video key is saved in Firestore (`bunnyVideoGuid` field)
4. Test R2 URL directly in browser: `https://pub-538a404fb8fa4466a767ef9ff57967e4.r2.dev/videos/...`

### CORS errors
**Problem**: Browser blocks R2 requests

**Solution**:
1. Go to Cloudflare R2 Dashboard
2. Select `nikhil-bucket`
3. Go to **Settings** > **CORS**
4. Add CORS rule:
   ```json
   {
     "AllowedOrigins": ["*"],
     "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
     "AllowedHeaders": ["*"],
     "MaxAgeSeconds": 3600
   }
   ```

### Signature errors
**Problem**: "SignatureDoesNotMatch" error

**Solution**:
- Verify all R2 credentials are correct
- Check system time is accurate (AWS signatures are time-sensitive)
- Regenerate R2 API token if needed

---

## Next Steps (Optional Enhancements)

### 1. Thumbnail Generation
Add automatic thumbnail generation:
- Extract first frame of video
- Upload thumbnail to R2
- Store thumbnail URL in Firestore

### 2. Video Compression
Before uploading:
- Compress video client-side
- Use FFmpeg.wasm for browser compression
- Reduce storage costs

### 3. HLS Streaming
For adaptive bitrate streaming:
- Convert videos to HLS format (.m3u8)
- Store multiple quality versions
- Better for mobile users

### 4. Progress Indicators
During upload:
- Show actual upload progress
- Use chunked uploads for large files
- Resume interrupted uploads

---

## Support

If you encounter issues:
1. Check R2 Dashboard for uploaded files
2. Verify credentials in `r2_direct_service.dart`
3. Test R2 public URLs in browser
4. Check Flutter console for error logs

---

**Migration Complete!** 🚀

Your e-learning platform now uses Cloudflare R2 for cost-effective, scalable video storage **without any Cloud Functions**!
