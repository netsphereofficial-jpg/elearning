# 🔐 Admin Panel - Complete Guide

## ✅ What's Been Built

Your e-learning platform now has a **complete admin panel** with:

### Features Implemented:
1. ✅ **Admin Authentication** - Email/password login for 3 admin accounts
2. ✅ **Course Management (CRUD)** - Create, edit, delete courses and videos
3. ✅ **Payment Approval System** - Approve/reject user payments
4. ✅ **User Management** - View, block/unblock users
5. ✅ **Course Validity** - Courses expire after specified days
6. ✅ **Dashboard with Stats** - Overview of users, courses, payments, revenue

---

## 🚀 Quick Start

### Step 1: Create Admin Accounts

You need to manually create 3 admin accounts in Firebase Console:

1. Go to **Firebase Console → Authentication → Users**
2. Click **"Add User"** button
3. Create these 3 accounts:

```
Admin 1:
Email: admin1@elearning.com
Password: Admin@123

Admin 2:
Email: admin2@elearning.com
Password: Admin@123

Admin 3:
Email: admin3@elearning.com
Password: Admin@123
```

4. After creating the auth accounts, update Firestore:
   - Go to **Firestore Database → users collection**
   - Find each admin user document (by their UID)
   - Add/Update these fields:
     - `role`: `"admin"` (string)
     - `isBlocked`: `false` (boolean)

### Step 2: Access Admin Panel

**Web URL:** `http://localhost:PORT/#/admin` or create a dedicated route

For now, access via the admin login screen directly.

### Step 3: Test Admin Login

Run the app and navigate to the admin login screen:
```bash
flutter run -d chrome
```

Login with any admin account:
- Email: `admin1@elearning.com`
- Password: `Admin@123`

---

## 📊 Admin Panel Features

### 1. Dashboard Overview

**Location:** First screen after login

**What you see:**
- Total Users count
- Total Courses (published/total)
- Pending Payments count
- Total Revenue (₹)

**Actions:**
- Refresh button to reload stats
- Navigate to other sections via sidebar

---

### 2. Course Management

**Location:** Courses tab in sidebar

#### View All Courses
- Table view with: Title, Price, Videos count, Validity days, Status
- Filter: "Published Only" toggle
- Refresh button

#### Create New Course
1. Click **"+ New Course"** floating button
2. Fill in the form:
   - **Title**: Course name
   - **Description**: Course description
   - **Thumbnail URL**: Image URL (use Unsplash, etc.)
   - **Price**: Amount in ₹
   - **Validity Days**: How long course is valid after enrollment (default: 30)
   - **Published**: Toggle to publish/unpublish
3. Add Videos:
   - Click **"Add Video"** button
   - Fill in video details:
     - **Video Title**: Video name
     - **Description**: Video description
     - **Bunny Video GUID**: Your Bunny.net video ID (example: `62d26a71-7b57-43c7-bdf2-8da954fc45c8`)
     - **Thumbnail URL**: Video thumbnail
     - **Duration**: Length in seconds
     - **Order**: Display order (1, 2, 3...)
     - **Free Preview**: Toggle if this video should be free
4. Click **"Save"**

#### Edit Existing Course
1. Click **edit icon** (pencil) on any course
2. Modify fields as needed
3. Add/Edit/Delete videos
4. Click **"Save"**

#### Delete Course
1. Click **delete icon** (trash) on any course
2. Confirm deletion
3. Course will be unpublished (soft delete)

#### Publish/Unpublish
1. Click **publish/unpublish icon** on any course
2. Toggles the published status

---

### 3. Payment Approval

**Location:** Payments tab in sidebar

#### Three Tabs:
1. **Pending** - Payments awaiting approval
2. **Approved** - Approved payments
3. **Rejected** - Rejected payments

#### Approve Payment
1. Go to **Pending** tab
2. Click on any payment to expand details
3. Review:
   - User email
   - Course title
   - Amount
   - Transaction ID
4. Click **"Approve"** button
5. Confirm approval

**What happens:**
- Payment status changes to `approved`
- User gets access to the course
- `validUntil` date is set (current date + course validity days)
- Admin ID and approval timestamp recorded

#### Reject Payment
1. Go to **Pending** tab
2. Click on any payment to expand details
3. Click **"Reject"** button
4. Enter rejection reason (required)
5. Confirm rejection

**What happens:**
- Payment status changes to `rejected`
- User does NOT get access
- Rejection reason stored
- Admin ID and timestamp recorded

#### View Payment History
- **Approved tab**: See all approved payments with validity dates
- **Rejected tab**: See all rejected payments with reasons

---

### 4. User Management

**Location:** Users tab in sidebar

#### View All Users
- List of all users with:
  - Avatar/Name
  - Email
  - Role badge (USER/ADMIN)
  - Status (ACTIVE/BLOCKED)

#### View User Details
1. Click **menu icon** (3 dots) on any user
2. Click **"View Details"**
3. See:
   - User info
   - Role
   - Status
   - Enrollments list

#### Block/Unblock User
1. Click **menu icon** on any user
2. Click **"Block"** or **"Unblock"**
3. Confirm action

**What happens:**
- User's `isBlocked` field updated
- Blocked users cannot log in
- Existing sessions invalidated on next check

---

## 🎯 User Flow (Student Side)

### Before Admin Panel:
1. User enrolls in course
2. Payment auto-approved ✅
3. Immediate access

### After Admin Panel (Current):
1. User enrolls in course
2. Payment goes to **PENDING** ⏳
3. User sees: *"Payment submitted for approval"*
4. **Admin approves** payment ✅
5. User gets access
6. Access expires after `validityDays`

---

## 📝 Course Validity System

### How It Works:

