# 🔐 Google Sign-In Setup Guide

## ❌ Current Error
```
ClientID not set. Either set it on a <meta name="google-signin-client_id" content="CLIENT_ID" /> tag
```

This error means you need to configure Google Sign-In for your web app.

---

## ✅ Quick Fix (5 minutes)

### **Step 1: Get Your Google Client ID**

1. Go to **[Firebase Console](https://console.firebase.google.com/)**
2. Select your project
3. Click ⚙️ **Settings** → **Project settings**
4. Scroll down to **Your apps** section
5. Click on your **Web app** (or create one if you haven't)
6. You'll see something like:

```
Web API Key: AIzaSy...
```

7. Now go to **Authentication** → **Sign-in method**
8. Click **Google** provider
9. You'll see **Web SDK configuration**
10. Copy the **Web client ID** (looks like: `123456789-abc...apps.googleusercontent.com`)

### **Alternative: Get from Google Cloud Console**

1. Go to **[Google Cloud Console](https://console.cloud.google.com/)**
2. Select your Firebase project
3. Go to **APIs & Services** → **Credentials**
4. Under **OAuth 2.0 Client IDs**, find **Web client (auto created by Google Service)**
5. Click on it
6. Copy the **Client ID**

---

### **Step 2: Add Client ID to Your App**

Open `web/index.html` and **replace** the placeholder:

```html
<!-- BEFORE (current): -->
<meta name="google-signin-client_id" content="YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com">

<!-- AFTER (with your actual ID): -->
<meta name="google-signin-client_id" content="123456789-abc...apps.googleusercontent.com">
```

**Example:**
```html
<meta name="google-signin-client_id" content="123456789012-abcdefghijklmnop.apps.googleusercontent.com">
```

---

### **Step 3: Rebuild and Run**

```bash
# Stop the current app (Ctrl+C in terminal)

# Restart
flutter run -d chrome
```

---

## 🔍 Verify Setup

After completing above steps, when you run the app:

1. ✅ No "ClientID not set" error
2. ✅ App loads with "Sign in with Google" button
3. ✅ Clicking button opens Google OAuth popup
4. ✅ After sign-in, redirects to main app with tabs

---

## 🐛 Still Having Issues?

### **Issue: "redirect_uri_mismatch" Error**

**Solution:**
1. Go to **Google Cloud Console** → **Credentials**
2. Click your **Web client** OAuth 2.0 Client ID
3. Under **Authorized JavaScript origins**, add:
   ```
   http://localhost
   ```
4. Under **Authorized redirect URIs**, add:
   ```
   http://localhost
   ```
5. Click **Save**
6. Wait 5 minutes for changes to propagate
7. Try again

### **Issue: "Access Blocked" Error**

**Solution:**
1. Firebase Console → Authentication → Sign-in method
2. Make sure **Google** is **enabled** (toggle should be green)
3. Click Google → Check **Web SDK configuration**
4. Make sure **Web Client ID** and **Web Client Secret** are filled

### **Issue: Still Getting "ClientID not set"**

**Solution:**
1. Double-check you edited `web/index.html` (NOT `build/web/index.html`)
2. Make sure there are NO quotes around the Client ID
3. Stop the app completely (Ctrl+C)
4. Run: `flutter clean`
5. Run: `flutter pub get`
6. Run: `flutter run -d chrome`

---

## 📋 Complete Checklist

- [ ] Got Client ID from Firebase/Google Cloud Console
- [ ] Pasted Client ID in `web/index.html`
- [ ] No extra quotes or spaces
- [ ] Stopped and restarted the app
- [ ] Google Sign-In button appears
- [ ] Clicking button opens Google popup
- [ ] Can successfully sign in

---

## 🎯 What Happens Next?

After successful Google Sign-In:
1. User info saved to Firestore `users` collection
2. Redirected to Main App with 6 tabs
3. Can browse courses
4. Can enroll and watch videos

---

## 📞 Need Help?

If you're still stuck:
1. Check the browser **Console** (F12) for detailed errors
2. Make sure Firebase project has **web app** configured
3. Verify Google Sign-In is **enabled** in Authentication
4. Try in **incognito mode** to rule out cache issues

---

**Generated for E-Learning Platform**
