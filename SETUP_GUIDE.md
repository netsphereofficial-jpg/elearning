# E-Learning Platform Setup Guide

Complete setup instructions for your secure video streaming platform.

---

## 📋 Prerequisites

- Flutter 3.x installed
- Node.js 18+ (for Cloud Functions)
- Firebase CLI: `npm install -g firebase-tools`
- A Firebase project
- A Cloudflare account (for video streaming)

---

## 🚀 Step-by-Step Setup

### 1. Firebase Project Setup

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project"
3. Name it (e.g., "elearning-platform")
4. Disable Google Analytics (optional for dev)
5. Create project

#### Enable Firebase Services

**Authentication:**
1. Go to Authentication > Sign-in method
2. Enable "Email/Password"
3. Save

**Firestore Database:**
1. Go to Firestore Database
2. Click "Create database"
3. Start in **test mode** (change rules later)
4. Choose a location (nearest to your users)

**Cloud Functions:**
1. Upgrade to Blaze (Pay-as-you-go) plan
2. Go to Functions tab
3. Enable Cloud Functions API

#### Get Firebase Web Config
1. Go to Project Settings (gear icon)
2. Scroll to "Your apps"
3. Click Web icon (</>) to add web app
4. Register app with a nickname
5. Copy the config object

#### Update Your Code
Open `lib/main.dart` and replace the Firebase configuration:

```dart
await Firebase.initializeApp(
  options: const FirebaseOptions(
    apiKey: "AIzaSy...",              // From Firebase config
    authDomain: "your-app.firebaseapp.com",
    projectId: "your-project-id",
    storageBucket: "your-app.appspot.com",
    messagingSenderId: "123456789",
    appId: "1:123456789:web:abc123",
  ),
);
```

---

### 2. Cloudflare Stream Setup