1. **Course Creation:**
   - Admin sets `validityDays` (e.g., 30 days)

2. **Payment Approval:**
   - Admin approves payment
   - System calculates: `validUntil = now + validityDays`
   - Example: Approved on Jan 1 → Valid until Jan 31

3. **Access Control:**
   - User tries to watch video
   - System checks: `isUserEnrolled(userId, courseId)`
   - Checks:
     - ✅ Enrollment status = `approved`
     - ✅ Current date < `validUntil`
   - If expired: Access denied

4. **Expiry Warning:**
   - `isExpiringSoon` flag shows if < 3 days remaining
   - Can show warning to user

---

## 🔒 Security & Permissions

### Role-Based Access:

```dart
User Roles:
- user (default)
- admin

Access Control:
- Only admins can access admin panel
- Only admins can approve payments
- Only admins can manage courses
- Only admins can block users
```

### Firebase Security Rules (Recommended):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to check admin
    function isAdmin() {
      return request.auth != null &&
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Courses - read public, write admins only
    match /courses/{courseId} {
      allow read: if true;
      allow write: if isAdmin();
    }

    // Enrollments - read own, create own, update admins only
    match /enrollments/{enrollmentId} {
      allow read: if request.auth.uid == resource.data.userId || isAdmin();
      allow create: if request.auth.uid == request.resource.data.userId;
      allow update: if isAdmin();
    }

    // Users - read own, write admins only
    match /users/{userId} {
      allow read: if request.auth.uid == userId || isAdmin();
      allow write: if isAdmin();
    }

    // Settings - read public, write admins only
    match /settings/{settingId} {
      allow read: if true;
      allow write: if isAdmin();
    }

    // Contact submissions - create anyone, read/update admins only
    match /contactSubmissions/{submissionId} {
      allow create: if request.auth != null;
      allow read, update: if isAdmin();
    }
  }
}
```

---

## 📁 File Structure

```
lib/
├── models/
│   ├── user_model.dart (UPDATED - role, isBlocked)
│   ├── course_model.dart (UPDATED - validityDays)
│   └── enrollment_model.dart (UPDATED - validUntil, approvedBy)
│
├── services/
│   ├── admin_auth_service.dart (NEW)
│   ├── admin_course_service.dart (NEW)
│   ├── admin_payment_service.dart (NEW)
│   ├── admin_user_service.dart (NEW)
│   ├── course_service.dart (UPDATED - validity checking)
│   └── init_service.dart (UPDATED - admin instructions)
│
└── screens/
    ├── admin/
    │   ├── admin_login_screen.dart (NEW)
    │   ├── admin_dashboard_screen.dart (NEW)
    │   ├── dashboard_overview_screen.dart (NEW)
    │   ├── courses_list_screen.dart (NEW)
    │   ├── course_form_screen.dart (NEW)
    │   ├── payments_list_screen.dart (NEW)
    │   └── users_list_screen.dart (NEW)
    │
    └── payment_screen.dart (UPDATED - pending status)
```

---

## 🐛 Troubleshooting

### Issue: Can't login to admin panel

**Causes:**
1. Admin account not created in Firebase Auth
2. User document doesn't have `role: "admin"` in Firestore
3. Wrong email/password

**Solution:**
1. Verify account exists in Firebase Auth
2. Check Firestore users collection for `role` field
3. Reset password if needed

---

### Issue: Payments not showing in Pending tab

**Cause:** Old enrollments still have `status: "completed"`

**Solution:**
1. Update old enrollments in Firestore:
   - Change `status: "completed"` → `"approved"`
   - Add `validUntil` field if missing

---

### Issue: User can't access course after approval

**Causes:**
1. Enrollment status not `approved`
2. `validUntil` date in the past
3. CourseService not checking correctly

**Solution:**
1. Check enrollment document in Firestore
2. Verify `status: "approved"` and `validUntil` is in future
3. Check browser console for errors

---

## 🎓 Best Practices

### For Admins:

1. **Always verify transaction ID** before approving
2. **Provide clear rejection reasons** when rejecting
3. **Set appropriate validity days** based on course length
4. **Regularly review pending payments** (daily)
5. **Keep track of expired enrollments** for support

### For Developers:

1. **Test with dummy data** first
2. **Set up Firebase Security Rules** before production
3. **Monitor Firestore usage** (reads/writes)
4. **Implement logging** for admin actions
5. **Add email notifications** for payment approvals

---

## 🚀 What's Next?

### Recommended Enhancements:

1. **Email Notifications:**
   - Send email when payment approved/rejected
   - Remind users when course expires soon

2. **Advanced Admin Features:**
   - Bulk approve payments
   - Export reports (CSV/PDF)
   - Analytics dashboard

3. **User Features:**
   - View enrollment status
   - Request course extension
   - Download certificate

4. **Payment Features:**
   - Upload transaction screenshot
   - Payment gateway integration
   - Automatic verification

---

## ✅ Testing Checklist

Before going live, test:

- [  ] Admin can login
- [  ] Admin can create course
- [  ] Admin can edit course
- [  ] Admin can add videos to course
- [  ] Admin can delete course
- [  ] Admin can approve payment
- [  ] Admin can reject payment
- [  ] Admin can view users
- [  ] Admin can block user
- [  ] User payment shows as pending
- [  ] User gets access after approval
- [  ] User access expires after validity period
- [  ] Blocked user can't login

---

## 📞 Support

If you encounter issues:
1. Check browser console (F12) for errors
2. Check Firestore for data consistency
3. Verify Firebase Security Rules
4. Check admin account setup

---

**Admin Panel Build Complete!** 🎉

Generated: 2025-01-08
Flutter Version: 3.9.2+
