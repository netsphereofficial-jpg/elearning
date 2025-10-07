# 🎓 E-Learning Video Streaming Platform

A secure, scalable video streaming platform built with Flutter Web, Firebase, and Cloudflare Stream (or Google Cloud Storage).

## ✨ Features

### 🔐 Security Features
- **Multi-layer DRM protection** with signed URLs and JWT tokens
- **Dynamic watermark overlay** with user email and timestamp
- **DevTools detection** - pauses video when browser DevTools open
- **Right-click prevention** and keyboard shortcut blocking
- **Session management** - limit concurrent devices (max 2)
- **Abnormal playback detection** - flags suspicious video access patterns
- **Progress tracking** - resume from last watched position

### 🎬 Video Platform Features
- **Adaptive bitrate streaming** (HLS/DASH)
- **Global CDN delivery** via Cloudflare or Google Cloud CDN
- **Premium content access control**
- **Video progress tracking** and completion tracking
- **Responsive video grid** layout
- **Search and categorization** (ready for implementation)

### 🛡️ Backend Security
- **Firebase Authentication** with email/password
- **Firestore security rules** for data protection
- **Cloud Functions** for serverless backend logic
- **Access logging** for audit trails
- **Automatic session cleanup** (runs hourly)

---

## 🏗️ Tech Stack

### Frontend
- **Flutter 3.x** (Web)
- **Provider** for state management
- **Chewie** video player with custom controls
- **Firebase SDK** for authentication and data

### Backend
- **Firebase Authentication** - User management
- **Cloud Firestore** - NoSQL database
- **Firebase Cloud Functions** - Serverless API (Node.js)
- **Cloudflare Stream** or **Google Cloud Storage** - Video hosting

### Security
- **JWT tokens** for API security
- **Signed URLs** with 4-hour expiration
- **CORS configuration** for web access control
- **Rate limiting** via Cloud Functions

---

## 💰 Cost Estimate

For **1,000 students** watching **10GB content** (~300 minutes):

| Service | Monthly Cost |
|---------|--------------|
| **Firebase** (Auth + Firestore + Functions) | $0-5 (free tier) |
| **Cloudflare Stream** | $180-300 |
| **Google Cloud Storage + CDN** | $12-45 ⭐ Cheapest |
| **Bunny.net** | $15-30 |

**Recommended:** Google Cloud Storage with Cloud CDN for best price/performance ratio.

---

## 🚀 Quick Start

### Prerequisites
- Flutter 3.x installed
- Firebase account
- Node.js 18+ (for Cloud Functions)
- Cloudflare Stream or GCS account

### 1. Clone Repository
```bash
git clone https://github.com/netsphereofficial-jpg/elearning.git
cd elearning
```

### 2. Install Dependencies
```bash
flutter pub get
cd functions && npm install && cd ..
```

### 3. Configure Firebase
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

### 4. Deploy Backend
```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Cloud Functions
firebase deploy --only functions
```

### 5. Run the App
```bash
flutter run -d chrome
```

---

## 📁 Project Structure

```
elearning/
├── lib/
│   ├── config/              # Configuration files
│   ├── models/              # Data models
│   ├── screens/             # UI screens
│   ├── services/            # Business logic
│   ├── widgets/             # Reusable widgets
│   └── main.dart            # Entry point
├── functions/               # Cloud Functions
├── SETUP_GUIDE.md          # Setup instructions
├── GCS_SETUP_GUIDE.md      # GCS setup guide
└── ARCHITECTURE.md          # Architecture docs
```

---

## 📚 Documentation

- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Complete setup instructions
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture
- **[GCS_SETUP_GUIDE.md](GCS_SETUP_GUIDE.md)** - Google Cloud Storage setup

---

## 🔐 Security Layers

1. **Authentication** - Firebase Auth with JWT
2. **Access Control** - Premium content checks
3. **Streaming Security** - Encrypted HLS/DASH
4. **Frontend Protection** - Watermark, right-click blocking
5. **Monitoring** - Access logs and anomaly detection

---

## 🐛 Troubleshooting

See **[SETUP_GUIDE.md](SETUP_GUIDE.md)** for detailed troubleshooting.

---

## 📝 License

This project is private and proprietary.

---

**Built with ❤️ using Flutter & Firebase**
