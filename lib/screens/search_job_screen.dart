import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:naukariwala/screens/apply_job_screen.dart';
import 'package:naukariwala/screens/job_details_screen.dart';

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

  @override
  void initState() {
    super.initState();
    fetchJobsFromFirestore();
    _searchController.addListener(() => _filterJobs(_searchController.text));
  }

  Future<void> fetchJobsFromFirestore() async {
  try {
    dev.log('Fetching jobs with collection group query, emulator: localhost:8080', name: 'SearchJobScreen');
    FirebaseFirestore.instance.settings = const Settings(
      host: 'localhost:8080',
      sslEnabled: false,
      persistenceEnabled: false,
    );
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
        filteredJobs = jobList;
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

  void _filterJobs(String query) {
    _searchQuery = query.toLowerCase();
    if (_searchQuery.isEmpty) {
      setState(() => filteredJobs = jobs);
      return;
    }

    final results = jobs.where((job) {
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
    final doc = await FirebaseFirestore.instance
        .collection('Applications')
        .doc(uid)
        .collection('AppliedJobs')
        .doc(jobId)
        .get();
    return doc.exists;
  }

  void _navigateToJobDetails(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailsScreen(job: job),
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
          builder: (_) => ApplyJobScreen(
            jobId: job['jobId'],
            recruiterId: job['recruiterId'],
            jobTitle: job['title'] ?? 'Untitled',
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
                          ? const Center(child: Text('No jobs found.'))
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