import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:naukariwala/screens/profile_screen.dart';
import 'package:naukariwala/screens/search_job_screen.dart';
import 'package:naukariwala/screens/chat_screen.dart';
import '../../services/auth_service.dart';
import 'dart:developer' as dev; // Added import for dev

class SeekerDashboard extends StatefulWidget {
  final String? seekerName;
  final String? photoUrl;

  const SeekerDashboard({super.key, this.seekerName, this.photoUrl});

  @override
  State<SeekerDashboard> createState() => _SeekerDashboardState();
}

class _SeekerDashboardState extends State<SeekerDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
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
        title: const Text(''), // Empty title to avoid overlap
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A1B9A), Color(0xFF00695C)], // Deep Purple to Teal gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: widget.photoUrl != null ? NetworkImage(widget.photoUrl!) : null,
                  child: widget.photoUrl == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.white),
                title: const Text('Profile', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  DefaultTabController.of(context).animateTo(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.work, color: Colors.white),
                title: const Text('Search Jobs', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  DefaultTabController.of(context).animateTo(1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.work_history_rounded, color: Colors.white),
                title: const Text('Applied Jobs', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  DefaultTabController.of(context).animateTo(2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notification_add, color: Colors.white),
                title: const Text('Notifications', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  DefaultTabController.of(context).animateTo(3);
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
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6A1B9A), Color(0xFF00695C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(icon: Icon(Icons.person)),
                  Tab(icon: Icon(Icons.work)),
                  Tab(icon: Icon(Icons.work_history_rounded)),
                  Tab(icon: Icon(Icons.notification_add)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const ProfileScreen(isRecruiter: false),
                  const SearchJobScreen(isSeekerProfileView: true),
                  _buildAppliedJobsTab(),
                  _buildNotificationsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppliedJobsTab() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Please log in to view applied jobs.'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search by title...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.toLowerCase();
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('Applications')
                .doc(uid)
                .collection('AppliedJobs')
                .orderBy('appliedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No jobs applied yet.'));
              }

              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final title = (data['jobTitle'] ?? '').toLowerCase();
                return title.contains(_searchQuery);
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final job = docs[index].data() as Map<String, dynamic>;
                  final appliedAt = job['appliedAt'] != null
                      ? (job['appliedAt'] as Timestamp).toDate()
                      : null;
                  final interviewDate = job['interviewDate'] != null
                      ? (job['interviewDate'] as Timestamp).toDate()
                      : null;
                  final appliedDate = appliedAt != null
                      ? DateFormat('dd MMM yyyy').format(appliedAt)
                      : 'N/A';
                  final interviewDateStr = interviewDate != null
                      ? DateFormat('dd MMM yyyy').format(interviewDate)
                      : null;
                  final jobId = job['jobId'] as String? ?? 'Unknown';
                  final recruiterId = job['recruiterId'] as String? ?? 'Unknown';

                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore
                        .collection('Recruiters')
                        .doc(job['recruiterId'])
                        .collection('Jobs')
                        .doc(job['jobId'])
                        .get(),
                    builder: (context, jobSnapshot) {
                      String companyName = 'Unknown Company';
                      if (jobSnapshot.hasData && jobSnapshot.data!.exists) {
                        final jobData = jobSnapshot.data!.data() as Map<String, dynamic>;
                        companyName = jobData['Company Name'] ?? 'Unknown Company';
                      }

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.work_outline, color: Colors.blue),
                          title: Text('${job['jobTitle']} - $companyName'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Applied on: $appliedDate'),
                              Text('Status: ${job['status'] ?? 'Applied'}'),
                              if (interviewDateStr != null)
                                Text('Interview: $interviewDateStr'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.chat),
                            onPressed: () {
                              if (!mounted) return;
                              final chatId = [uid, recruiterId].join('_').split('_')..sort();
                              final normalizedChatId = '${chatId[0]}_${chatId[1]}';
                              _authService.sendMessage(recruiterId, jobId, 'Hello, I’d like to discuss my application!')
                                  .then((_) {
                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(chatId: normalizedChatId, recipientId: recruiterId, jobId: jobId),
                                    ),
                                  );
                                }
                              }).catchError((e) {
                                dev.log('Error starting chat: $e', name: 'SeekerDashboard', error: e);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Failed to start chat')),
                                  );
                                }
                              });
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsTab() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Please log in to view notifications.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('SeekerNotifications')
          .doc(uid)
          .collection('Notifications')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No notifications yet.'));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final notif = docs[index].data() as Map<String, dynamic>;
            final isRead = notif['read'] == true;
            final timestamp = notif['timestamp'] != null
                ? (notif['timestamp'] as Timestamp).toDate()
                : null;
            final timeStr = timestamp != null
                ? DateFormat('dd MMM yyyy').format(timestamp)
                : '';

            return Card(
              color: isRead ? Colors.grey[200] : Colors.green[50],
              child: ListTile(
                leading: Icon(
                  Icons.notifications,
                  color: isRead ? Colors.grey : Colors.green,
                ),
                title: Text(notif['title'] ?? 'Notification'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notif['message'] ?? ''),
                    if (timeStr.isNotEmpty) Text('Date: $timeStr'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}