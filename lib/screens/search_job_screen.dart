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
      final seekerDoc = await FirebaseFirestore.instance
          .collection('Seekers')
          .doc(currentUser.uid)
          .get();

      if (seekerDoc.exists && mounted) {
        setState(() {
          _seekerProfile = seekerDoc.data();
        });
      }
    } catch (e) {
      dev.log('Error fetching seeker profile: $e', name: 'SearchJobScreen', error: e);
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
    } catch (e) {
      dev.log('Error fetching jobs: $e, stack: ${StackTrace.current}', name: 'SearchJobScreen', error: e);
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load jobs: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load jobs: $e')),
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
    } catch (e) {
      dev.log('Error checking application status: $e', name: 'SearchJobScreen', error: e);
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
          const SnackBar(content: Text('Please log in to apply')),
        );
      }
      return;
    }

    final hasApplied = await _hasApplied(job['jobId']);
    if (hasApplied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already applied for this job')),
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
            seekerProfile: _seekerProfile, // Pass seeker profile
          ),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted successfully')),
        );
      }
    } catch (e) {
      dev.log('Error applying to job: $e', name: 'SearchJobScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply: $e')),
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
        title: Text(widget.isSeekerProfileView ? 'Available Jobs' : 'Search & Available Jobs'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    if (!widget.isSeekerProfileView)
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            labelText: 'Search by job title, company, or location',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    Expanded(
                      child: filteredJobs.isEmpty
                          ? const Center(child: Text('No jobs found matching your skills, education, or experience.'))
                          : ListView.builder(
                              itemCount: filteredJobs.length,
                              itemBuilder: (context, index) {
                                final job = filteredJobs[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: ListTile(
                                    title: Text(job['title'] ?? 'Untitled'),
                                    subtitle: Text(
                                      '${job['company'] ?? ''} • ${job['location'] ?? ''} • ${job['jobType'] ?? ''}',
                                    ),
                                    trailing: FutureBuilder<bool>(
                                      future: _hasApplied(job['jobId']),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const CircularProgressIndicator(strokeWidth: 2);
                                        }
                                        final hasApplied = snapshot.data ?? false;
                                        return ElevatedButton(
                                          onPressed: hasApplied ? null : () => _applyToJob(job),
                                          child: Text(hasApplied ? 'Applied' : 'Apply'),
                                        );
                                      },
                                    ),
                                    onTap: () => _navigateToJobDetails(job),
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