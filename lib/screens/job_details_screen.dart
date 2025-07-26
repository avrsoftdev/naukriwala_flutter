import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as dev;
import 'apply_job_screen.dart';
import 'edit_job_screen.dart';

class JobDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const JobDetailsScreen({super.key, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  Stream<QuerySnapshot>? _applicantsStream;
  Stream<QuerySnapshot>? _notificationsStream;
  Map<String, dynamic>? _seekerProfile;
  Map<String, dynamic>? _jobData;
  bool _isJobVisible = false;
  bool _isLoading = true;
  String? _ineligibilityReason;
  bool _hasApplied = false;

  @override
  void initState() {
    super.initState();
    _fetchJobAndProfile();
    _fetchApplicants();
    _fetchNotifications();
  }

  Future<void> _fetchJobAndProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _isJobVisible = false;
        _ineligibilityReason = 'Please log in to view this job.';
      });
      return;
    }

    try {
      // Fetch job details to verify existence and status
      final jobDoc = await FirebaseFirestore.instance
          .collection('Recruiters')
          .doc(widget.job['recruiterId']?.toString())
          .collection('Jobs')
          .doc(widget.job['jobId']?.toString())
          .get();

      if (!jobDoc.exists || jobDoc.data()?['status'] != 'open') {
        setState(() {
          _isLoading = false;
          _isJobVisible = false;
          _ineligibilityReason = 'This job is no longer available.';
        });
        return;
      }

      // Update job data with latest from Firestore
      _jobData = {...widget.job, ...jobDoc.data()!};

      // Check if seeker has already applied
      final hasApplied = await _checkApplicationStatus();

      if (currentUser.uid == widget.job['recruiterId']?.toString()) {
        setState(() {
          _isLoading = false;
          _isJobVisible = true;
          _hasApplied = hasApplied;
        });
        return;
      }

      // Fetch seeker profile
      final seekerDoc = await FirebaseFirestore.instance
          .collection('Seekers')
          .doc(currentUser.uid)
          .get();

      if (!seekerDoc.exists) {
        setState(() {
          _isLoading = false;
          _isJobVisible = false;
          _ineligibilityReason = 'Please complete your profile to view this job.';
        });
        return;
      }

      setState(() {
        _seekerProfile = seekerDoc.data();
        _isJobVisible = _checkJobCompatibility();
        _hasApplied = hasApplied;
        _isLoading = false;
        if (!_isJobVisible) {
          _ineligibilityReason = _getIneligibilityReason();
        }
      });
    } catch (e) {
      dev.log('Error fetching job or profile: $e', name: 'JobDetailsScreen');
      setState(() {
        _isLoading = false;
        _isJobVisible = false;
        _ineligibilityReason = 'Failed to load job or profile: $e';
      });
    }
  }

  Future<bool> _checkApplicationStatus() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    dev.log('No authenticated user for application status check', name: 'JobDetailsScreen');
    return false;
  }
  try {
    dev.log('Checking application status for job ${widget.job['jobId']} and seeker ${currentUser.uid} using seeker-side path', name: 'JobDetailsScreen');
    final doc = await FirebaseFirestore.instance
        .collection('Applications')
        .doc(currentUser.uid) // Seeker-side path
        .collection('AppliedJobs')
        .doc(widget.job['jobId']?.toString())
        .get();
    final exists = doc.exists;
    dev.log('Application status for job ${widget.job['jobId']}: exists=$exists', name: 'JobDetailsScreen');
    return exists;
  } catch (e) {
    dev.log('Error checking application status for job ${widget.job['jobId']}: $e', name: 'JobDetailsScreen', error: e);
    return false;
  }
}

  Future<void> _fetchApplicants() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != widget.job['recruiterId']?.toString()) return;
    setState(() {
      _applicantsStream = FirebaseFirestore.instance
          .collection('Applications')
          .doc(widget.job['jobId']?.toString())
          .collection('AppliedJobs')
          .snapshots();
    });
  }

  Future<void> _fetchNotifications() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    setState(() {
      _notificationsStream = FirebaseFirestore.instance
          .collection('Notifications')
          .where('to', isEqualTo: currentUser.uid)
          .snapshots();
    });
  }

  bool _checkJobCompatibility() {
    if (_seekerProfile == null || _jobData == null) return false;

    final jobSkills = (_jobData!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
    final seekerSkills = (_seekerProfile!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
    final jobEducation = _jobData!['education']?.toString().toLowerCase() ?? '';
    final seekerEducation = _seekerProfile!['education']?.toString().toLowerCase() ?? '';
    final jobExperience = _parseExperience(_jobData!['experience']?.toString() ?? '0');
    final seekerExperience = _parseExperience(_seekerProfile!['experience']?.toString() ?? '0');

    bool skillsMatch = jobSkills.isEmpty || seekerSkills.any((skill) => jobSkills.contains(skill));
    bool educationMatch = jobEducation.isEmpty || seekerEducation.contains(jobEducation);
    bool experienceMatch = seekerExperience >= jobExperience;

    dev.log('Skills match: $skillsMatch, Education match: $educationMatch, Experience match: $experienceMatch',
        name: 'JobDetailsScreen');

    return skillsMatch && educationMatch && experienceMatch;
  }

  String _getIneligibilityReason() {
    if (_seekerProfile == null || _jobData == null) {
      return 'Unable to verify eligibility due to missing profile or job data.';
    }

    final jobSkills = (_jobData!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
    final seekerSkills = (_seekerProfile!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
    final jobEducation = _jobData!['education']?.toString().toLowerCase() ?? '';
    final seekerEducation = _seekerProfile!['education']?.toString().toLowerCase() ?? '';
    final jobExperience = _parseExperience(_jobData!['experience']?.toString() ?? '0');
    final seekerExperience = _parseExperience(_seekerProfile!['experience']?.toString() ?? '0');

    List<String> reasons = [];
    if (jobSkills.isNotEmpty && !seekerSkills.any((skill) => jobSkills.contains(skill))) {
      reasons.add('Your skills do not match the required skills (${jobSkills.join(', ')}).');
    }
    if (jobEducation.isNotEmpty && !seekerEducation.contains(jobEducation)) {
      reasons.add('Your education does not meet the requirement ($jobEducation).');
    }
    if (seekerExperience < jobExperience) {
      reasons.add('Your experience (${seekerExperience.toInt()} years) is less than required ($jobExperience years).');
    }
    return reasons.isEmpty
        ? 'This job does not match your skills, education, or experience.'
        : reasons.join(' ');
  }

  double _parseExperience(String experience) {
    try {
      final match = RegExp(r'\d+').firstMatch(experience);
      return double.parse(match?.group(0) ?? '0');
    } catch (e) {
      return 0;
    }
  }

  void _applyForJob() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to apply')),
        );
      }
      return;
    }
    if (currentUser.uid == widget.job['recruiterId']?.toString()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recruiters cannot apply to their own jobs')),
        );
      }
      return;
    }
    if (_hasApplied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already applied for this job')),
        );
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyJobScreen(
          jobId: widget.job['jobId']?.toString() ?? '',
          jobTitle: widget.job['title']?.toString() ?? 'Unknown Job',
          recruiterId: widget.job['recruiterId']?.toString() ?? '',
          seekerProfile: _seekerProfile, // Pass seeker profile
        ),
      ),
    );
  }

  Future<void> deleteJob() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != widget.job['recruiterId']?.toString()) return;

    try {
      await FirebaseFirestore.instance
          .collection('Recruiters')
          .doc(user.uid)
          .collection('Jobs')
          .doc(widget.job['jobId']?.toString())
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job deleted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete job: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    dev.log('Job data in JobDetailsScreen: ${widget.job}', name: 'JobDetailsScreen');

    final jobTitle = _jobData?['title']?.toString() ?? widget.job['title']?.toString() ?? 'Job Details';
    final company = _jobData?['company']?.toString() ?? widget.job['company']?.toString() ?? 'Unknown Company';
    final location = _jobData?['location']?.toString() ?? widget.job['location']?.toString() ?? 'Unknown Location';
    final jobType = _jobData?['jobType']?.toString() ?? widget.job['jobType']?.toString() ?? 'Unknown Type';
    final salary = _jobData?['salary']?.toString() ?? widget.job['salary']?.toString() ?? 'Not specified';
    final experience = _jobData?['experience']?.toString() ?? widget.job['experience']?.toString() ?? 'N/A';
    final description = _jobData?['description']?.toString() ?? widget.job['description']?.toString() ?? 'No description provided';
    final currentUser = FirebaseAuth.instance.currentUser;
    final isRecruiter = currentUser != null && currentUser.uid == widget.job['recruiterId']?.toString();

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isJobVisible) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Not Available')),
        body: Center(
          child: Text(
            _ineligibilityReason ?? 'This job does not match your skills, education, or experience.',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(jobTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              jobTitle,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('$company • $location • $jobType'),
            const SizedBox(height: 10),
            Text('Salary: $salary'),
            Text('Experience Required: $experience'),
            const SizedBox(height: 20),
            const Text(
              'Job Description',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(description),
            const SizedBox(height: 20),
            if (!isRecruiter && currentUser != null)
              FutureBuilder<bool>(
                future: _checkApplicationStatus(),
                builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  final hasApplied = snapshot.data ?? _hasApplied;
                  return ElevatedButton.icon(
                    onPressed: hasApplied ? null : _applyForJob,
                    icon: const Icon(Icons.send),
                    label: Text(hasApplied ? 'Applied' : 'Apply Now'),
                  );
                },
              ),
            if (isRecruiter)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditJobScreen(
                            jobId: widget.job['jobId']?.toString() ?? '',
                            jobData: _jobData ?? widget.job,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                  ElevatedButton.icon(
                    onPressed: deleteJob,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            if (isRecruiter && _applicantsStream != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Applicants',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: _applicantsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text('No applicants yet.');
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final applicant = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          final resume = applicant['resume'] as Map<String, dynamic>? ?? {};
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(resume['name'] ?? 'Unknown Applicant'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Job: ${applicant['jobTitle'] ?? 'Unknown Job'}'),
                                  Text('Skills: ${(resume['skills'] as List<dynamic>?)?.join(', ') ?? 'N/A'}'),
                                  Text('Education: ${resume['education'] ?? 'N/A'}'),
                                  Text('Experience: ${resume['experience'] ?? 'N/A'}'),
                                  Text('Email: ${resume['email'] ?? 'N/A'}'),
                                  Text('Mobile: ${resume['mobileNumber'] ?? 'N/A'}'),
                                  if (resume['specialization']?.isNotEmpty ?? false)
                                    Text('Specialization: ${resume['specialization']}'),
                                ],
                              ),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Applicant: ${resume['name'] ?? 'Unknown'}'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Job: ${applicant['jobTitle'] ?? 'Unknown Job'}'),
                                          Text('Skills: ${(resume['skills'] as List<dynamic>?)?.join(', ') ?? 'N/A'}'),
                                          Text('Education: ${resume['education'] ?? 'N/A'}'),
                                          Text('Experience: ${resume['experience'] ?? 'N/A'}'),
                                          Text('Email: ${resume['email'] ?? 'N/A'}'),
                                          Text('Mobile: ${resume['mobileNumber'] ?? 'N/A'}'),
                                          Text('Specialization: ${resume['specialization'] ?? 'N/A'}'),
                                          Text('Current Company: ${resume['currentCompany'] ?? 'N/A'}'),
                                          Text('Current CTC: ${resume['currentCtc'] ?? 'N/A'}'),
                                          Text('Expected CTC: ${resume['expectedCtc'] ?? 'N/A'}'),
                                          Text('Cover Letter: ${applicant['coverLetter'] ?? 'N/A'}'),
                                          if (resume['photoUrl']?.isNotEmpty ?? false)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: Image.network(resume['photoUrl'], height: 100, fit: BoxFit.cover),
                                            ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            if (_notificationsStream != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: _notificationsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text('No notifications yet.');
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final notification = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            title: Text(notification['message'] ?? 'Unknown Message'),
                            subtitle: Text('Time: ${notification['timestamp']?.toDate().toString() ?? 'N/A'}'),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}