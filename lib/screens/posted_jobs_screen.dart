import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:naukariwala/screens/post_job_screen.dart';
import 'dart:developer' as dev;
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PostedJobsScreen extends StatefulWidget {
  const PostedJobsScreen({super.key});

  @override
  State<PostedJobsScreen> createState() => _PostedJobsScreenState();
}

class _PostedJobsScreenState extends State<PostedJobsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _filter = 'All Jobs'; // Filter state: All Jobs, Featured Jobs, Non-Featured Jobs

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Card(
            elevation: 4,
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                'User not logged in',
                style: TextStyle(color: Colors.red.shade700, fontSize: 16.sp),
              ),
            ),
          ),
        ),
      );
    }

    dev.log('[2025-09-01 15:05 IST] Current user UID: ${user!.uid}', name: 'PostedJobsScreen');

    Query<Map<String, dynamic>> jobsQuery = FirebaseFirestore.instance
        .collection('Recruiters')
        .doc(user!.uid)
        .collection('Jobs')
        .orderBy('isFeatured', descending: true)
        .orderBy('createdAt', descending: true);

    // Apply filter based on _filter value
    if (_filter == 'Featured Jobs') {
      jobsQuery = jobsQuery.where('isFeatured', isEqualTo: true);
    } else if (_filter == 'Non-Featured Jobs') {
      jobsQuery = jobsQuery.where('isFeatured', isEqualTo: false);
    }

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
      body: Column(
        children: [
          // Filter Dropdown
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: DropdownButton<String>(
              value: _filter,
              isExpanded: true,
              items: ['All Jobs', 'Featured Jobs', 'Non-Featured Jobs']
                  .map((String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: TextStyle(fontSize: 14.sp)),
                      ))
                  .toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _filter = newValue;
                  });
                  dev.log('[2025-09-01 15:05 IST] Filter changed to: $_filter', name: 'PostedJobsScreen');
                }
              },
              underline: Container(
                height: 2.h,
                color: Colors.teal,
              ),
              icon: Icon(Icons.filter_list, size: 20.sp, color: Colors.teal),
              style: TextStyle(color: Colors.black87, fontSize: 14.sp),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                  dev.log('[2025-09-01 15:05 IST] Stream error for user ${user!.uid}: ${snapshot.error}', name: 'PostedJobsScreen', error: snapshot.error);
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Text(
                          errorMessage,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 16.sp),
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
                      style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index].data() as Map<String, dynamic>;
                    final jobId = jobs[index].id;
                    final isFeatured = job['isFeatured'] ?? false;
                    dev.log('[2025-09-01 15:05 IST] Job $jobId data for user ${user!.uid}: isFeatured=$isFeatured, title=${job['title']}', name: 'PostedJobsScreen');

                    final title = job['title'] ?? 'Untitled Job';
                    final company = job['company'] ?? 'Unknown Company';
                    final location = job['location'] ?? 'Unspecified';
                    final salary = job['salary'] ?? 'Not specified';
                    final skills = (job['skills'] as List<dynamic>?)?.join(', ') ?? 'N/A';
                    final education = job['education'] ?? 'N/A';
                    final experience = job['experience'] ?? 'N/A';
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
                            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: ExpansionTile(
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              title,
                                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18.sp, color: Colors.black87),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isFeatured)
                                            Padding(
                                              padding: EdgeInsets.only(left: 8.w),
                                              child: Chip(
                                                label: Text(
                                                  'Featured',
                                                  style: TextStyle(fontSize: 12.sp, color: Colors.white),
                                                ),
                                                backgroundColor: Colors.blue.shade600,
                                                padding: EdgeInsets.symmetric(horizontal: 8.w),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                      decoration: BoxDecoration(
                                        color: status == 'open' ? Colors.green.shade100 : Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(12.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.1),
                                            blurRadius: 2.r,
                                            offset: Offset(0, 1.h),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.bold,
                                          color: status == 'open' ? Colors.green.shade700 : Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: EdgeInsets.only(top: 8.h),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Company: $company', style: TextStyle(color: Colors.grey.shade700, fontSize: 14.sp)),
                                      Text('Location: $location', style: TextStyle(color: Colors.grey.shade700, fontSize: 14.sp)),
                                      Text('Salary: $salary', style: TextStyle(color: Colors.grey.shade700, fontSize: 14.sp)),
                                      Text('Skills: $skills', style: TextStyle(color: Colors.grey.shade700, fontSize: 14.sp)),
                                      Text('Education: $education', style: TextStyle(color: Colors.grey.shade700, fontSize: 14.sp)),
                                      Text('Experience: $experience', style: TextStyle(color: Colors.grey.shade700, fontSize: 14.sp)),
                                      Text('Specialization: $specialization', style: TextStyle(color: Colors.grey.shade700, fontSize: 14.sp)),
                                      Text('Posted: $postedDate', style: TextStyle(color: Colors.grey.shade700, fontSize: 14.sp)),
                                      Text('Applicants: $applicantCount', style: TextStyle(color: Colors.grey.shade700, fontSize: 14.sp)),
                                    ],
                                  ),
                                ),
                                children: applicantSnapshot.hasError
                                    ? [
                                        ListTile(
                                          title: Text(
                                            'Error loading applicants',
                                            style: TextStyle(color: Colors.red.shade700, fontSize: 14.sp),
                                          ),
                                        ),
                                      ]
                                    : applicants.isNotEmpty
                                        ? applicants.map<Widget>((applicant) => ListTile(
                                              title: Text(applicant['name'], style: TextStyle(color: Colors.black87, fontSize: 14.sp)),
                                              subtitle: Text('Resume URL: ${applicant['resumeUrl'] ?? 'N/A'}', style: TextStyle(color: Colors.blue.shade600, fontSize: 12.sp)),
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
          ),
        ],
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

      dev.log('[2025-09-01 15:05 IST] Fetched ${snapshot.docs.length} applicants for job $jobId by user ${user!.uid}', name: 'PostedJobsScreen');

      final applicants = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['resume']?['name']?.toString() ?? 'Unknown Seeker',
          'resumeUrl': data['resume']?['cvUrl']?.toString() ?? 'N/A',
        };
      }).toList();

      return {'count': snapshot.docs.length, 'applicants': applicants};
    } catch (e, stackTrace) {
      dev.log('[2025-09-01 15:05 IST] Error fetching applicant data for job $jobId by user ${user!.uid}: $e', name: 'PostedJobsScreen', error: e, stackTrace: stackTrace);
      if (e is FirebaseException) {
        dev.log('[2025-09-01 15:05 IST] Firebase error details: ${e.code} - ${e.message}', name: 'PostedJobsScreen');
        if (e.code == 'permission-denied') {
          dev.log('[2025-09-01 15:05 IST] Permission denied accessing Applications for job $jobId', name: 'PostedJobsScreen');
        }
      }
      return {'count': 0, 'applicants': []};
    }
  }

  void _confirmDeleteJob(BuildContext context, String jobId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Container(
          padding: EdgeInsets.all(16.w),
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
                final jobRef = FirebaseFirestore.instance
                    .collection('Recruiters')
                    .doc(user!.uid)
                    .collection('Jobs')
                    .doc(jobId);
                batch.delete(jobRef);

                dev.log('[2025-09-01 15:05 IST] Deleting job document at ${jobRef.path}', name: 'PostedJobsScreen');

                final appsSnapshot = await FirebaseFirestore.instance
                    .collection('Applications')
                    .where('jobId', isEqualTo: jobId)
                    .where('recruiterId', isEqualTo: user!.uid)
                    .get();
                for (var doc in appsSnapshot.docs) {
                  batch.delete(doc.reference);
                  dev.log('[2025-09-01 15:05 IST] Queued delete for application at ${doc.reference.path}', name: 'PostedJobsScreen');
                }

                final recruiterNotifsSnapshot = await FirebaseFirestore.instance
                    .collection('RecruiterNotifications')
                    .doc(user!.uid)
                    .collection('Notifications')
                    .where('jobId', isEqualTo: jobId)
                    .get();
                for (var doc in recruiterNotifsSnapshot.docs) {
                  batch.delete(doc.reference);
                  dev.log('[2025-09-01 15:05 IST] Queued delete for recruiter notification at ${doc.reference.path}', name: 'PostedJobsScreen');
                }

                // Attempt to delete seeker notifications, handle permission errors gracefully
                try {
                  final seekerNotifsSnapshot = await FirebaseFirestore.instance
                      .collectionGroup('Notifications')
                      .where('jobId', isEqualTo: jobId)
                      .get();
                  for (var doc in seekerNotifsSnapshot.docs) {
                    batch.delete(doc.reference);
                    dev.log('[2025-09-01 15:05 IST] Queued delete for seeker notification at ${doc.reference.path}', name: 'PostedJobsScreen');
                  }
                } catch (e) {
                  dev.log('[2025-09-01 15:05 IST] Failed to delete seeker notifications for job $jobId: $e', name: 'PostedJobsScreen', error: e);
                }

                await batch.commit();
                dev.log('[2025-09-01 15:05 IST] Batch commit completed for job $jobId', name: 'PostedJobsScreen');

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Job deleted successfully. Some related notifications may persist.'),
                    backgroundColor: Colors.teal,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                dev.log('[2025-09-01 15:05 IST] Job $jobId and related data deleted by user ${user!.uid}', name: 'PostedJobsScreen');
              } catch (e, stackTrace) {
                dev.log('[2025-09-01 15:05 IST] Error deleting job $jobId: $e', name: 'PostedJobsScreen', error: e, stackTrace: stackTrace);
                if (e is FirebaseException) {
                  dev.log('[2025-09-01 15:05 IST] Firebase error details: ${e.code} - ${e.message}', name: 'PostedJobsScreen');
                  if (e.code == 'permission-denied') {
                    dev.log('[2025-09-01 15:05 IST] Permission denied deleting job $jobId or related data', name: 'PostedJobsScreen');
                  }
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete job: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade600, Colors.red.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4.r,
                    offset: Offset(0, 2.h),
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
          )
        ],
      ),
    );
  }
}

class AnimatedScaleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;

  const AnimatedScaleButton({required this.onPressed, required this.child, super.key});

  @override
  AnimatedScaleButtonState createState() => AnimatedScaleButtonState();
}

class AnimatedScaleButtonState extends State<AnimatedScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> scaleAnimation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => controller.forward(),
      onTapUp: (_) {
        controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => controller.reverse(),
      child: ScaleTransition(
        scale: scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

class AnimatedListItem extends StatefulWidget {
  final Widget child;

  const AnimatedListItem({required this.child, super.key});

  @override
  AnimatedListItemState createState() => AnimatedListItemState();
}

class AnimatedListItemState extends State<AnimatedListItem> with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(controller);
    slideAnimation = Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(controller);
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: widget.child,
      ),
    );
  }
}