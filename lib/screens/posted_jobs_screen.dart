import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:naukariwala/screens/post_job_screen.dart';
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
      return Scaffold(
        body: Center(
          child: Card(
            elevation: 4,
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'User not logged in',
                style: TextStyle(color: Colors.red.shade700, fontSize: 16),
              ),
            ),
          ),
        ),
      );
    }

    dev.log('[2025-08-08 20:48 IST] Current user UID: ${user!.uid}', name: 'PostedJobsScreen');

    final jobsQuery = FirebaseFirestore.instance
        .collection('Recruiters')
        .doc(user!.uid)
        .collection('Jobs')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Posted Jobs',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: jobsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            );
          }

          if (snapshot.hasError) {
            dev.log('[2025-08-08 20:48 IST] Stream error for user ${user!.uid}: ${snapshot.error}', name: 'PostedJobsScreen', error: snapshot.error);
            String errorMessage = 'Error loading jobs. Please verify Firestore permissions.';
            if (snapshot.error is FirebaseException) {
              final error = snapshot.error as FirebaseException;
              errorMessage = 'Firebase error: ${error.code} - ${error.message}';
              if (error.code == 'permission-denied') {
                errorMessage += '\nEnsure /Recruiters/${user!.uid}/Jobs is accessible.';
              }
            }
            return Center(
              child: Card(
                elevation: 4,
                color: Colors.red.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    errorMessage,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          final jobs = snapshot.data?.docs ?? [];

          if (jobs.isEmpty) {
            return Center(
              child: Text(
                'No jobs posted yet',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            );
          }

          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index].data() as Map<String, dynamic>;
              final jobId = jobs[index].id;
              dev.log('[2025-08-08 20:48 IST] Job $jobId data for user ${user!.uid}: $job', name: 'PostedJobsScreen');

              final title = job['title'] ?? 'Untitled Job';
              final company = job['company'] ?? 'Unknown Company';
              final location = job['location'] ?? 'Unspecified';
              final salary = job['salary'] ?? 'Not specified';
              final skills = (job['skills'] as List<dynamic>?)?.join(', ') ?? 'N/A';
              final education = job['education'] ?? 'N/A';
              final specialization = job['specialization'] ?? 'N/A';
              final status = job['status'] ?? 'unknown';
              final timestamp = job['createdAt'] as Timestamp?;
              final postedDate = timestamp != null
                  ? DateFormat('dd MMM yyyy').format(timestamp.toDate())
                  : 'N/A';

              return FutureBuilder<Map<String, dynamic>>(
                future: _getApplicantData(jobId),
                builder: (context, applicantSnapshot) {
                  final applicantCount = applicantSnapshot.data?['count'] ?? 0;
                  final applicants = applicantSnapshot.data?['applicants'] ?? [];

                  return AnimatedListItem(
                    child: Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.blue.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: status == 'open' ? Colors.green.shade100 : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: status == 'open' ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Company: $company', style: TextStyle(color: Colors.grey.shade700)),
                                Text('Location: $location', style: TextStyle(color: Colors.grey.shade700)),
                                Text('Salary: $salary', style: TextStyle(color: Colors.grey.shade700)),
                                Text('Skills: $skills', style: TextStyle(color: Colors.grey.shade700)),
                                Text('Education: $education', style: TextStyle(color: Colors.grey.shade700)),
                                Text('Specialization: $specialization', style: TextStyle(color: Colors.grey.shade700)),
                                Text('Posted: $postedDate', style: TextStyle(color: Colors.grey.shade700)),
                                Text('Applicants: $applicantCount', style: TextStyle(color: Colors.grey.shade700)),
                              ],
                            ),
                          ),
                          children: applicantSnapshot.hasError
                              ? [
                                  ListTile(
                                    title: Text(
                                      'Error loading applicants',
                                      style: TextStyle(color: Colors.red.shade700),
                                    ),
                                  ),
                                ]
                              : applicants.isNotEmpty
                                  ? applicants.map<Widget>((applicant) => ListTile(
                                        title: Text(applicant['name'], style: const TextStyle(color: Colors.black87)),
                                        subtitle: Text('Resume URL: ${applicant['resumeUrl'] ?? 'N/A'}', style: TextStyle(color: Colors.blue.shade600)),
                                      )).toList()
                                  : [
                                      const ListTile(
                                        title: Text('No applicants yet', style: TextStyle(color: Colors.grey)),
                                      ),
                                    ],
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.teal),
                            onSelected: (value) {
                              if (value == 'edit') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PostJobScreen(editJobData: {...job, 'jobId': jobId}),
                                  ),
                                );
                              } else if (value == 'delete') {
                                _confirmDeleteJob(context, jobId);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit', style: TextStyle(color: Colors.teal)),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
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
      final snapshot = await FirebaseFirestore.instance
          .collection('Applications')
          .where('jobId', isEqualTo: jobId)
          .where('recruiterId', isEqualTo: user!.uid)
          .get();

      dev.log('[2025-08-08 20:48 IST] Fetched ${snapshot.docs.length} applicants for job $jobId by user ${user!.uid}', name: 'PostedJobsScreen');

      final applicants = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['resume']?['name']?.toString() ?? 'Unknown Seeker',
          'resumeUrl': data['resume']?['cvUrl']?.toString() ?? 'N/A',
        };
      }).toList();

      return {'count': snapshot.docs.length, 'applicants': applicants};
    } catch (e, stackTrace) {
      dev.log('[2025-08-08 20:48 IST] Error fetching applicant data for job $jobId by user ${user!.uid}: $e', name: 'PostedJobsScreen', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        dev.log('[2025-08-08 20:48 IST] Firebase error details: ${e.code} - ${e.message}', name: 'PostedJobsScreen');
        if (e.code == 'permission-denied') {
          dev.log('[2025-08-08 20:48 IST] Permission denied accessing Applications for job $jobId', name: 'PostedJobsScreen');
        }
      }
      return {'count': 0, 'applicants': []};
    }
  }

  void _confirmDeleteJob(BuildContext context, String jobId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: const Text(
            'Delete Job',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        content: const Text('Are you sure you want to delete this job?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.teal)),
          ),
          AnimatedScaleButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final batch = FirebaseFirestore.instance.batch();
                // Delete job
                batch.delete(
                  FirebaseFirestore.instance
                      .collection('Recruiters')
                      .doc(user!.uid)
                      .collection('Jobs')
                      .doc(jobId),
                );
                // Delete applications
                final appsSnapshot = await FirebaseFirestore.instance
                    .collection('Applications')
                    .where('jobId', isEqualTo: jobId)
                    .where('recruiterId', isEqualTo: user!.uid)
                    .get();
                for (var doc in appsSnapshot.docs) {
                  batch.delete(doc.reference);
                }
                // Delete notifications
                final notificationsSnapshot = await FirebaseFirestore.instance
                    .collection('Notifications')
                    .where('jobId', isEqualTo: jobId)
                    .get();
                for (var doc in notificationsSnapshot.docs) {
                  batch.delete(doc.reference);
                }
                await batch.commit();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Job and related data deleted'),
                    backgroundColor: Colors.teal,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                dev.log('[2025-08-08 20:48 IST] Job $jobId and related data deleted by user ${user!.uid}', name: 'PostedJobsScreen');
              } catch (e, stackTrace) {
                dev.log('[2025-08-08 20:48 IST] Error deleting job $jobId: $e', name: 'PostedJobsScreen', error: e, stackTrace: stackTrace);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete job: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade600, Colors.red.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Animated Button Widget
class AnimatedScaleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;

  const AnimatedScaleButton({required this.onPressed, required this.child, super.key});

  @override
  AnimatedScaleButtonState createState() => AnimatedScaleButtonState();
}

class AnimatedScaleButtonState extends State<AnimatedScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// Custom Animated List Item Widget
class AnimatedListItem extends StatefulWidget {
  final Widget child;

  const AnimatedListItem({required this.child, super.key});

  @override
  AnimatedListItemState createState() => AnimatedListItemState();
}

class AnimatedListItemState extends State<AnimatedListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _slideAnimation = Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}