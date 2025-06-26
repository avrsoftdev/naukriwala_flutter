import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_job_screen.dart';
import 'job_details_screen.dart';
import 'package:intl/intl.dart';

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

    debugPrint('Current user UID: ${user!.uid}');

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
            debugPrint('Stream error: ${snapshot.error}');
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
              debugPrint('Job $jobId data: $job');

              final title = job['title'] ?? 'Untitled Job';
              final company = job['company'] ?? 'Unknown Company';
              final location = job['location'] ?? 'Unspecified';
              final salary = job['salary'] ?? 'Not specified';
              final status = job['status'] ?? 'unknown';
              final timestamp = job['createdAt'] as Timestamp?;
              final postedDate = timestamp != null
                  ? DateFormat('dd MMM yyyy').format(timestamp.toDate())
                  : 'N/A';

              return FutureBuilder<int>(
                future: _getApplicantCount(jobId),
                builder: (context, applicantSnapshot) {
                  final applicantCount = applicantSnapshot.data ?? 0;
                  if (applicantSnapshot.hasError) {
                    debugPrint('Applicant count error: ${applicantSnapshot.error}');
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: ListTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'open' ? Colors.green[100] : Colors.red[100],
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
                          const SizedBox(height: 4),
                          Text('Company: $company'),
                          Text('Location: $location'),
                          Text('Salary: $salary'),
                          Text('Posted: $postedDate'),
                          Text('Applicants: $applicantCount'),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JobDetailsScreen(job: {...job, 'jobId': jobId}),
                          ),
                        );
                      },
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PostJobScreen(
                                  editJobData: {...job, 'jobId': jobId},
                                ),
                              ),
                            );
                          } else if (value == 'delete') {
                            _confirmDeleteJob(context, jobId);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'edit', child: const Text('Edit')),
                          PopupMenuItem(value: 'delete', child: const Text('Delete')),
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

  Future<int> _getApplicantCount(String jobId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('AppliedJobs')
          .where('jobId', isEqualTo: jobId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error fetching applicant count: $e');
      return 0;
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
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Job deleted')),
                );
              } catch (e) {
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