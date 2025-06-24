import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:naukariwala/screens/profile_screen.dart';
import 'package:naukariwala/screens/search_job_screen.dart';
import 'package:naukariwala/screens/chat_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.deepPurple,
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.photoUrl != null ? NetworkImage(widget.photoUrl!) : null,
                child: widget.photoUrl == null ? const Icon(Icons.person, size: 20) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Welcome, ${widget.seekerName ?? "Seeker"}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          bottom: const TabBar(
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
        body: TabBarView(
          children: [
            const ProfileScreen(isRecruiter: false),
            const SearchJobScreen(isSeekerProfileView: true),
            _buildAppliedJobsTab(),
            _buildNotificationsTab(),
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(seekerId: uid),
                                ),
                              );
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