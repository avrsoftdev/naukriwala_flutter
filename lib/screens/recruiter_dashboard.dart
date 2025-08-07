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
      dev.log('No authenticated user found', name: 'RecruiterDashboard');
    } else {
      dev.log('Recruiter ID: $recruiterId', name: 'RecruiterDashboard');
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
      dev.log('FCM token updated for $recruiterId: $token', name: 'RecruiterDashboard');
    } else {
      dev.log('Failed to retrieve FCM token for $recruiterId', name: 'RecruiterDashboard');
    }
  }

  Future<void> _checkRole() async {
    try {
      final role = await _authService.getUserRole();
      dev.log('Role for UID ${FirebaseAuth.instance.currentUser!.uid}: $role', name: 'RecruiterDashboard');
      if (role != 'recruiter') {
        dev.log('WARNING: User ${FirebaseAuth.instance.currentUser!.uid} does not have recruiter role', name: 'RecruiterDashboard');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid role. Please ensure your account is set as a recruiter.')),
          );
        }
      }
    } catch (e) {
      dev.log('Error checking role: $e', name: 'RecruiterDashboard', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (recruiterId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to access the dashboard.')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(''),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A1B9A), Color(0xFF00695C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.white),
                title: const Text('Profile', style: TextStyle(color: Colors.white)),
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
              ListTile(
                leading: const Icon(Icons.work, color: Colors.white),
                title: const Text('Posted Jobs', style: TextStyle(color: Colors.white)),
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
              ListTile(
                leading: const Icon(Icons.group_add, color: Colors.white),
                title: const Text('Applied Seekers', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppliedSeekersScreen(authService: _authService),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.call, color: Colors.white),
                title: const Text('Calls', style: TextStyle(color: Colors.white)),
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
              ListTile(
                leading: const Icon(Icons.work, color: Colors.white),
                title: const Text('Post a Job', style: TextStyle(color: Colors.white)),
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
              ListTile(
                leading: const Icon(Icons.notifications, color: Colors.white),
                title: const Text('Notifications', style: TextStyle(color: Colors.white)),
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
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: const Text('Logout', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await _authService.signOut();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged out successfully')),
                    );
                  }
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
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6A1B9A), Color(0xFF00695C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const TabBar(
                labelColor: Colors.transparent,
                unselectedLabelColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                tabs: [
                  Tab(icon: Icon(Icons.person)),
                  Tab(icon: Icon(Icons.work)),
                  Tab(icon: Icon(Icons.group_add)),
                  Tab(icon: Icon(Icons.call)),
                  Tab(icon: Icon(Icons.post_add)),
                  Tab(icon: Icon(Icons.notifications)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ProfileScreen(isRecruiter: true),
                  PostedJobsScreen(),
                  AppliedSeekersScreen(authService: _authService),
                  CallsScreen(),
                  PostJobScreen(),
                  NotificationsScreen(isRecruiter: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
