import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:naukariwala/screens/chat_screen.dart';
import 'package:naukariwala/services/auth_service.dart';
import 'dart:developer' as dev;

class MyApplicationsScreen extends StatefulWidget {
  final String seekerId;
  const MyApplicationsScreen({super.key, required this.seekerId});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your applications.')),
      );
    }
    if (uid != widget.seekerId) {
      return const Scaffold(
        body: Center(child: Text('Unauthorized access. Seeker ID mismatch.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Applications'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
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
                  dev.log('Error loading applications for seekerId $uid: ${snapshot.error}', name: 'MyApplicationsScreen');
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  dev.log('No applications found for seekerId: $uid', name: 'MyApplicationsScreen');
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
                          companyName = jobData['company'] ?? 'Unknown Company';
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
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(context); // Capture NavigatorState
                                final chatId = [uid, recruiterId].join('_').split('_')..sort();
                                final normalizedChatId = '${chatId[0]}_${chatId[1]}';
                                _authService
                                    .sendMessage(recruiterId, jobId, 'Hello, I’d like to discuss my application!')
                                    .then((_) {
                                  if (mounted) {
                                    navigator.push(
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          chatId: normalizedChatId,
                                          recipientId: recruiterId,
                                          jobId: jobId,
                                        ),
                                      ),
                                    );
                                  }
                                }).catchError((e) {
                                  dev.log('Error starting chat: $e', name: 'MyApplicationsScreen', error: e);
                                  if (mounted) {
                                    scaffoldMessenger.showSnackBar(
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
      ),
    );
  }
}