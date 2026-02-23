// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:naukariwala/screens/posted_jobs_screen.dart';
import 'package:naukariwala/screens/profile_screen.dart';
import 'package:naukariwala/screens/post_job_screen.dart';
import 'package:naukariwala/screens/post_job_screen.dart';
import 'package:naukariwala/screens/applied_seekers_screen.dart';
import 'package:naukariwala/screens/calls_screen.dart';
import 'package:naukariwala/screens/notifications_screen.dart';
import 'package:naukariwala/widgets/notification_bell.dart';
import 'package:naukariwala/screens/chat_list_screen.dart';
import '../widgets/chat_icon_with_badge.dart';
import '../services/auth_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  String? recruiterName; // State variable to store the recruiter's name

  @override
  void initState() {
    super.initState();
    if (recruiterId == null) {
      dev.log(
        '[2025-08-08 21:25 IST] No authenticated user found',
        name: 'RecruiterDashboard',
      );
    } else {
      dev.log(
        '[2025-08-08 21:25 IST] Recruiter ID: $recruiterId',
        name: 'RecruiterDashboard',
      );
    }
    _requestNotificationPermissions();
    _checkRoleAndFetchName();
  }

  void _requestNotificationPermissions() async {
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token != null && recruiterId != null) {
      await _firestore.collection('UsersIndex').doc(recruiterId).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
      dev.log(
        '[2025-08-08 21:25 IST] FCM token updated for $recruiterId: $token',
        name: 'RecruiterDashboard',
      );
    } else {
      dev.log(
        '[2025-08-08 21:25 IST] Failed to retrieve FCM token for $recruiterId',
        name: 'RecruiterDashboard',
      );
    }
  }

  Future<void> _checkRoleAndFetchName() async {
    try {
      final role = await _authService.getUserRole();
      dev.log(
        '[2025-08-08 21:25 IST] Role for UID ${FirebaseAuth.instance.currentUser!.uid}: $role',
        name: 'RecruiterDashboard',
      );
      if (role != 'recruiter') {
        dev.log(
          '[2025-08-08 21:25 IST] WARNING: User ${FirebaseAuth.instance.currentUser!.uid} does not have recruiter role',
          name: 'RecruiterDashboard',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Invalid role. Please ensure your account is set as a recruiter.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } else {
        // Fetch recruiter name from Firestore
        final doc = await _firestore
            .collection('Recruiters')
            .doc(recruiterId)
            .get();
        final data = doc.data();
        if (data != null && mounted) {
          setState(() {
            recruiterName = data['name']?.toString() ?? 'Recruiter';
          });
        }
      }
    } catch (e) {
      dev.log(
        '[2025-08-08 21:25 IST] Error checking role or fetching name: $e',
        name: 'RecruiterDashboard',
        error: e,
      );
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

    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 2,
            // title: Text(
            //   'Recruiter Dashboard',
            //   style: TextStyle(
            //     color: const Color.fromARGB(221, 12, 20, 108),
            //     fontWeight: FontWeight.bold,
            //     fontSize: 22.sp,
            //   ),
            // ),
            centerTitle: true,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.black87, size: 28),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            actions: [
              NotificationBell(
                isRecruiter: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          NotificationsScreen(isRecruiter: true),
                    ),
                  );
                },
              ),
              ChatIconWithBadge(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatListScreen(),
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
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: Center(
                      child: Icon(
                        Icons.business_center_outlined,
                        color: Colors.white,
                        size: 44.sp,
                      ),
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
                          builder: (context) =>
                              const ProfileScreen(isRecruiter: true),
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
          body: SingleChildScrollView(
            child: DefaultTabController(
              length: 5,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 8.h,
                      horizontal: 8.w,
                    ),
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
                      isScrollable: true,
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
                      ],
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: TabBarView(
                      children: [
                        const ProfileScreen(isRecruiter: true),
                        const PostedJobsScreen(),
                        AppliedSeekersScreen(
                          authService: _authService,
                          jobId: '',
                          jobTitle: '',
                        ),
                        const CallsScreen(),
                        const PostJobScreen(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 28.r),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 5.h),
      tileColor: Colors.transparent,
      hoverColor: Colors.white12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
    );
  }

  Widget _buildTab(IconData icon, String label) {
    return Tab(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 12.w),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20.r)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20.r),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
