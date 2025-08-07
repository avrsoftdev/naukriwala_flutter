import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    fetchSeekerProfile();
    fetchJobsFromFirestore();
    _searchController.addListener(() => _filterJobs(_searchController.text));
  }

  Future<void> fetchSeekerProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

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
        }
      }
    } catch (e, stackTrace) {
      dev.log('Error fetching seeker profile: $e', name: 'SearchJobScreen', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> fetchJobsFromFirestore() async {
    try {
      dev.log('Fetching jobs with collection group query, emulator: ${kDebugMode ? "localhost:8080" : "default"}', name: 'SearchJobScreen');
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

      dev.log('Fetched ${snapshot.docs.length} jobs, docs: ${snapshot.docs.map((d) => d.id).toList()}', name: 'SearchJobScreen');
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
      dev.log('Error fetching jobs: $e, stack: ${StackTrace.current}', name: 'SearchJobScreen', error: e, stackTrace: stackTrace);
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

      dev.log('Job: ${job['title']}, Skills match: $skillsMatch, Education match: $educationMatch, Experience match: $experienceMatch',
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

  Future<bool> _hasApplied(String jobId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Applications')
          .doc(jobId)
          .collection('AppliedJobs')
          .doc(uid)
          .get();
      return doc.exists;
    } catch (e, stackTrace) {
      dev.log('Error checking application status: $e', name: 'SearchJobScreen', error: e, stackTrace: stackTrace);
      return false;
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

  Future<void> _applyToJob(Map<String, dynamic> job) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to apply'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final hasApplied = await _hasApplied(job['jobId']);
    if (hasApplied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already applied for this job'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      await Navigator.push(
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stackTrace) {
      dev.log('Error applying to job: $e', name: 'SearchJobScreen', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isSeekerProfileView ? 'Available Jobs' : 'Search & Available Jobs',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Card(
                    elevation: 4,
                    color: Colors.red.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (!widget.isSeekerProfileView)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by job title, company, or location',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.search, color: Colors.teal),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.teal, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: _filterJobs,
                        ),
                      ),
                    Expanded(
                      child: filteredJobs.isEmpty
                          ? Center(
                              child: Text(
                                'No jobs found matching your skills, education, or experience.',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredJobs.length,
                              itemBuilder: (context, index) {
                                final job = filteredJobs[index];
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
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(16.0),
                                        title: Text(
                                          job['title'] ?? 'Untitled',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black87),
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            '${job['company'] ?? ''} • ${job['location'] ?? ''} • ${job['jobType'] ?? ''}',
                                            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                                          ),
                                        ),
                                        trailing: FutureBuilder<bool>(
                                          future: _hasApplied(job['jobId']),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                              return const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                                              );
                                            }
                                            final hasApplied = snapshot.data ?? false;
                                            return AnimatedScaleButton(
                                              onPressed: hasApplied ? null : () => _applyToJob(job),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: hasApplied
                                                        ? [Colors.grey.shade400, Colors.grey.shade600]
                                                        : [Colors.blue.shade700, Colors.teal.shade400],
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
                                                child: Text(
                                                  hasApplied ? 'Applied' : 'Apply',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
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