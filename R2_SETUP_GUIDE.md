# Cloudflare R2 Setup Guide

This guide will help you configure Cloudflare R2 for video storage in your e-learning platform.

## Overview

The application has been migrated from Bunny.net to **Cloudflare R2 Object Storage** for video hosting. R2 provides:
- Zero egress fees (no bandwidth charges)
- S3-compatible API
- Direct presigned URL uploads
- Cost-effective storage at $0.015/GB/month

## Prerequisites

1. A Cloudflare account (free tier available)
2. Access to Cloudflare R2 dashboard
3. Firebase Functions environment configured

## Step 1: Create R2 Bucket

1. Log in to your [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **R2** in the sidebar
3. Click **Create Bucket**
4. Name your bucket: `nikhil-bucket` (or your preferred name)
5. Choose a location close to your users (optional)
6. Click **Create Bucket**

## Step 2: Generate R2 API Credentials

1. In the R2 dashboard, click **Manage R2 API Tokens**
2. Click **Create API Token**
3. Configure the token:
   - **Token Name**: `elearning-app-token`
   - **Permissions**:
     - Object Read & Write
     - Bucket Read
   - **TTL**: No expiry (or set as needed)
   - **Bucket Scope**: Select `nikhil-bucket` (or your bucket name)
4. Click **Create API Token**
5. **IMPORTANT**: Copy and save these credentials immediately:
   - Access Key ID
   - Secret Access Key
   - Account ID (found in R2 overview page)

## Step 3: Configure Firebase Functions Environment Variables

Set the R2 credentials as environment variables for Firebase Functions:

```bash
cd functions

# Set R2 configuration
firebase functions:config:set \
  r2.account_id="YOUR_R2_ACCOUNT_ID" \
  r2.access_key_id="YOUR_R2_ACCESS_KEY_ID" \
  r2.secret_access_key="YOUR_R2_SECRET_ACCESS_KEY" \
  r2.bucket_name="nikhil-bucket"

# Optional: Set custom R2 public domain (if configured)
firebase functions:config:set r2.public_domain="YOUR_CUSTOM_DOMAIN"
```

**Example:**
```bash
firebase functions:config:set \
  r2.account_id="abc123def456" \
  r2.access_key_id="1a2b3c4d5e6f7g8h" \
  r2.secret_access_key="your-secret-key-here" \
  r2.bucket_name="nikhil-bucket"
```

## Step 4: Verify Configuration

Check that environment variables are set correctly:

```bash
firebase functions:config:get
```

You should see output like:
```json
{
  "r2": {
    "account_id": "abc123def456",
    "access_key_id": "1a2b3c4d5e6f7g8h",
    "secret_access_key": "your-secret-key-here",
    "bucket_name": "nikhil-bucket"
  }
}
```

## Step 5: Deploy Firebase Functions

Deploy the updated Cloud Functions with R2 support:

```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific functions
firebase deploy --only functions:createR2VideoForUpload,functions:generateSignedVideoUrl,functions:checkR2VideoStatus
```

## Step 6: Update Existing Videos (Optional)

If you have existing videos in Bunny.net that you want to migrate:

1. **Download videos** from Bunny.net
2. **Upload to R2** using the admin panel
3. **Update Firestore documents** to include the new `r2VideoKey` field

Alternatively, you can create a migration script to bulk transfer videos.

## Step 7: Test Video Upload

1. Log in as an admin user
2. Navigate to **Admin Panel** > **Courses**
3. Create or edit a course
4. Click **Add Video**
5. Fill in video details
6. Click **Choose Video File**
7. Select a video file
8. Monitor upload progress
9. Verify the `R2 Video Key` is auto-filled

## Step 8: Test Video Playback

1. Log in as a student user
2. Enroll in a course with videos
3. Click on a video to play
4. Verify the video loads and plays correctly

## Environment Variable Reference

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `R2_ACCOUNT_ID` | Your Cloudflare account ID | Yes | `abc123def456` |
| `R2_ACCESS_KEY_ID` | R2 API access key | Yes | `1a2b3c4d5e6f7g8h` |
| `R2_SECRET_ACCESS_KEY` | R2 API secret key | Yes | `your-secret-key` |
| `R2_BUCKET_NAME` | Name of your R2 bucket | Yes | `nikhil-bucket` |
| `R2_PUBLIC_DOMAIN` | Custom domain (optional) | No | `videos.example.com` |

## Cloud Functions Reference

### New R2-Compatible Functions

1. **`createR2VideoForUpload`** - Creates video entry and returns presigned upload URL
2. **`generateSignedVideoUrl`** - Generates signed URL for video playback (4-hour expiry)
3. **`checkR2VideoStatus`** - Checks if video exists in R2
4. **`confirmR2VideoUpload`** - Confirms successful video upload
5. **`getUploadUrl`** - Generates presigned URL for direct file upload

### Removed Bunny.net Functions

The following functions are no longer used:
- `createBunnyVideoForUpload` → Replaced by `createR2VideoForUpload`
- `transferVideoToBunny` → No longer needed (direct R2 upload)
- `checkBunnyVideoStatus` → Replaced by `checkR2VideoStatus`

## Data Model Changes

### Before (Bunny.net)
```dart
CourseVideo {
  bunnyVideoGuid: "62d26a71-7b57-43c7-bdf2-8da954fc45c8"
  thumbnailUrl: "https://vz-d86440c8-58b.b-cdn.net/guid/thumbnail.jpg"
}
```

### After (R2)
```dart
CourseVideo {
  bunnyVideoGuid: "videos/1234567890-abc123-video.mp4"  // Now stores R2 key
  thumbnailUrl: ""  // Optional, can be added later
}
```

**Note**: The `bunnyVideoGuid` field now stores the R2 video key for backward compatibility.

## Cost Comparison

### Bunny.net (Previous)
- Storage: $0.005/GB/month
- Bandwidth: $0.01-0.05/GB
- **Estimated cost for 100GB + 1TB traffic**: ~$10-50/month

### Cloudflare R2 (Current)
- Storage: $0.015/GB/month
- Egress: **FREE** (no bandwidth charges)
- **Estimated cost for 100GB + 1TB traffic**: ~$1.50/month

**Savings: 70-97% reduction in costs!**

## Troubleshooting

### Error: "R2_ACCOUNT_ID is not defined"
**Solution**: Ensure environment variables are set correctly using `firebase functions:config:set`

### Error: "Failed to create video entry in R2"
**Solution**:
1. Verify R2 API credentials are correct
2. Check bucket name matches configuration
3. Ensure API token has proper permissions

### Error: "Video not found in R2 storage"
**Solution**:
1. Confirm video was successfully uploaded
2. Check R2 dashboard to verify file exists
3. Verify `r2VideoKey` is correctly stored in Firestore

### Video Upload Fails
**Solution**:
1. Check file size (R2 supports large files)
2. Verify presigned URL hasn't expired (1-hour validity)
3. Check browser console for detailed error messages

### Video Won't Play
**Solution**:
1. Verify signed URL is being generated correctly
2. Check that user has proper permissions
3. Ensure `generateSignedVideoUrl` function is deployed
4. Verify R2 bucket is accessible

## Custom Domain Setup (Optional)

To use a custom domain for R2:

1. In Cloudflare dashboard, go to **R2** > **Settings**
2. Click **Connect Domain**
3. Enter your custom domain (e.g., `videos.example.com`)
4. Update DNS records as instructed
5. Set the environment variable:
   ```bash
   firebase functions:config:set r2.public_domain="videos.example.com"
   ```

## Security Best Practices

1. **Never commit credentials** to version control
2. **Use environment variables** for all sensitive data
3. **Rotate API tokens** regularly
4. **Set bucket permissions** to private (presigned URLs only)
5. **Enable CORS** on R2 bucket if needed for direct browser uploads
6. **Monitor usage** in Cloudflare dashboard
7. **Set up alerts** for unusual activity

## Support

If you encounter issues:
1. Check Cloudflare R2 [documentation](https://developers.cloudflare.com/r2/)
2. Review Firebase Functions [logs](https://console.firebase.google.com/)
3. Verify all environment variables are set correctly
4. Test with a small video file first

---

**Migration completed successfully!** 🎉

Your e-learning platform now uses Cloudflare R2 for cost-effective, scalable video storage.
