import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as dev;
import 'package:firebase_auth/firebase_auth.dart';

class MyApplicationsScreen extends StatefulWidget {
  final String seekerId;
  const MyApplicationsScreen({super.key, required this.seekerId});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  late final Stream<QuerySnapshot> _applicationsStream;
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    if (currentUserId == null) {
      dev.log('No authenticated user found', name: 'MyApplicationsScreen');
      return;
    }
    if (currentUserId != widget.seekerId) {
      dev.log('SeekerId mismatch: currentUserId=$currentUserId, widget.seekerId=${widget.seekerId}', name: 'MyApplicationsScreen');
    }
    dev.log('Fetching applications for seekerId: ${widget.seekerId}', name: 'MyApplicationsScreen');
    _applicationsStream = FirebaseFirestore.instance
        .collectionGroup('AppliedJobs')
        .where('seekerId', isEqualTo: widget.seekerId)
        .orderBy('appliedAt', descending: true)
        .snapshots();
  }

  String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  Future<void> _openResume(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open resume')),
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
              final jobTitle = data['jobTitle'] ?? 'N/A';
              final company = data['company'] ?? 'N/A';
              final appliedAt = data['appliedAt'] as Timestamp?;
              final status = data['status'] ?? 'Pending';
              final resumeUrl = data['cvUrl'] ?? data['resumeUrl'] ?? ''; // Check both possible keys

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
                  trailing: resumeUrl.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.picture_as_pdf),
                          tooltip: 'View Resume',
                          onPressed: () => _openResume(resumeUrl),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}