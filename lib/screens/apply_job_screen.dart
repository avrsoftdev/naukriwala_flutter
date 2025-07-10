import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as dev;

class ApplyJobScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final String recruiterId;
  final Map<String, dynamic>? seekerProfile;

  const ApplyJobScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.recruiterId,
    this.seekerProfile,
  });

  @override
  ApplyJobScreenState createState() => ApplyJobScreenState();
}

class ApplyJobScreenState extends State<ApplyJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _coverLetterController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _seekerProfile;

  @override
  void initState() {
    super.initState();
    _seekerProfile = widget.seekerProfile;
    if (_seekerProfile == null) _fetchSeekerProfile();
  }

  Future<void> _fetchSeekerProfile() async {
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
      } else {
        _showSnackBar('Please complete your profile before applying');
      }
    } catch (e) {
      dev.log('Error fetching seeker profile: $e', name: 'ApplyJobScreen', error: e);
      _showSnackBar('Error loading profile');
    }
  }

  Future<bool> _checkJobEligibility() async {
    try {
      final jobDoc = await FirebaseFirestore.instance
          .collection('Recruiters')
          .doc(widget.recruiterId)
          .collection('Jobs')
          .doc(widget.jobId)
          .get();

      if (!jobDoc.exists || jobDoc.data()?['status'] != 'open') {
        _showSnackBar('This job is no longer available');
        return false;
      }

      if (_seekerProfile == null) {
        _showSnackBar('Profile data not available');
        return false;
      }

      final jobData = jobDoc.data()!;
      final jobSkills = (jobData['skills'] as List<dynamic>?)?.cast<String>() ?? [];
      final seekerSkills = (_seekerProfile!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
      final jobEducation = jobData['education']?.toString().toLowerCase() ?? '';
      final seekerEducation = _seekerProfile!['education']?.toString().toLowerCase() ?? '';
      final jobExperience = _parseExperience(jobData['experience']?.toString() ?? '0');
      final seekerExperience = _parseExperience(_seekerProfile!['experience']?.toString() ?? '0');

      bool skillsMatch = jobSkills.isEmpty || seekerSkills.any((s) => jobSkills.contains(s));
      bool educationMatch = jobEducation.isEmpty || seekerEducation.contains(jobEducation);
      bool experienceMatch = seekerExperience >= jobExperience;

      if (!skillsMatch || !educationMatch || !experienceMatch) {
        _showSnackBar('You are not eligible for this job');
        return false;
      }

      return true;
    } catch (e) {
      dev.log('Error checking job eligibility: $e', name: 'ApplyJobScreen', error: e);
      _showSnackBar('Error checking eligibility');
      return false;
    }
  }

  double _parseExperience(String exp) {
    try {
      final match = RegExp(r'\d+').firstMatch(exp);
      return double.tryParse(match?.group(0) ?? '0') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _applyForJob() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _showSnackBar('Please log in to apply');

    if (user.uid == widget.recruiterId) {
      return _showSnackBar('You cannot apply for your own job');
    }

    if (_seekerProfile == null) {
      return _showSnackBar('Profile data not available');
    }

    final isEligible = await _checkJobEligibility();
    if (!isEligible) return;

    setState(() => _isLoading = true);

    try {
      final applicationData = {
        'jobId': widget.jobId,
        'jobTitle': widget.jobTitle,
        'seekerId': user.uid,
        'recruiterId': widget.recruiterId,
        'coverLetter': _coverLetterController.text.trim(),
        'status': 'Applied',
        'appliedAt': FieldValue.serverTimestamp(),
        'resume': {
          'name': _seekerProfile!['name'],
          'email': _seekerProfile!['email'],
          'mobileNumber': _seekerProfile!['mobileNumber'],
          'skills': _seekerProfile!['skills'],
          'education': _seekerProfile!['education'],
          'experience': _seekerProfile!['experience'],
          'specialization': _seekerProfile!['specialization'],
          'currentCompany': _seekerProfile!['currentCompany'],
          'currentCtc': _seekerProfile!['currentCtc'],
          'expectedCtc': _seekerProfile!['expectedCtc'],
          'photoUrl': _seekerProfile!['photoUrl'],
        },
      };

      // Recruiter-centric
      await FirebaseFirestore.instance
          .collection('Applications')
          .doc(widget.jobId)
          .collection('AppliedJobs')
          .doc(user.uid)
          .set(applicationData);

      // Seeker-centric
      await FirebaseFirestore.instance
          .collection('Applications')
          .doc(user.uid)
          .collection('AppliedJobs')
          .doc(widget.jobId)
          .set(applicationData);

      // ApplicationsIndex
      await FirebaseFirestore.instance
          .collection('ApplicationsIndex')
          .doc('${widget.recruiterId}_${user.uid}')
          .set({'status': 'active'}, SetOptions(merge: true));

      // Notification
      final notificationId = FirebaseFirestore.instance
          .collection('SeekerNotifications')
          .doc(widget.recruiterId)
          .collection('Notifications')
          .doc()
          .id;
      await FirebaseFirestore.instance
          .collection('SeekerNotifications')
          .doc(widget.recruiterId)
          .collection('Notifications')
          .doc(notificationId)
          .set({
            'to': widget.recruiterId,
            'from': user.uid,
            'message': 'New application for "${widget.jobTitle}" from ${_seekerProfile!['name']}',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'application',
            'jobId': widget.jobId,
            'read': false,
            'notificationId': notificationId,
          });

      dev.log("Application and notification $notificationId submitted for job ${widget.jobId} by ${user.uid}", name: 'ApplyJobScreen');
      _showSnackBar('Application submitted successfully');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      dev.log('Error applying for job ${widget.jobId}: $e', name: 'ApplyJobScreen', error: e);
      if (e is FirebaseException) {
        _showSnackBar('Failed to apply: ${e.code} - ${e.message}');
      } else {
        _showSnackBar('Failed to apply');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    _coverLetterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Apply for ${widget.jobTitle}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text('Cover Letter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _coverLetterController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Write your cover letter here...',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Please enter a cover letter' : null,
                    ),
                    const SizedBox(height: 20),
                    if (_seekerProfile != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Resume Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text('Name: ${_seekerProfile!['name'] ?? ''}'),
                          Text('Email: ${_seekerProfile!['email'] ?? ''}'),
                          Text('Skills: ${(_seekerProfile!['skills'] as List?)?.join(', ') ?? ''}'),
                          Text('Education: ${_seekerProfile!['education'] ?? ''}'),
                          Text('Experience: ${_seekerProfile!['experience'] ?? ''}'),
                        ],
                      ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _applyForJob,
                        icon: const Icon(Icons.send),
                        label: const Text('Submit Application'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}