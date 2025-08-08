import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:naukariwala/screens/profile_screen.dart';
import 'package:naukariwala/screens/posted_jobs_screen.dart';
import 'package:naukariwala/screens/post_job_screen.dart';
import 'package:naukariwala/screens/applied_seekers_screen.dart';
import 'package:naukariwala/screens/calls_screen.dart';
import 'package:naukariwala/screens/notifications_screen.dart';
import '../../services/auth_service.dart';
import 'dart:developer' as dev;

class RecruiterDashboard extends StatefulWidget {
  const RecruiterDashboard({super.key});

  @override
  State<RecruiterDashboard> createState() => _RecruiterDashboardState();
}

class _RecruiterDashboardState extends State<RecruiterDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final String? recruiterId = FirebaseAuth.instance.currentUser?.uid;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    if (recruiterId == null) {
      dev.log('[2025-08-08 21:25 IST] No authenticated user found', name: 'RecruiterDashboard');
    } else {
      dev.log('[2025-08-08 21:25 IST] Recruiter ID: $recruiterId', name: 'RecruiterDashboard');
    }
    _requestNotificationPermissions();
    _checkRole();
  }

  void _requestNotificationPermissions() async {
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token != null && recruiterId != null) {
      await _firestore.collection('UsersIndex').doc(recruiterId).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
      dev.log('[2025-08-08 21:25 IST] FCM token updated for $recruiterId: $token', name: 'RecruiterDashboard');
    } else {
      dev.log('[2025-08-08 21:25 IST] Failed to retrieve FCM token for $recruiterId', name: 'RecruiterDashboard');
    }
  }

  Future<void> _checkRole() async {
    try {
      final role = await _authService.getUserRole();
      dev.log('[2025-08-08 21:25 IST] Role for UID ${FirebaseAuth.instance.currentUser!.uid}: $role', name: 'RecruiterDashboard');
      if (role != 'recruiter') {
        dev.log('[2025-08-08 21:25 IST] WARNING: User ${FirebaseAuth.instance.currentUser!.uid} does not have recruiter role', name: 'RecruiterDashboard');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Invalid role. Please ensure your account is set as a recruiter.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      dev.log('[2025-08-08 21:25 IST] Error checking role: $e', name: 'RecruiterDashboard', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (recruiterId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please log in to access the dashboard.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: const Text(
          'Recruiter Dashboard',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.black87, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(isRecruiter: true),
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Recruiter',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDrawerItem(
                icon: Icons.person,
                title: 'Profile',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(isRecruiter: true),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.work,
                title: 'Posted Jobs',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PostedJobsScreen(),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.group_add,
                title: 'Applied Seekers',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppliedSeekersScreen(
                        authService: _authService,
                        jobId: '',
                        jobTitle: '',
                      ),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.call,
                title: 'Calls',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CallsScreen(),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.work,
                title: 'Post a Job',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PostJobScreen(),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.notifications,
                title: 'Notifications',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(isRecruiter: true),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.logout,
                title: 'Logout',
                onTap: () async {
                  await _authService.signOut();
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, '/');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Logged out successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: DefaultTabController(
        length: 6,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicator: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  color: Colors.white24,
                ),
                tabs: [
                  _buildTab(Icons.person, 'Profile'),
                  _buildTab(Icons.work, 'Jobs'),
                  _buildTab(Icons.group_add, 'Seekers'),
                  _buildTab(Icons.call, 'Calls'),
                  _buildTab(Icons.post_add, 'Post Job'),
                  _buildTab(Icons.notifications, 'Notifications'),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: TabBarView(
                  children: [
                    ProfileScreen(isRecruiter: true),
                    PostedJobsScreen(),
                    AppliedSeekersScreen(
                      authService: _authService,
                      jobId: '',
                      jobTitle: '',
                    ),
                    CallsScreen(),
                    PostJobScreen(),
                    NotificationsScreen(isRecruiter: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 28),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      tileColor: Colors.transparent,
      hoverColor: Colors.white12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildTab(IconData icon, String label) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}