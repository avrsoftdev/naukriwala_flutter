import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_job_screen.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;

class PostedJobsScreen extends StatefulWidget {
  const PostedJobsScreen({super.key});

  @override
  State<PostedJobsScreen> createState() => _PostedJobsScreenState();
}

class _PostedJobsScreenState extends State<PostedJobsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    dev.log('Current user UID: ${user!.uid}', name: 'PostedJobsScreen');

    final jobsQuery = FirebaseFirestore.instance
        .collection('Recruiters')
        .doc(user!.uid)
        .collection('Jobs')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posted Jobs'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: jobsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            dev.log('Stream error for user ${user!.uid}: ${snapshot.error}', name: 'PostedJobsScreen', error: snapshot.error);
            return Center(child: Text('Error loading jobs: ${snapshot.error}'));
          }

          final jobs = snapshot.data?.docs ?? [];

          if (jobs.isEmpty) {
            return const Center(child: Text('No jobs posted yet'));
          }

          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index].data() as Map<String, dynamic>;
              final jobId = jobs[index].id;
              dev.log('Job $jobId data for user ${user!.uid}: $job', name: 'PostedJobsScreen');

              final title = job['title'] ?? 'Untitled Job';
              final company = job['company'] ?? 'Unknown Company';
              final location = job['location'] ?? 'Unspecified';
              final salary = job['salary'] ?? 'Not specified';
              final status = job['status'] ?? 'unknown';
              final timestamp = job['createdAt'] as Timestamp?;
              final postedDate = timestamp != null
                  ? DateFormat('dd MMM yyyy').format(timestamp.toDate())
                  : 'N/A';

              return FutureBuilder<Map<String, dynamic>>(
                future: _getApplicantData(jobId),
                builder: (context, applicantSnapshot) {
                  final applicantCount = applicantSnapshot.data?['count'] ?? 0;
                  final applicantNames = applicantSnapshot.data?['names'] ?? [];

                  if (applicantSnapshot.hasError) {
                    dev.log(
                        'Applicant data error for job $jobId (user ${user!.uid}): ${applicantSnapshot.error}',
                        name: 'PostedJobsScreen',
                        error: applicantSnapshot.error);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: ExpansionTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(title,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'open'
                                    ? Colors.green[100]
                                    : Colors.red[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: status == 'open'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Company: $company'),
                            Text('Location: $location'),
                            Text('Salary: $salary'),
                            Text('Posted: $postedDate'),
                            Text('Applicants: Error loading count'),
                          ],
                        ),
                        children: [const ListTile(title: Text('Error loading applicants'))],
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PostJobScreen(editJobData: {...job, 'jobId': jobId}),
                                ),
                              );
                            } else if (value == 'delete') {
                              _confirmDeleteJob(context, jobId);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: ExpansionTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(title,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'open'
                                  ? Colors.green[100]
                                  : Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: status == 'open' ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Company: $company'),
                          Text('Location: $location'),
                          Text('Salary: $salary'),
                          Text('Posted: $postedDate'),
                          Text('Applicants: $applicantCount'),
                        ],
                      ),
                      children: applicantNames.isNotEmpty
                          ? applicantNames
                              .map<Widget>((name) => ListTile(title: Text(name)))
                              .toList()
                          : [const ListTile(title: Text('No applicants yet'))],
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PostJobScreen(editJobData: {...job, 'jobId': jobId}),
                              ),
                            );
                          } else if (value == 'delete') {
                            _confirmDeleteJob(context, jobId);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _getApplicantData(String jobId) async {
    try {
      // Query direct path instead of collection group
      final snapshot = await FirebaseFirestore.instance
          .collection('Applications')
          .doc(jobId)
          .collection('AppliedJobs')
          .where('recruiterId', isEqualTo: user!.uid)
          .get();

      dev.log('Fetched ${snapshot.docs.length} applicants for job $jobId by user ${user!.uid}', name: 'PostedJobsScreen');

      final names = snapshot.docs.map((doc) {
        final data = doc.data();
        // Fetch seeker profile to ensure accurate name
        return FirebaseFirestore.instance
            .collection('Seekers')
            .doc(doc.id)
            .get()
            .then((seekerDoc) => (seekerDoc.data()?['name'] as String?) ?? 'Unknown Seeker');
      }).toList();

      // Resolve all seeker profile queries
      final resolvedNames = await Future.wait(names);

      return {'count': snapshot.docs.length, 'names': resolvedNames};
    } catch (e) {
      dev.log('Error fetching applicant data for job $jobId by user ${user!.uid}: $e', name: 'PostedJobsScreen', error: e);
      if (e is FirebaseException) {
        dev.log('Firebase error details: ${e.code} - ${e.message}', name: 'PostedJobsScreen');
      }
      return {'count': 0, 'names': []};
    }
  }

  void _confirmDeleteJob(BuildContext context, String jobId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text('Are you sure you want to delete this job?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance
                    .collection('Recruiters')
                    .doc(user!.uid)
                    .collection('Jobs')
                    .doc(jobId)
                    .delete();
                // Also delete Applications/{jobId} to clean up
                await FirebaseFirestore.instance
                    .collection('Applications')
                    .doc(jobId)
                    .delete();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Job deleted')),
                );
              } catch (e) {
                dev.log('Error deleting job $jobId: $e', name: 'PostedJobsScreen', error: e);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete job: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}