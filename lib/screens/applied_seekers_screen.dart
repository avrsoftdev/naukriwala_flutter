import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // Added for canLaunchUrl and launchUrl

class AppliedSeekersScreen extends StatefulWidget {
  final bool isRecruiter;
  final List<dynamic>? notifications;

  const AppliedSeekersScreen({
    this.isRecruiter = true,
    this.notifications,
    super.key, // Added key parameter
  });

  @override
  _AppliedSeekersScreenState createState() => _AppliedSeekersScreenState();
}

class _AppliedSeekersScreenState extends State<AppliedSeekersScreen> {
  late final Stream<QuerySnapshot> _applicationsStream;
  final String? recruiterId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    if (recruiterId != null) {
      _applicationsStream = FirebaseFirestore.instance
          .collectionGroup('AppliedJobs')
          .where('recruiterId', isEqualTo: recruiterId)
          .orderBy('appliedAt', descending: true)
          .snapshots();
    }
  }

  String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  Future<void> _openResume(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) { // Updated to canLaunchUrl
      await launchUrl(Uri.parse(url)); // Updated to launchUrl
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
    if (recruiterId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Applied Seekers')),
        body: Center(child: Text('Please log in as a recruiter.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Applied Seekers'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _applicationsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading applications: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No applications found.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final seekerId = data['seekerId'] ?? 'N/A';
              final jobTitle = data['jobTitle'] ?? 'N/A';
              final appliedAt = data['appliedAt'] as Timestamp?;
              final resumeUrl = data['resumeUrl'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Seeker ID: $seekerId'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Job: $jobTitle'),
                      if (appliedAt != null) Text('Applied on: ${_formatTimestamp(appliedAt)}'),
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