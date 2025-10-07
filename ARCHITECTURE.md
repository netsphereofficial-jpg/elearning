# E-Learning Platform Architecture

## 🏗️ System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Flutter Web App                         │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────────┐ │
│  │ Login Screen│  │ Video List   │  │ Secure Video Player   │ │
│  │             │  │ Screen       │  │ - Watermark           │ │
│  │ - Auth Form │  │ - Grid View  │  │ - Security Overlay    │ │
│  │ - Validation│  │ - Search     │  │ - Progress Tracking   │ │
│  └─────────────┘  └──────────────┘  └───────────────────────┘ │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────────┐
│                     Service Layer (Flutter)                     │
│  ┌──────────────┐  ┌─────────────┐  ┌────────────────────────┐│
│  │ AuthService  │  │VideoService │  │  State Management      ││
│  │              │  │             │  │  (Provider)            ││
│  │ - Login      │  │ - Get Videos│  │                        ││
│  │ - Logout     │  │ - Track     │  │                        ││
│  │ - Sessions   │  │   Progress  │  │                        ││
│  └──────────────┘  └─────────────┘  └────────────────────────┘│
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────────┐
│                          Firebase                               │
│  ┌──────────────┐  ┌─────────────┐  ┌────────────────────────┐│
│  │ Firebase     │  │ Firestore   │  │  Cloud Functions       ││
│  │ Auth         │  │ Database    │  │                        ││
│  │              │  │             │  │  - generateSignedURL   ││
│  │ - Email/Pass │  │ - Users     │  │  - validateToken       ││
│  │ - Sessions   │  │ - Videos    │  │  - cleanupSessions     ││
│  │              │  │ - History   │  │  - detectAbnormal      ││
│  └──────────────┘  └─────────────┘  └────────────────────────┘│
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Cloudflare Stream                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Video Storage & CDN                                      │  │
│  │ - HLS/DASH Adaptive Streaming                            │  │
│  │ - Automatic Transcoding                                  │  │
│  │ - Global CDN (300+ locations)                            │  │
│  │ - Signed URLs                                            │  │
│  │ - Thumbnail Generation                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
elearning/
├── lib/
│   ├── config/
│   │   └── firebase_config.dart          # Firebase & Cloudflare credentials
│   ├── models/
│   │   ├── user_model.dart               # User data model
│   │   ├── video_model.dart              # Video data model
│   │   └── watch_session_model.dart      # Watch session model
│   ├── screens/
│   │   ├── login_screen.dart             # Login UI
│   │   ├── video_list_screen.dart        # Video grid/list
│   │   └── video_player_screen.dart      # Secure video player
│   ├── services/
│   │   ├── auth_service.dart             # Authentication logic
│   │   └── video_service.dart            # Video operations
│   ├── widgets/
│   │   ├── watermark_overlay.dart        # Dynamic watermark
│   │   └── security_overlay.dart         # Security features
│   └── main.dart                          # App entry point
├── functions/
│   ├── index.js                           # Cloud Functions code
│   └── package.json                       # Node.js dependencies
├── web/
│   └── index.html                         # Web entry point
├── pubspec.yaml                           # Flutter dependencies
├── SETUP_GUIDE.md                         # Setup instructions
└── ARCHITECTURE.md                        # This file
```

---

## 🔐 Security Architecture

### Layer 1: Authentication & Authorization
```
User Login
    ↓
Firebase Auth (JWT)
    ↓
Session Token Stored (Secure Storage)
    ↓
Token Validation on Each Request
```

### Layer 2: Video Access Control
```
User Requests Video
    ↓
Cloud Function Validates:
    - User authenticated?
    - User has access to video? (free/premium)
    - Concurrent sessions within limit?
    ↓
Generate Signed URL with JWT
    - Expires in 4 hours
    - Embedded with user ID + video ID
    ↓
Return to Client
```

### Layer 3: Streaming Security
```
Client Receives Signed URL
    ↓
Cloudflare Stream:
    - Verifies signature
    - Checks expiration
    - Serves encrypted HLS/DASH chunks
    - Each chunk is individually encrypted
    ↓
Player decrypts and plays
```

### Layer 4: Frontend Protection
```
Video Player Loads
    ↓
Security Overlay Active:
    - Right-click disabled
    - Keyboard shortcuts blocked
    - DevTools detection enabled
    - Watermark visible and moving
    ↓
User watches video
    ↓
Progress tracked every 10 seconds
```

---

## 📊 Data Flow

### Video Playback Flow
```
1. User clicks video in list
   ↓
