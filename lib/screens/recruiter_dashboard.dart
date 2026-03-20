// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:naukariwala/screens/profile_screen.dart';
import 'package:naukariwala/screens/post_job_screen.dart';
import 'posted_jobs_view.dart';
import 'package:naukariwala/screens/applied_seekers_screen.dart';
import 'package:naukariwala/screens/calls_screen.dart';
import 'package:naukariwala/screens/notifications_screen.dart';
import 'package:naukariwala/widgets/notification_bell.dart';
import 'package:naukariwala/screens/chat_list_screen.dart';
import '../widgets/chat_icon_with_badge.dart';
import '../services/auth_service.dart';
import 'package:naukariwala/services/ads_service.dart';
import '../services/update_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;

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
    _initializeBannerAd();
    _checkForAppUpdate();
  }

  void _initializeBannerAd() {
    _bannerAd = AdsService.createBannerAd();
    _bannerAd.load().then((_) {
      if (mounted) {
        setState(() {
          _isBannerAdReady = true;
        });
      }
    }).catchError((error) {
      dev.log('Banner ad failed to load: $error', name: 'RecruiterDashboard');
    });
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
  }

  void _checkForAppUpdate() async {
    // Add a small delay to ensure the widget is fully built
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      UpdateService.checkForUpdate(context);
    }
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
                  colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: ListView(
                padding: EdgeInsets.fromLTRB(14.w, 18.h, 14.w, 18.h),
                children: [
                  _buildDrawerHeader(),
                  SizedBox(height: 10.h),
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
                          builder: (context) => PostedJobsScreen(),
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
                  // Banner Ad
                  if (_isBannerAdReady)
                    SizedBox(
                      height: _bannerAd.size.height.toDouble(),
                      width: _bannerAd.size.width.toDouble(),
                      child: AdWidget(ad: _bannerAd),
                    ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: TabBarView(
                      children: [
                        const ProfileScreen(isRecruiter: true),
                        PostedJobsScreen(),
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
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: ListTile(
          leading: Container(
            padding: EdgeInsets.all(7.r),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: Colors.white, size: 20.r),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 15.r,
            color: Colors.white70,
          ),
          onTap: onTap,
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
          tileColor: Colors.transparent,
          hoverColor: Colors.white12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: Image.asset(
              'assets/logo.png',
              height: 62.h,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            recruiterName?.trim().isNotEmpty == true ? recruiterName! : 'Recruiter',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
