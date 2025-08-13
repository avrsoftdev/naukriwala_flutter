import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:naukariwala/screens/apply_job_screen.dart';
import 'package:naukariwala/screens/job_details_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class SearchJobScreen extends StatefulWidget {
  final bool isSeekerProfileView;

  const SearchJobScreen({super.key, this.isSeekerProfileView = false});

  @override
  SearchJobScreenState createState() => SearchJobScreenState();
}

class SearchJobScreenState extends State<SearchJobScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> jobs = [];
  List<Map<String, dynamic>> filteredJobs = [];
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? _seekerProfile;
  // Track applied jobs
  final Set<String> _appliedJobIds = {};

  @override
  void initState() {
    super.initState();
    fetchSeekerProfile();
    fetchJobsFromFirestore();
    _searchController.addListener(() => _filterJobs(_searchController.text));
    dev.log('[2025-08-08 22:12 IST] SearchJobScreen initialized, isSeekerProfileView: ${widget.isSeekerProfileView}', name: 'SearchJobScreen');
  }

  Future<void> fetchSeekerProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      dev.log('[2025-08-08 22:12 IST] No authenticated user', name: 'SearchJobScreen');
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('UsersIndex')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && mounted) {
        final seekerDoc = await FirebaseFirestore.instance
            .collection('Seekers')
            .doc(currentUser.uid)
            .get();
        if (seekerDoc.exists) {
          setState(() {
            _seekerProfile = seekerDoc.data();
          });
          // Fetch applied jobs for the user
          final applications = await FirebaseFirestore.instance
              .collection('Applications')
              .where('seekerId', isEqualTo: currentUser.uid)
              .get();
          setState(() {
            _appliedJobIds.addAll(applications.docs.map((doc) => doc['jobId'] as String));
          });
          dev.log('[2025-08-08 22:12 IST] Fetched seeker profile for ${currentUser.uid}', name: 'SearchJobScreen');
        } else {
          dev.log('[2025-08-08 22:12 IST] No seeker profile found for ${currentUser.uid}', name: 'SearchJobScreen');
        }
      }
    } catch (e, stackTrace) {
      dev.log('[2025-08-08 22:12 IST] Error fetching seeker profile: $e', name: 'SearchJobScreen', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> fetchJobsFromFirestore() async {
    try {
      dev.log('[2025-08-08 22:12 IST] Fetching jobs with collection group query, emulator: ${kDebugMode ? "localhost:8080" : "default"}', name: 'SearchJobScreen');
      if (kDebugMode) {
        FirebaseFirestore.instance.settings = const Settings(
          host: 'localhost:8080',
          sslEnabled: false,
          persistenceEnabled: false,
        );
      }
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('Jobs')
          .where('status', isEqualTo: 'open')
          .orderBy('createdAt', descending: true)
          .get();

      dev.log('[2025-08-08 22:12 IST] Fetched ${snapshot.docs.length} jobs, docs: ${snapshot.docs.map((d) => d.id).toList()}', name: 'SearchJobScreen');
      final jobList = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'jobId': doc.id,
          'recruiterId': data['recruiterId'],
          'postedAt': (data['createdAt'] as Timestamp?)?.toDate(),
        };
      }).toList();

      if (mounted) {
        setState(() {
          jobs = jobList;
          filteredJobs = _filterJobsByProfile(jobList);
          isLoading = false;
          errorMessage = null;
        });
      }
    } catch (e, stackTrace) {
      dev.log('[2025-08-08 22:12 IST] Error fetching jobs: $e', name: 'SearchJobScreen', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load jobs: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load jobs: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _filterJobsByProfile(List<Map<String, dynamic>> jobList) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (_seekerProfile == null || currentUser == null || jobList.isEmpty || currentUser.uid == jobList.first['recruiterId']?.toString()) {
      return jobList;
    }

    return jobList.where((job) {
      final jobSkills = (job['skills'] as List<dynamic>?)?.cast<String>() ?? [];
      final seekerSkills = (_seekerProfile!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
      final jobEducation = job['education']?.toString().toLowerCase() ?? '';
      final seekerEducation = _seekerProfile!['education']?.toString().toLowerCase() ?? '';
      final jobExperience = _parseExperience(job['experience']?.toString() ?? '0');
      final seekerExperience = _parseExperience(_seekerProfile!['experience']?.toString() ?? '0');

      bool skillsMatch = jobSkills.isEmpty || seekerSkills.any((skill) => jobSkills.contains(skill));
      bool educationMatch = jobEducation.isEmpty || seekerEducation.contains(jobEducation);
      bool experienceMatch = seekerExperience >= jobExperience;

      dev.log('[2025-08-08 22:12 IST] Job: ${job['title']}, Skills match: $skillsMatch, Education match: $educationMatch, Experience match: $experienceMatch',
          name: 'SearchJobScreen');

      return skillsMatch && educationMatch && experienceMatch;
    }).toList();
  }

  double _parseExperience(String experience) {
    try {
      final match = RegExp(r'\d+').firstMatch(experience);
      return double.parse(match?.group(0) ?? '0');
    } catch (e) {
      return 0;
    }
  }

  void _filterJobs(String query) {
    _searchQuery = query.toLowerCase();
    if (_searchQuery.isEmpty) {
      setState(() => filteredJobs = _filterJobsByProfile(jobs));
      return;
    }

    final results = _filterJobsByProfile(jobs).where((job) {
      final title = (job['title'] ?? '').toString().toLowerCase();
      final company = (job['company'] ?? '').toString().toLowerCase();
      final location = (job['location'] ?? '').toString().toLowerCase();
      return title.contains(_searchQuery) ||
          company.contains(_searchQuery) ||
          location.contains(_searchQuery);
    }).toList();

    setState(() => filteredJobs = results);
  }

  Future<void> _applyToJob(Map<String, dynamic> job) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please log in to apply',
              style: TextStyle(fontSize: 14.sp),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ApplyJobScreen(
            jobId: job['jobId'],
            recruiterId: job['recruiterId'],
            jobTitle: job['title'] ?? 'Untitled',
            seekerProfile: _seekerProfile,
          ),
        ),
      );
      if (mounted && result == true) {
        setState(() {
          _appliedJobIds.add(job['jobId']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Application submitted successfully',
              style: TextStyle(fontSize: 14.sp),
            ),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stackTrace) {
      dev.log('[2025-08-08 22:12 IST] Error navigating to ApplyJobScreen: $e', name: 'SearchJobScreen', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to apply: $e',
              style: TextStyle(fontSize: 14.sp),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _navigateToJobDetails(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailsScreen(job: job),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(360, 640), minTextAdapt: true, splitScreenMode: true);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isSeekerProfileView ? 'Available Jobs' : 'Search & Available Jobs',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20.sp),
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
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Card(
                    elevation: 4,
                    color: Colors.red.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    child: Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 16.sp),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (!widget.isSeekerProfileView)
                      Padding(
                        padding: EdgeInsets.all(16.r),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by job title, company, or location',
                            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14.sp),
                            prefixIcon: Icon(Icons.search, color: Colors.teal, size: 20.sp),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: Colors.teal, width: 2.w),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          ),
                          style: TextStyle(fontSize: 16.sp),
                          onChanged: _filterJobs,
                        ),
                      ),
                    Expanded(
                      child: filteredJobs.isEmpty
                          ? Center(
                              child: Text(
                                'No jobs found matching your skills, education, or experience.',
                                style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredJobs.length,
                              itemBuilder: (context, index) {
                                final job = filteredJobs[index];
                                final isApplied = _appliedJobIds.contains(job['jobId']);
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
                                      child: ListTile(
                                        contentPadding: EdgeInsets.all(16.r),
                                        title: Text(
                                          job['title'] ?? 'Untitled',
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18.sp, color: Colors.black87),
                                        ),
                                        subtitle: Padding(
                                          padding: EdgeInsets.only(top: 8.h),
                                          child: Text(
                                            '${job['company'] ?? ''} • ${job['location'] ?? ''} • ${job['jobType'] ?? ''}',
                                            style: TextStyle(color: Colors.grey.shade700, fontSize: 14.sp),
                                          ),
                                        ),
                                        trailing: AnimatedScaleButton(
                                          onPressed: isApplied ? null : () => _applyToJob(job),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: isApplied
                                                    ? [Colors.grey.shade400, Colors.grey.shade600]
                                                    : [Colors.blue.shade700, Colors.teal.shade400],
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
                                            child: Text(
                                              isApplied ? 'Applied' : 'Apply',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.sp,
                                              ),
                                            ),
                                          ),
                                        ),
                                        onTap: () => _navigateToJobDetails(job),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

// Custom Animated Button Widget
class AnimatedScaleButton extends StatefulWidget {
  final VoidCallback? onPressed;
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
      onTapDown: widget.onPressed != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onPressed != null
          ? (_) {
              _controller.reverse();
              widget.onPressed!();
            }
          : null,
      onTapCancel: widget.onPressed != null ? () => _controller.reverse() : null,
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