#### Create Cloudflare Account
1. Sign up at [Cloudflare](https://www.cloudflare.com/)
2. Go to Stream from the dashboard
3. Note your **Account ID**

#### Get API Token
1. Go to "My Profile" > "API Tokens"
2. Create Token > "Edit Cloudflare Stream" template
3. Copy the token (you won't see it again!)

#### Update Configuration
1. Open `lib/config/firebase_config.dart`
2. Update:
```dart
static const String cloudflareAccountId = "your_account_id_here";
static const String cloudflareApiToken = "your_api_token_here";
```

3. Open `functions/index.js`
4. Update at the top:
```javascript
const CLOUDFLARE_ACCOUNT_ID = 'your_account_id';
const CLOUDFLARE_API_TOKEN = 'your_api_token';
```

---

### 3. Deploy Cloud Functions

#### Initialize Firebase in Project
```bash
# Login to Firebase
firebase login

# Initialize Firebase in your project
firebase init

# Select:
# - Functions (use arrow keys, space to select)
# - Use an existing project
# - JavaScript
# - No ESLint
# - Install dependencies: Yes
```

#### Set Environment Variables (Optional but recommended)
```bash
# Set Cloudflare credentials as environment variables
firebase functions:config:set \
  cloudflare.account_id="YOUR_ACCOUNT_ID" \
  cloudflare.api_token="YOUR_API_TOKEN" \
  jwt.secret="your-random-secret-key-here"
```

#### Deploy Functions
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

Wait for deployment to complete (5-10 minutes first time).

---

### 4. Firestore Security Rules

Update your Firestore rules for production:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;

      // Watch history subcollection
      match /watchHistory/{videoId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }

      // Sessions subcollection
      match /sessions/{sessionId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // Videos collection (read-only for users)
    match /videos/{videoId} {
      allow read: if request.auth != null;
      allow write: if false; // Only admins via Cloud Functions
    }

    // Video access logs (write-only)
    match /videoAccess/{accessId} {
      allow read: if false;
      allow write: if request.auth != null;
    }
  }
}
```

---

### 5. Run the Flutter App

#### Install Dependencies
```bash
flutter pub get
```

#### Run for Web
```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

**Note:** The `--disable-web-security` flag is for development only to avoid CORS issues.

#### Build for Production
```bash
flutter build web --release
```

Deploy the `build/web` folder to:
- Firebase Hosting: `firebase deploy --only hosting`
- Vercel
- Netlify
- Your own server

---

### 6. Upload Test Videos

#### Option 1: Via Cloudflare Dashboard
1. Go to Cloudflare Stream dashboard
2. Click "Upload Video"
3. Upload your video file
4. Copy the Video ID
5. Create a document in Firestore `videos` collection:

```json
{
  "title": "Introduction to Flutter",
  "description": "Learn Flutter basics",
  "cloudflareVideoId": "abc123def456",
  "thumbnailUrl": "https://customer-xxx.cloudflarestream.com/abc123/thumbnails/thumbnail.jpg",
  "durationInSeconds": 600,
  "category": "Programming",
  "isPremium": false,
  "uploadedAt": "2025-01-15T10:00:00Z",
  "viewCount": 0,
  "tags": ["flutter", "mobile", "beginners"]
}
```

#### Option 2: Via Cloud Function (for admins)
Create an admin user in Firestore:
```json
// In /users/{userId} document
{
  "email": "admin@example.com",
  "name": "Admin",
  "isAdmin": true,
  "isPremium": true
}
```

Then call the function from your app or use Firebase Functions shell.

---

### 7. Test the Application

#### Test Flow:
1. **Open the app** → Should show login screen
2. **Login** with any email (e.g., `test@test.com`) and password (min 6 chars)
3. **View video list** → Should show uploaded videos
4. **Click a video** → Should play with:
   - Watermark overlay (your email)
   - Right-click disabled
   - DevTools detection
5. **Progress tracking** → Refresh page, resume from last position

---

## 🔒 Security Features Implemented

### ✅ Video Protection
- **Signed URLs** with 4-hour expiry
- **JWT tokens** for access validation
- **HLS/DASH streaming** (Cloudflare handles this)
- **Domain restrictions** (configure in Cloudflare)

### ✅ Frontend Security
- **Watermark overlay** with user email + timestamp
- **Right-click disabled** on video player
- **Keyboard shortcuts blocked** (Ctrl+S, Ctrl+U, F12)
- **DevTools detection** pauses video
- **No native download controls**

### ✅ Backend Security
- **Firestore security rules** restrict access
- **Concurrent session limiting** (max 2 devices)
- **Abnormal playback detection** flags suspicious activity
- **Access logging** tracks all video views

### ✅ Session Management
- **Auto-cleanup** of expired sessions (every hour)
- **Device tracking** per user
- **Session invalidation** on new login

---

## 💰 Cost Estimation

### Firebase (Spark Plan - Free Tier)
- **Authentication:** 50K MAU free
- **Firestore:** 50K reads, 20K writes free per day
- **Cloud Functions:** 2M invocations free per month
- **Hosting:** 10 GB storage, 360 MB/day transfer

### Firebase (Blaze Plan - After Free Tier)
- **Functions:** $0.40 per million invocations
- **Firestore:** $0.06 per 100K reads
- **Hosting:** $0.026/GB storage, $0.15/GB transfer

### Cloudflare Stream
- **Storage:** $5 per 1,000 minutes stored
- **Delivery:** $1 per 1,000 minutes delivered
- **No bandwidth charges**

### Example: 1000 Students, 50 hours content
- **Storage:** 50 hours × 60 = 3,000 minutes = $15 one-time
- **Delivery:** 1000 students × 50 hours × 0.5 (avg watch rate) = 25,000 hours = 1,500,000 minutes = **$1,500/month**
- **Alternative:** Cache popular videos, use lower bitrates = **$500-800/month**

---

## 🎯 Next Steps

### Immediate
- [ ] Replace placeholder Firebase config
- [ ] Set up Cloudflare Stream
- [ ] Deploy Cloud Functions
- [ ] Upload test videos
- [ ] Test login and video playback

### Production-Ready
- [ ] Set proper Firestore security rules
- [ ] Enable Firebase App Check (bot protection)
- [ ] Set up Firebase Hosting
- [ ] Configure custom domain
- [ ] Enable Cloudflare Bot Management
- [ ] Add analytics (Firebase Analytics or Mixpanel)
- [ ] Implement payment system (Stripe) for premium content
- [ ] Add email verification for signups
- [ ] Create admin panel for video management

### Enhanced Security
- [ ] Implement forensic watermarking (invisible tracking)
- [ ] Add CAPTCHA on login
- [ ] Set up IP-based rate limiting
- [ ] Enable DRM (Widevine) in Cloudflare Stream
- [ ] Add screen recording detection
- [ ] Implement video quality restrictions for suspicious users

---

## 🐛 Troubleshooting

### "Firebase initialization error"
- Check if Firebase config values are correct
- Ensure Firebase project has web app registered

### "Could not generate video URL"
- Verify Cloud Functions are deployed
- Check Cloudflare credentials in functions/index.js
- Look at Cloud Functions logs: `firebase functions:log`

### "User not authenticated"
- Ensure Email/Password auth is enabled in Firebase
- Check if user document exists in Firestore

### Video not playing
- Check if Cloudflare video ID is correct
- Verify signed URL is generated
- Check browser console for CORS errors
- Test video URL directly in browser

### CORS errors
- For development: run with `--web-browser-flag "--disable-web-security"`
- For production: Configure CORS in Cloudflare Stream settings
- Add your domain to allowed origins

---

## 📚 Additional Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [Cloudflare Stream API](https://developers.cloudflare.com/stream/)
- [Flutter Video Player](https://pub.dev/packages/video_player)
- [Chewie Player](https://pub.dev/packages/chewie)
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)

---

## 🆘 Support

If you encounter issues:
1. Check Firebase Console > Functions > Logs
2. Check browser console (F12)
3. Verify all credentials are correct
4. Test with a simple video URL first
5. Ensure all Firebase services are enabled

---

## 📝 License & Security Note

This platform includes multiple layers of security to protect your video content. However, determined users can still find ways to record screen or bypass protections. Use this as a deterrent, not foolproof protection.

For Hollywood-level DRM, consider:
- Cloudflare Stream with Widevine DRM
- AWS MediaPackage with DRM
- BuyDRM or PallyCon services

**Cost for full DRM:** ~$200-500/month base + per-stream fees.