2. App checks local cache for watch session
   ↓
3. Call Cloud Function: generateSignedVideoUrl
   ├─ Input: userId, videoId
   └─ Output: signedUrl, token, expiresAt
   ↓
4. Initialize video player with signed URL
   ↓
5. Resume from last position (if exists)
   ↓
6. Start progress tracking timer
   ↓
7. Every 10 seconds:
   ├─ Save current position to Firestore
   ├─ Update total watch time
   └─ Check if completed (>90%)
   ↓
8. On completion:
   ├─ Mark as completed in Firestore
   └─ Increment video view count
```

### Session Management Flow
```
User Logs In
   ↓
Generate Device ID
   ↓
Check Concurrent Sessions
   ├─ If < max allowed → Create new session
   └─ If >= max allowed → Show error or invalidate oldest
   ↓
Register Session in Firestore:
   - deviceId
   - lastActiveAt
   - isActive: true
   ↓
Periodic Cleanup (Cloud Function - every hour):
   - Find sessions inactive > 4 hours
   - Set isActive: false
```

---

## 🗄️ Database Schema

### Firestore Collections

#### `/users/{userId}`
```json
{
  "email": "string",
  "name": "string",
  "photoUrl": "string?",
  "isPremium": "boolean",
  "isAdmin": "boolean",
  "createdAt": "timestamp",
  "lastLoginAt": "timestamp",
  "maxConcurrentSessions": "number"
}
```

#### `/users/{userId}/watchHistory/{videoId}`
```json
{
  "userId": "string",
  "videoId": "string",
  "lastWatchedPosition": "number (seconds)",
  "lastWatchedAt": "timestamp",
  "totalWatchTime": "number (seconds)",
  "isCompleted": "boolean",
  "completedAt": "timestamp?",
  "deviceId": "string",
  "ipAddress": "string?"
}
```

#### `/users/{userId}/sessions/{sessionId}`
```json
{
  "deviceId": "string",
  "lastActiveAt": "timestamp",
  "isActive": "boolean"
}
```

#### `/videos/{videoId}`
```json
{
  "title": "string",
  "description": "string",
  "cloudflareVideoId": "string",
  "thumbnailUrl": "string",
  "durationInSeconds": "number",
  "category": "string",
  "isPremium": "boolean",
  "uploadedAt": "timestamp",
  "viewCount": "number",
  "tags": "array<string>"
}
```

#### `/videoAccess/{accessId}`
```json
{
  "userId": "string",
  "videoId": "string",
  "timestamp": "timestamp",
  "ipAddress": "string",
  "userAgent": "string"
}
```

#### `/suspiciousActivity/{activityId}`
```json
{
  "userId": "string",
  "videoId": "string",
  "type": "string (ABNORMAL_PLAYBACK_SPEED, etc.)",
  "details": "object",
  "timestamp": "timestamp"
}
```

---

## 🔧 Cloud Functions

### 1. `generateSignedVideoUrl`
- **Trigger:** HTTPS Callable
- **Purpose:** Generate time-limited signed URLs for video streaming
- **Input:** `{ userId, videoId }`
- **Output:** `{ signedUrl, expiresAt, token }`
- **Security Checks:**
  - User authenticated
  - User has access to video (free/premium)
  - Concurrent sessions within limit
  - Log access in Firestore

### 2. `validateVideoToken`
- **Trigger:** HTTPS Callable
- **Purpose:** Validate JWT tokens for video access
- **Input:** `{ token }`
- **Output:** `{ valid, userId, videoId }`

### 3. `cleanupExpiredSessions`
- **Trigger:** Scheduled (every hour)
- **Purpose:** Remove inactive sessions
- **Logic:** Set `isActive: false` for sessions inactive > 4 hours

### 4. `detectAbnormalPlayback`
- **Trigger:** Firestore onUpdate (`watchHistory`)
- **Purpose:** Detect video download attempts or speed hacking
- **Logic:** If position change > 2x real time, flag as suspicious

### 5. `uploadVideoToCloudflare` (Admin only)
- **Trigger:** HTTPS Callable
- **Purpose:** Upload videos to Cloudflare Stream from admin panel
- **Input:** `{ videoUrl, title, description, category }`
- **Output:** `{ success, videoId, cloudflareVideoId }`
- **Security:** Requires `isAdmin: true` in user document

---

## 🎯 Performance Optimizations

### 1. Adaptive Bitrate Streaming
- Cloudflare automatically generates multiple quality levels
- Player switches based on network conditions
- Smooth playback experience

### 2. CDN Edge Caching
- Videos cached at 300+ global locations
- Low latency for users worldwide
- Reduced origin requests

### 3. Lazy Loading
- Video list loads thumbnails first
- Full metadata fetched on demand
- Pagination for large video libraries

### 4. Progress Tracking Optimization
- Save every 10 seconds (not every second)
- Batch updates to reduce Firestore writes
- Local state management for smooth UI

### 5. Token Caching
- Signed URLs valid for 4 hours
- Cache in memory to avoid repeated Cloud Function calls
- Refresh only when expired

---

## 🚀 Scalability Considerations

### Current Architecture Supports:
- **1,000 concurrent users** on free tier
- **10,000+ concurrent users** on Blaze plan
- **Unlimited video storage** (pay per GB)
- **Global distribution** via Cloudflare CDN

### To Scale to 100K+ Users:
1. **Enable Firebase App Check** (bot protection)
2. **Add Redis caching** for frequently accessed data
3. **Implement video CDN caching** for popular content
4. **Use Cloud Run** for more complex backend logic
5. **Add load balancing** via Cloud Load Balancer
6. **Implement database sharding** for massive user base

### Cost at Scale:
- **10K users, 50 videos, 30 min avg watch/month:**
  - Cloudflare: $150-250/month
  - Firebase: $50-100/month
  - **Total: ~$200-350/month**

---

## 🔄 Future Enhancements

### Phase 1 (Current)
- ✅ Basic authentication
- ✅ Video listing and playback
- ✅ Watermark overlay
- ✅ Progress tracking
- ✅ Session management

### Phase 2 (Next)
- [ ] Payment integration (Stripe)
- [ ] Subscription management
- [ ] Admin panel for video uploads
- [ ] Advanced analytics dashboard
- [ ] Email notifications

### Phase 3 (Advanced)
- [ ] Full DRM implementation (Widevine)
- [ ] Forensic watermarking
- [ ] AI-powered content recommendations
- [ ] Live streaming support
- [ ] Interactive quizzes/assessments
- [ ] Mobile apps (iOS/Android)

---

## 📊 Monitoring & Analytics

### Recommended Tools:
1. **Firebase Analytics** - User behavior tracking
2. **Cloud Functions Logs** - Backend monitoring
3. **Cloudflare Analytics** - Video delivery metrics
4. **Sentry** - Error tracking
5. **Mixpanel** - Advanced user analytics

### Key Metrics to Track:
- Video completion rates
- Average watch time
- Concurrent sessions
- Bandwidth usage
- Sign-up conversion rate
- Premium conversion rate
- Suspicious activity incidents

---

## 🛡️ Security Best Practices

### Already Implemented:
- ✅ Firebase Auth with JWT
- ✅ Firestore security rules
- ✅ Signed URLs with expiration
- ✅ Token-based access control
- ✅ Session management
- ✅ Access logging
- ✅ Abnormal behavior detection

### Additional Recommendations:
- [ ] Enable Firebase App Check
- [ ] Add CAPTCHA on login (reCAPTCHA)
- [ ] Implement rate limiting (Cloud Armor)
- [ ] Enable 2FA for admin accounts
- [ ] Regular security audits
- [ ] Penetration testing
- [ ] GDPR compliance measures
- [ ] Data encryption at rest

---

## 📞 API Endpoints

### Firebase Cloud Functions

#### `POST /generateSignedVideoUrl`
```json
Request:
{
  "userId": "string",
  "videoId": "string"
}

Response:
{
  "signedUrl": "https://...",
  "expiresAt": 1234567890,
  "token": "eyJhbGc..."
}
```

#### `POST /validateVideoToken`
```json
Request:
{
  "token": "eyJhbGc..."
}

Response:
{
  "valid": true,
  "userId": "string",
  "videoId": "string"
}
```

---

## 🎓 Technology Stack Summary

### Frontend
- **Framework:** Flutter 3.x (Web)
- **State Management:** Provider
- **Video Player:** video_player + chewie
- **HTTP Client:** dio
- **Secure Storage:** flutter_secure_storage

### Backend
- **Authentication:** Firebase Auth
- **Database:** Cloud Firestore
- **Serverless Functions:** Firebase Cloud Functions (Node.js)
- **Video Streaming:** Cloudflare Stream

### DevOps
- **Hosting:** Firebase Hosting (or Vercel/Netlify)
- **CI/CD:** GitHub Actions (optional)
- **Monitoring:** Firebase Console + Cloudflare Dashboard

---

This architecture provides a solid foundation for a secure, scalable video streaming platform with room to grow as your user base expands.
