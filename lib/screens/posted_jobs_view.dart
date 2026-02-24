import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:naukariwala/screens/edit_job_screen.dart';
import 'dart:developer' as dev;
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PostedJobsScreen extends StatefulWidget {
  const PostedJobsScreen({super.key});

  @override
  State<PostedJobsScreen> createState() => _PostedJobsScreenState();
}

class _PostedJobsScreenState extends State<PostedJobsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _filter = 'All Jobs';

  static const List<String> _filters = <String>[
    'All Jobs',
    'Featured Jobs',
    'Non-Featured Jobs',
  ];

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

    if (_filter == 'Featured Jobs') {
      jobsQuery = jobsQuery.where('isFeatured', isEqualTo: true);
    } else if (_filter == 'Non-Featured Jobs') {
      jobsQuery = jobsQuery.where('isFeatured', isEqualTo: false);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        title: Text(
          'My Posted Jobs',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 20.sp),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8EEF8), Color(0xFFF6F9FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
              child: _buildFilterChips(),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: jobsQuery.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    dev.log(
                      '[2025-09-01 15:05 IST] Stream error for user ${user!.uid}: ${snapshot.error}',
                      name: 'PostedJobsScreen',
                      error: snapshot.error,
                    );
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
                        elevation: 2,
                        color: Colors.red.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Text(
                            errorMessage,
                            style: TextStyle(color: Colors.red.shade700, fontSize: 14.sp),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }

                  final jobs = snapshot.data?.docs ?? [];
                  final featuredCount = jobs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['isFeatured'] == true;
                  }).length;

                  if (jobs.isEmpty) {
                    return Center(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 20.w),
                        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 22.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 12.r,
                              offset: Offset(0, 4.h),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.work_outline_rounded, size: 34.sp, color: Colors.blueGrey.shade400),
                            SizedBox(height: 10.h),
                            Text(
                              'No jobs posted yet',
                              style: TextStyle(fontSize: 16.sp, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Create a new job post to start receiving applications.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13.sp, color: Colors.blueGrey.shade400),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                        child: _buildSummaryBanner(
                          totalJobs: jobs.length,
                          featuredJobs: featuredCount,
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                          itemCount: jobs.length,
                          separatorBuilder: (_, index) => SizedBox(height: 10.h),
                          itemBuilder: (context, index) {
                            final job = jobs[index].data() as Map<String, dynamic>;
                            final jobId = jobs[index].id;
                            final isFeatured = job['isFeatured'] ?? false;
                            dev.log(
                              '[2025-09-01 15:05 IST] Job $jobId data for user ${user!.uid}: isFeatured=$isFeatured, title=${job['title']}',
                              name: 'PostedJobsScreen',
                            );

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
                            final postedDate =
                                timestamp != null ? DateFormat('dd MMM yyyy').format(timestamp.toDate()) : 'N/A';

                            return FutureBuilder<Map<String, dynamic>>(
                              future: _getApplicantData(jobId),
                              builder: (context, applicantSnapshot) {
                                final applicantCount = applicantSnapshot.data?['count'] ?? 0;
                                final applicants = applicantSnapshot.data?['applicants'] ?? [];

                                return AnimatedListItem(
                                  child: _buildJobCard(
                                    context: context,
                                    jobId: jobId,
                                    job: job,
                                    title: title,
                                    company: company,
                                    location: location,
                                    salary: salary,
                                    skills: skills,
                                    education: education,
                                    experience: experience,
                                    specialization: specialization,
                                    status: status.toString().toLowerCase(),
                                    postedDate: postedDate,
                                    isFeatured: isFeatured == true,
                                    applicantCount: applicantCount,
                                    applicants: applicants,
                                    hasApplicantError: applicantSnapshot.hasError,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12.r,
            offset: Offset(0, 3.h),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: _filters.map((filter) {
          final isSelected = _filter == filter;
          return ChoiceChip(
            label: Text(filter, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                _filter = filter;
              });
              dev.log('[2025-09-01 15:05 IST] Filter changed to: $_filter', name: 'PostedJobsScreen');
            },
            backgroundColor: const Color(0xFFE7EEF8),
            selectedColor: const Color(0xFF1565C0),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF0D47A1),
            ),
            checkmarkColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryBanner({
    required int totalJobs,
    required int featuredJobs,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics_outlined, color: Colors.white, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              '$totalJobs jobs found  •  $featuredJobs featured',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13.sp,
              ),
            ),
          ),
          Text(
            _filter,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
              fontSize: 11.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard({
    required BuildContext context,
    required String jobId,
    required Map<String, dynamic> job,
    required String title,
    required String company,
    required String location,
    required String salary,
    required String skills,
    required String education,
    required String experience,
    required String specialization,
    required String status,
    required String postedDate,
    required bool isFeatured,
    required int applicantCount,
    required List<dynamic> applicants,
    required bool hasApplicantError,
  }) {
    final bool isOpen = status == 'open';

    return Card(
      elevation: 2.5,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: const BorderSide(color: Color(0xFF0D47A1), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: ExpansionTile(
          tilePadding: EdgeInsets.fromLTRB(14.w, 12.h, 6.w, 4.h),
          childrenPadding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          iconColor: const Color(0xFF1565C0),
          collapsedIconColor: const Color(0xFF1565C0),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: const Color(0xFF102A43)),
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: isOpen ? const Color(0xFFE6F6EC) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: isOpen ? const Color(0xFF217A3D) : const Color(0xFFC62828),
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 10.h, right: 10.w, bottom: 6.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _metaChip(Icons.apartment_rounded, company),
                    _metaChip(Icons.location_on_outlined, location),
                    _metaChip(Icons.currency_rupee_rounded, salary),
                    if (isFeatured) _metaChip(Icons.star_rounded, 'Featured', highlighted: true),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Icon(Icons.people_alt_outlined, size: 16.sp, color: Colors.blueGrey.shade500),
                    SizedBox(width: 6.w),
                    Text(
                      '$applicantCount applicants',
                      style: TextStyle(fontSize: 12.sp, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 12.w),
                    Icon(Icons.schedule_rounded, size: 16.sp, color: Colors.blueGrey.shade500),
                    SizedBox(width: 6.w),
                    Text(
                      postedDate,
                      style: TextStyle(fontSize: 12.sp, color: Colors.blueGrey.shade700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: const Color(0xFF1565C0), size: 22.sp),
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditJobScreen(
                      jobId: jobId,
                      jobData: {...job, 'jobId': jobId},
                    ),
                  ),
                );
              } else if (value == 'delete') {
                _confirmDeleteJob(context, jobId);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit', style: TextStyle(color: Color(0xFF1565C0))),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          children: [
            Divider(height: 1.h, color: const Color(0xFFDCE6F3)),
            SizedBox(height: 10.h),
            _buildDetailRow('Skills', skills),
            _buildDetailRow('Education', education),
            _buildDetailRow('Experience', experience),
            _buildDetailRow('Specialization', specialization),
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Applicants',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: const Color(0xFF102A43)),
              ),
            ),
            SizedBox(height: 8.h),
            if (hasApplicantError)
              _buildApplicantInfoCard(
                icon: Icons.error_outline_rounded,
                text: 'Error loading applicants',
                color: Colors.red.shade600,
                background: Colors.red.shade50,
              )
            else if (applicants.isNotEmpty)
              ...applicants.map<Widget>((applicant) {
                final name = applicant['name']?.toString() ?? 'Unknown Seeker';
                final resume = applicant['resumeUrl']?.toString() ?? 'N/A';
                return Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6FAFF),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: const Color(0xFFDCE6F3)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14.r,
                          backgroundColor: const Color(0xFF1565C0),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF243B53)),
                              ),
                              Text(
                                'Resume: $resume',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11.sp, color: Colors.blueGrey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              })
            else
              _buildApplicantInfoCard(
                icon: Icons.inbox_outlined,
                text: 'No applicants yet',
                color: Colors.blueGrey.shade600,
                background: const Color(0xFFEFF4FA),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, {bool highlighted = false}) {
    final background = highlighted ? const Color(0xFFFFF8E1) : const Color(0xFFEAF2FD);
    final foreground = highlighted ? const Color(0xFFB26A00) : const Color(0xFF0D47A1);
    return Container(
      constraints: BoxConstraints(maxWidth: 220.w),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: foreground),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: foreground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90.w,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 12.sp, color: Colors.blueGrey.shade500, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12.sp, color: const Color(0xFF243B53)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantInfoCard({
    required IconData icon,
    required String text,
    required Color color,
    required Color background,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.sp, color: color, fontWeight: FontWeight.w600),
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

