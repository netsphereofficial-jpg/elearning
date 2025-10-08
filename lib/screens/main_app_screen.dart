import 'package:flutter/material.dart';
import '../widgets/modern_navbar.dart';
import 'home_screen.dart';
import 'about_screen.dart';
import 'gallery_screen.dart';
import 'courses_grid_screen.dart';
import 'testimony_screen.dart';
import 'contact_us_screen.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onNavigateToCourses: () => _navigateToIndex(3)),
      const AboutScreen(),
      const GalleryScreen(),
      const CoursesGridScreen(),
      const TestimonyScreen(),
      const ContactUsScreen(),
    ];
  }

  void _navigateToIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ModernNavBar(
            currentIndex: _currentIndex,
            onIndexChanged: _navigateToIndex,
          ),
          Expanded(
            child: _screens[_currentIndex],
          ),
        ],
      ),
    );
  }
}
