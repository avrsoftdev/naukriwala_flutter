import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as dev;
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class MyApplicationsScreen extends StatefulWidget {
  final String seekerId;
  const MyApplicationsScreen({super.key, required this.seekerId});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  late Stream<QuerySnapshot> _applicationsStream;
  String? currentUserId;

  void _initStream() {
    if (currentUserId != null && currentUserId == widget.seekerId) {
      _applicationsStream = FirebaseFirestore.instance
          .collectionGroup('AppliedJobs')
          .where('seekerId', isEqualTo: widget.seekerId)
          .orderBy('appliedAt', descending: true)
          .snapshots();
    } else {
      _applicationsStream = const Stream.empty();
    }
  }

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _initStream();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        currentUserId = user?.uid;
        _initStream();
      });
    });
  }

  String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  Future<void> _openResume(String url) async {
    if (url.isEmpty) {
      dev.log('No resume URL provided for seeker ${widget.seekerId}', name: 'MyApplicationsScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No resume available')),
        );
      }
      return;
    }
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
        dev.log('Opened resume for seeker ${widget.seekerId}: $url', name: 'MyApplicationsScreen');
      } else {
        dev.log('Could not launch resume URL: $url', name: 'MyApplicationsScreen');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open resume')),
          );
        }
      }
    } catch (e) {
      dev.log('Error opening resume URL $url: $e', name: 'MyApplicationsScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening resume')),
        );
      }
    }
  }

  void _startChat(String jobId, String recruiterId) async {
    try {
      final authService = AuthService(); // Instantiate AuthService
      final chatId = [widget.seekerId, recruiterId].join('_').split('_')..sort();
      final normalizedChatId = '${chatId[0]}_${chatId[1]}';
      await authService.sendMessage(recruiterId, jobId, 'Hello, I’d like to discuss my application!');

      // Navigate to ChatScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(chatId: normalizedChatId, recipientId: recruiterId, jobId: jobId),
        ),
      );
    } catch (e) {
      dev.log('Error starting chat: $e', name: 'MyApplicationsScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start chat')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your applications.')),
      );
    }
    if (currentUserId != widget.seekerId) {
      return const Scaffold(
        body: Center(child: Text('Unauthorized access. Seeker ID mismatch.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Applications'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _applicationsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            dev.log('Error loading applications for seekerId ${widget.seekerId}: ${snapshot.error}', name: 'MyApplicationsScreen');
            if (snapshot.error.toString().contains('FAILED_PRECONDITION')) {
              return const Center(
                child: Text(
                  'Error loading applications: Index required. Create it here: https://console.firebase.google.com/v1/r/project/naukriwala-455909/firestore/indexes',
                  textAlign: TextAlign.center,
                ),
              );
            }
            return Center(child: Text('Error loading applications: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            dev.log('No applications found for seekerId: ${widget.seekerId}', name: 'MyApplicationsScreen');
            return const Center(child: Text('No applications found.'));
          }

          dev.log('Loaded ${docs.length} applications for seekerId: ${widget.seekerId}', name: 'MyApplicationsScreen');
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final jobId = docs[index].reference.parent.parent?.id ?? 'N/A'; // Get jobId from parent path
              final recruiterId = data['recruiterId'] ?? 'N/A';
              final jobTitle = data['jobTitle'] ?? 'N/A';
              final company = data['company'] ?? 'N/A';
              final appliedAt = data['appliedAt'] as Timestamp?;
              final status = data['status'] ?? 'Pending';
              final resumeData = data['resume'] as Map<String, dynamic>?;
              final resumeUrl = resumeData?['cvUrl'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(jobTitle),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Company: $company'),
                      if (appliedAt != null) Text('Applied on: ${_formatTimestamp(appliedAt)}'),
                      Text('Status: $status'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (resumeUrl.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf),
                          tooltip: 'View Resume',
                          onPressed: () => _openResume(resumeUrl),
                        ),
                      IconButton(
                        icon: const Icon(Icons.chat),
                        tooltip: 'Start Chat',
                        onPressed: () => _startChat(jobId, recruiterId),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Placeholder ChatScreen (to be implemented)
class ChatScreen extends StatelessWidget {
  final String chatId;
  final String recipientId;
  final String jobId;

  const ChatScreen({super.key, required this.chatId, required this.recipientId, required this.jobId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Center(
        child: Text('Chat with $recipientId for job $jobId (Chat ID: $chatId)\nImplement message list and input here.'),
      ),
    );
  }
}