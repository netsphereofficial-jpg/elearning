import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize app with test course, payment settings, and admin note
  Future<void> initializeTestData() async {
    try {
      await _initializeSampleCourse();
      await _initializePaymentSettings();
      await _initializeAdminNote();
      await _createAdminFirestoreDocuments();
    } catch (e) {
      print('Error initializing test data: $e');
    }
  }

  // Create sample course with 10 videos
  Future<void> _initializeSampleCourse() async {
    try {
      // Check if courses collection is empty
      final coursesSnapshot = await _firestore.collection('courses').limit(1).get();

      if (coursesSnapshot.docs.isEmpty) {
        print('Creating sample course with 10 videos...');

        // Sample course data
        await _firestore.collection('courses').add({
          'title': 'Complete Flutter Development Course',
          'description': 'Master Flutter development from basics to advanced. Build beautiful, cross-platform mobile and web applications with hands-on projects and real-world examples.',
          'thumbnailUrl': 'https://images.unsplash.com/photo-1516397281156-ca07cf9746fc?w=800',
          'price': 999,
          'validityDays': 30, // Course valid for 30 days after enrollment
          'isPublished': true,
          'createdAt': FieldValue.serverTimestamp(),
          'videos': [
            {
              'videoId': 'video_001',
              'title': 'Introduction to Flutter - FREE Preview',
              'description': 'Welcome to the course! Learn what Flutter is, why it\'s amazing, and what we\'ll build together.',
              'bunnyVideoGuid': '62d26a71-7b57-43c7-bdf2-8da954fc45c8',
              'thumbnailUrl': 'https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=400',
              'durationInSeconds': 480,
              'order': 1,
              'isFree': true,
            },
            {
              'videoId': 'video_002',
              'title': 'Setting Up Your Development Environment',
              'description': 'Install Flutter, VS Code, Android Studio, and set up your first Flutter project.',
              'bunnyVideoGuid': '62d26a71-7b57-43c7-bdf2-8da954fc45c8',
              'thumbnailUrl': 'https://images.unsplash.com/photo-1461749280684-dccba630e2f6?w=400',
              'durationInSeconds': 720,
              'order': 2,
              'isFree': false,
            },
            {
              'videoId': 'video_003',
              'title': 'Dart Programming Fundamentals',
              'description': 'Master Dart basics: variables, functions, classes, and object-oriented programming.',
              'bunnyVideoGuid': '62d26a71-7b57-43c7-bdf2-8da954fc45c8',
              'thumbnailUrl': 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=400',
              'durationInSeconds': 900,
              'order': 3,
              'isFree': false,
            },
            {
              'videoId': 'video_004',
              'title': 'Flutter Widgets Deep Dive',
              'description': 'Understand StatelessWidget, StatefulWidget, and build your first interactive app.',
              'bunnyVideoGuid': '62d26a71-7b57-43c7-bdf2-8da954fc45c8',
              'thumbnailUrl': 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=400',
              'durationInSeconds': 840,
              'order': 4,
              'isFree': false,
            },
            {
              'videoId': 'video_005',
              'title': 'Layouts and Responsive Design',
              'description': 'Master Column, Row, Stack, and create responsive UIs that work on all screen sizes.',
              'bunnyVideoGuid': '62d26a71-7b57-43c7-bdf2-8da954fc45c8',
              'thumbnailUrl': 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=400',
              'durationInSeconds': 780,
              'order': 5,
              'isFree': false,
            },
            {
              'videoId': 'video_006',
              'title': 'Navigation and Routing',
              'description': 'Learn Navigator, named routes, and pass data between screens effectively.',
              'bunnyVideoGuid': '62d26a71-7b57-43c7-bdf2-8da954fc45c8',
              'thumbnailUrl': 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=400',
              'durationInSeconds': 660,
              'order': 6,
              'isFree': false,
            },
            {
              'videoId': 'video_007',
              'title': 'State Management with Provider',
              'description': 'Manage app state efficiently using Provider pattern and ChangeNotifier.',
              'bunnyVideoGuid': '62d26a71-7b57-43c7-bdf2-8da954fc45c8',
              'thumbnailUrl': 'https://images.unsplash.com/photo-1551650975-87deedd944c3?w=400',
              'durationInSeconds': 1020,
              'order': 7,
              'isFree': false,
            },
            {
              'videoId': 'video_008',
              'title': 'Firebase Integration',
              'description': 'Connect your app to Firebase: Authentication, Firestore database, and Cloud Storage.',
              'bunnyVideoGuid': '62d26a71-7b57-43c7-bdf2-8da954fc45c8',
              'thumbnailUrl': 'https://images.unsplash.com/photo-1551650975-87deedd944c3?w=400',
              'durationInSeconds': 960,
              'order': 8,
              'isFree': false,
            },
            {
              'videoId': 'video_009',
              'title': 'REST APIs and HTTP Requests',
              'description': 'Fetch data from APIs, handle JSON, and display dynamic content in your app.',
              'bunnyVideoGuid': '62d26a71-7b57-43c7-bdf2-8da954fc45c8',
              'thumbnailUrl': 'https://images.unsplash.com/photo-1504639725590-34d0984388bd?w=400',
              'durationInSeconds': 840,
              'order': 9,
              'isFree': false,
            },
            {
              'videoId': 'video_010',
              'title': 'Publishing Your App',
              'description': 'Deploy your Flutter app to Google Play Store, Apple App Store, and the web.',
              'bunnyVideoGuid': '62d26a71-7b57-43c7-bdf2-8da954fc45c8',
              'thumbnailUrl': 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=400',
              'durationInSeconds': 720,
              'order': 10,
              'isFree': false,
            },
          ],
        });

        print('✅ Sample course created with 10 videos!');
      } else {
        print('Courses already exist in Firestore');
      }
    } catch (e) {
      print('Error creating sample course: $e');
    }
  }

  // Create payment settings document
  Future<void> _initializePaymentSettings() async {
    try {
      final settingsDoc = await _firestore.collection('settings').doc('payment').get();

      if (!settingsDoc.exists) {
        print('Creating payment settings...');

        await _firestore.collection('settings').doc('payment').set({
          'qrCodeImageUrl': 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=upi://pay?pa=example@paytm&pn=E-Learning%20Platform&cu=INR',
          'upiId': 'example@paytm',
          'paymentNote': 'Scan QR code or use UPI ID to make payment. Enter transaction ID after payment.',
        });

        print('✅ Payment settings created!');
      } else {
        print('Payment settings already exist');
      }
    } catch (e) {
      print('Error creating payment settings: $e');
    }
  }

  // Create admin setup instructions
  Future<void> _initializeAdminNote() async {
    try {
      final adminDoc = await _firestore.collection('settings').doc('admin').get();

      if (!adminDoc.exists) {
        print('Creating admin setup instructions...');

        await _firestore.collection('settings').doc('admin').set({
          'setupInstructions': '''
ADMIN SETUP REQUIRED:

Create 3 admin accounts manually in Firebase Console:

1. Go to Firebase Console → Authentication → Users
2. Click "Add User" and create these accounts:

   Admin 1:
   Email: admin1@elearning.com
   Password: Admin@123

   Admin 2:
   Email: admin2@elearning.com
   Password: Admin@123

   Admin 3:
   Email: admin3@elearning.com
   Password: Admin@123

3. After creating the auth accounts, update the Firestore users collection:
   - For each admin user document, add/update:
     role: "admin"
     isBlocked: false

Admin Panel Access:
- Web: http://localhost:PORT/#/admin
- These admins can log in via the admin login screen
''',
          'adminEmails': [
            'admin1@elearning.com',
            'admin2@elearning.com',
            'admin3@elearning.com',
          ],
          'createdAt': FieldValue.serverTimestamp(),
        });

        print('✅ Admin setup instructions created!');
        print('');
        print('⚠️  IMPORTANT: Create admin accounts in Firebase Console');
        print('   Emails: admin1@elearning.com, admin2@elearning.com, admin3@elearning.com');
        print('   Password for all: Admin@123');
      } else {
        print('Admin setup instructions already exist');
      }
    } catch (e) {
      print('Error creating admin setup instructions: $e');
    }
  }

  // Create Firestore documents for admin users that exist in Firebase Auth
  Future<void> _createAdminFirestoreDocuments() async {
    try {
      print('Checking for admin users in Firebase Auth...');

      final adminEmails = [
        'admin1@elearning.com',
        'admin2@elearning.com',
        'admin3@elearning.com',
      ];

      for (final email in adminEmails) {
        try {
          // Check if user document exists in Firestore
          final usersQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          if (usersQuery.docs.isEmpty) {
            // Try to get the user from Firebase Auth
            final users = await _auth.fetchSignInMethodsForEmail(email);

            if (users.isNotEmpty) {
              // User exists in Firebase Auth but not in Firestore
              print('Found $email in Firebase Auth. Creating Firestore document...');

              // We need to get the UID, but we can't without signing in
              // So we'll create a helper method to sign in temporarily
              try {
                final userCredential = await _auth.signInWithEmailAndPassword(
                  email: email,
                  password: 'Admin@123',
                );

                final user = userCredential.user!;

                // Create user document in Firestore with admin role
                await _firestore.collection('users').doc(user.uid).set({
                  'email': email,
                  'name': email.split('@')[0].replaceAll('admin', 'Admin '),
                  'photoUrl': null,
                  'isPremium': false,
                  'role': 'admin',
                  'isBlocked': false,
                  'createdAt': FieldValue.serverTimestamp(),
                  'lastLoginAt': FieldValue.serverTimestamp(),
                  'maxConcurrentSessions': 2,
                });

                print('✅ Created Firestore admin document for $email');

                // Sign out after creating document
                await _auth.signOut();
              } catch (authError) {
                print('Could not auto-create admin document for $email: $authError');
                print('Please create manually or use correct password.');
              }
            } else {
              print('⚠️  $email does not exist in Firebase Auth');
            }
          } else {
            print('✓ Firestore document already exists for $email');
          }
        } catch (e) {
          print('Error processing $email: $e');
        }
      }

      print('Admin Firestore document check complete.');
    } catch (e) {
      print('Error creating admin Firestore documents: $e');
    }
  }
}
