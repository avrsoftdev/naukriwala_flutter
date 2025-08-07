import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:naukariwala/screens/profile_screen.dart';
import 'package:naukariwala/screens/search_job_screen.dart';
import 'package:naukariwala/screens/my_applications_screen.dart';
import 'package:naukariwala/screens/notifications_screen.dart';
import 'package:naukariwala/services/auth_service.dart';
import 'dart:developer' as dev;

class SeekerDashboard extends StatefulWidget {
  final String? seekerName;
  final String? photoUrl;

  const SeekerDashboard({super.key, this.seekerName, this.photoUrl});

  @override
  State<SeekerDashboard> createState() => _SeekerDashboardState();
}

class _SeekerDashboardState extends State<SeekerDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          dev.log('No user logged in, redirecting to login', name: 'SeekerDashboard');
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
        title: null, // Removed Text widget
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87, size: 22),
            padding: const EdgeInsets.all(2),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.black87, size: 22),
            padding: const EdgeInsets.all(2),
            onPressed: () {
              dev.log('Navigating to NotificationsScreen', name: 'SeekerDashboard');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(isRecruiter: false),
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
                      backgroundImage: widget.photoUrl != null ? NetworkImage(widget.photoUrl!) : null,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      child: widget.photoUrl == null
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        widget.seekerName ?? 'Seeker',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDrawerItem(
                icon: Icons.person,
                title: 'Profile',
                onTap: () {
                  dev.log('Navigating to ProfileScreen', name: 'SeekerDashboard');
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(isRecruiter: false),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.work,
                title: 'Search Jobs',
                onTap: () {
                  dev.log('Navigating to SearchJobScreen', name: 'SeekerDashboard');
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchJobScreen()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.work_history_rounded,
                title: 'Applied Jobs',
                onTap: () {
                  dev.log('Navigating to MyApplicationsScreen', name: 'SeekerDashboard');
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MyApplicationsScreen(seekerId: uid)),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.notification_add,
                title: 'Notifications',
                onTap: () {
                  dev.log('Navigating to NotificationsScreen', name: 'SeekerDashboard');
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(isRecruiter: false),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.logout,
                title: 'Logout',
                onTap: () async {
                  dev.log('Logging out', name: 'SeekerDashboard');
                  Navigator.pop(context);
                  await _authService.signOut();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Logged out successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
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
                  _buildTab(Icons.work_history_rounded, 'Applications'),
                  _buildTab(Icons.notification_add, 'Notifications'),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: TabBarView(
                  children: [
                    const ProfileScreen(isRecruiter: false),
                    const SearchJobScreen(isSeekerProfileView: true),
                    MyApplicationsScreen(seekerId: uid),
                    const NotificationsScreen(isRecruiter: false),
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
      leading: Icon(icon, color: Colors.white, size: 24),
      title: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      tileColor: Colors.transparent,
      hoverColor: Colors.white12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildTab(IconData icon, String label) {
    dev.log('Building tab: $label', name: 'SeekerDashboard');
    return Tab(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 40), // Reduced for icon-only
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, size: 16), // Icon-only tab
      ),
    );
  }
}