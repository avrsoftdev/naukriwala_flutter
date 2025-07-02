import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;

class AppliedSeekersScreen extends StatefulWidget {
  final bool isRecruiter;
  final List<dynamic>? notifications;

  const AppliedSeekersScreen({
    this.isRecruiter = true,
    this.notifications,
    super.key,
  });

  @override
  AppliedSeekersScreenState createState() => AppliedSeekersScreenState();
}

class AppliedSeekersScreenState extends State<AppliedSeekersScreen> {
  late final Stream<QuerySnapshot> _applicationsStream;
  late final Stream<QuerySnapshot> _notificationsStream;
  final String? recruiterId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    if (recruiterId == null) {
      dev.log('No authenticated user found', name: 'AppliedSeekersScreen');
      return;
    }
    _applicationsStream = FirebaseFirestore.instance
        .collectionGroup('AppliedJobs')
        .where('recruiterId', isEqualTo: recruiterId)
        .orderBy('appliedAt', descending: true)
        .snapshots();
    _notificationsStream = FirebaseFirestore.instance
        .collection('Notifications')
        .where('to', isEqualTo: recruiterId)
        .where('type', isEqualTo: 'application')
        .orderBy('timestamp', descending: true)
        .snapshots();
    dev.log('Initialized streams for recruiterId: $recruiterId', name: 'AppliedSeekersScreen');
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final dt = ts.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  Future<Map<String, dynamic>?> _fetchSeekerProfile(String seekerId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Seekers')
          .doc(seekerId)
          .get();
      if (doc.exists) {
        dev.log('Fetched seeker profile for $seekerId: ${doc.data()}', name: 'AppliedSeekersScreen');
        return doc.data();
      }
      dev.log('No seeker profile found for $seekerId', name: 'AppliedSeekersScreen');
      return null;
    } catch (e) {
      dev.log('Error fetching seeker profile for $seekerId: $e', name: 'AppliedSeekersScreen');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (recruiterId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Applied Seekers')),
        body: const Center(child: Text('Please log in as a recruiter.')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Applied Jobs'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Jobs with Applicants'),
              Tab(text: 'Notifications'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Jobs with Applicants Tab
            StreamBuilder<QuerySnapshot>(
              stream: _applicationsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  dev.log('Error loading applications: ${snapshot.error}', name: 'AppliedSeekersScreen');
                  return Center(child: Text('Error loading applications: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  dev.log('No applications found for recruiterId: $recruiterId', name: 'AppliedSeekersScreen');
                  return const Center(child: Text('No applications found.'));
                }

                // Group by jobId
                final Map<String, List<Map<String, dynamic>>> jobsMap = {};
                for (final doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final jobId = data['jobId'] as String? ?? 'Unknown';
                  jobsMap.putIfAbsent(jobId, () => []).add(data);
                }

                return ListView.builder(
                  itemCount: jobsMap.length,
                  itemBuilder: (context, index) {
                    final jobId = jobsMap.keys.elementAt(index);
                    final applications = jobsMap[jobId]!;
                    final firstApp = applications.first;
                    final jobTitle = firstApp['jobTitle'] ?? 'Untitled Job';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        title: Text('$jobTitle (Applicants: ${applications.length})'),
                        children: applications.map<Widget>((app) {
                          final seekerId = app['seekerId'] ?? 'N/A';
                          final appliedAt = app['appliedAt'] as Timestamp?;

                          return FutureBuilder<Map<String, dynamic>?>(
                            future: _fetchSeekerProfile(seekerId),
                            builder: (context, profileSnapshot) {
                              final profile = profileSnapshot.data;
                              final seekerName = profile?['name'] ?? seekerId;
                              final seekerEmail = profile?['email'] ?? 'N/A';
                              final resume = app['resume'] as Map<String, dynamic>? ?? {};

                              return ListTile(
                                title: Text(seekerName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Email: $seekerEmail'),
                                    if (resume.isNotEmpty) ...[
                                      Text('Skills: ${resume['skills']?.join(', ') ?? 'N/A'}'),
                                      Text('Education: ${resume['education'] ?? 'N/A'}'),
                                    ],
                                    if (appliedAt != null) Text('Applied on: ${_formatTimestamp(appliedAt)}'),
                                  ],
                                ),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('$seekerName - Resume'),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Name: $seekerName'),
                                            Text('Email: $seekerEmail'),
                                            Text('Skills: ${resume['skills']?.join(', ') ?? 'N/A'}'),
                                            Text('Education: ${resume['education'] ?? 'N/A'}'),
                                            Text('Experience: ${resume['experience'] ?? 'N/A'}'),
                                            if (resume['mobileNumber'] != null)
                                              Text('Mobile: ${resume['mobileNumber']}'),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
            // Notifications Tab (unchanged)
            StreamBuilder<QuerySnapshot>(
              stream: _notificationsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  dev.log('Error loading notifications: ${snapshot.error}', name: 'AppliedSeekersScreen');
                  return Center(child: Text('Error loading notifications: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  dev.log('No notifications found for recruiterId: $recruiterId', name: 'AppliedSeekersScreen');
                  return const Center(child: Text('No notifications found.'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final message = data['message'] ?? 'N/A';
                    final timestamp = data['timestamp'] as Timestamp?;
                    final read = data['read'] ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(message),
                        subtitle: timestamp != null ? Text(_formatTimestamp(timestamp)) : null,
                        trailing: read
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.circle, color: Colors.grey),
                        onTap: () async {
                          try {
                            await FirebaseFirestore.instance
                                .collection('Notifications')
                                .doc(docs[index].id)
                                .update({'read': true});
                            dev.log('Marked notification ${docs[index].id} as read', name: 'AppliedSeekersScreen');
                          } catch (e) {
                            dev.log('Error marking notification as read: $e', name: 'AppliedSeekersScreen');
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}