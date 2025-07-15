
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as dev;
import '../../services/auth_service.dart';

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
  final AuthService _authService = AuthService();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _isLoading = false;
  Map<String, dynamic>? _seekerProfile;

  @override
  void initState() {
    super.initState();
    _seekerProfile = widget.seekerProfile;
    if (_seekerProfile == null) _fetchSeekerProfile();
    _updateFcmToken();
    dev.log('ApplyJobScreen initialized: jobId=${widget.jobId}, recruiterId=${widget.recruiterId}, jobTitle=${widget.jobTitle}', name: 'ApplyJobScreen');
  }

  Future<void> _updateFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        dev.log('No authenticated user for FCM token update', name: 'ApplyJobScreen');
        return;
      }
      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('UsersIndex').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
        dev.log('FCM token updated for ${user.uid}: $token', name: 'ApplyJobScreen');
      } else {
        dev.log('Failed to retrieve FCM token for ${user.uid}', name: 'ApplyJobScreen');
      }
    } catch (e) {
      dev.log('Error updating FCM token: $e', name: 'ApplyJobScreen', error: e);
    }
  }

  Future<void> _fetchSeekerProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      dev.log('No authenticated user found', name: 'ApplyJobScreen');
      _showSnackBar('Please log in to apply');
      return;
    }

    try {
      final profile = await _authService.fetchProfileData(isRecruiter: false);
      if (profile != null && mounted) {
        setState(() {
          _seekerProfile = profile;
        });
        dev.log('Fetched seeker profile for ${currentUser.uid}: $_seekerProfile', name: 'ApplyJobScreen');
      } else {
        dev.log('No profile found for ${currentUser.uid}', name: 'ApplyJobScreen');
        _showSnackBar('Please complete your profile before applying');
      }
    } catch (e) {
      dev.log('Error fetching seeker profile: $e', name: 'ApplyJobScreen', error: e);
      _showSnackBar('Error loading profile: $e');
    }
  }

  Future<bool> _checkJobEligibility() async {
    try {
      // Check if application already exists to allow recruiter profile read
      final applicationIndexDoc = await FirebaseFirestore.instance
          .collection('ApplicationsIndex')
          .doc('${widget.recruiterId}_${FirebaseAuth.instance.currentUser!.uid}')
          .get();

      final jobDoc = await FirebaseFirestore.instance
          .collection('Recruiters')
          .doc(widget.recruiterId)
          .collection('Jobs')
          .doc(widget.jobId)
          .get();

      if (!jobDoc.exists) {
        dev.log('Job ${widget.jobId} does not exist', name: 'ApplyJobScreen');
        _showSnackBar('This job is no longer available');
        return false;
      }
      if (jobDoc.data()?['status'] != 'open') {
        dev.log('Job ${widget.jobId} is not open: status=${jobDoc.data()?['status']}', name: 'ApplyJobScreen');
        _showSnackBar('This job is no longer available');
        return false;
      }

      if (_seekerProfile == null) {
        dev.log('Seeker profile is null', name: 'ApplyJobScreen');
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

      dev.log('Eligibility check for job ${widget.jobId}: skillsMatch=$skillsMatch, educationMatch=$educationMatch, experienceMatch=$experienceMatch', name: 'ApplyJobScreen');
      dev.log('Job skills: $jobSkills, Seeker skills: $seekerSkills', name: 'ApplyJobScreen');
      dev.log('Job education: $jobEducation, Seeker education: $seekerEducation', name: 'ApplyJobScreen');
      dev.log('Job experience: $jobExperience, Seeker experience: $seekerExperience', name: 'ApplyJobScreen');

      if (!skillsMatch || !educationMatch || !experienceMatch) {
        _showSnackBar('You are not eligible for this job');
        return false;
      }

      return true;
    } catch (e) {
      dev.log('Error checking job eligibility for ${widget.jobId}: $e', name: 'ApplyJobScreen', error: e);
      if (e is FirebaseException && e.code == 'permission-denied') {
        dev.log('Permission denied reading Recruiters/${widget.recruiterId}/Jobs/${widget.jobId}. Verify ApplicationsIndex/${widget.recruiterId}_${FirebaseAuth.instance.currentUser!.uid} exists.', name: 'ApplyJobScreen');
        _showSnackBar('Permission denied: Cannot access job details. Apply first or contact support.');
      } else {
        _showSnackBar('Error checking eligibility: $e');
      }
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

  Future<bool> _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final role = await _authService.getUserRole();
    dev.log('User ${user.uid} role: $role', name: 'ApplyJobScreen');
    return role == 'seeker';
  }

  Future<void> _applyForJob() async {
    if (!_formKey.currentState!.validate()) {
      dev.log('Form validation failed', name: 'ApplyJobScreen');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      dev.log('No authenticated user', name: 'ApplyJobScreen');
      _showSnackBar('Please log in to apply');
      return;
    }

    if (user.uid == widget.recruiterId) {
      dev.log('User attempted to apply for their own job', name: 'ApplyJobScreen');
      _showSnackBar('You cannot apply for your own job');
      return;
    }

    if (_seekerProfile == null) {
      dev.log('Seeker profile is null before applying', name: 'ApplyJobScreen');
      _showSnackBar('Profile data not available');
      return;
    }

    if (!await _checkRole()) {
      dev.log('User ${user.uid} does not have seeker role', name: 'ApplyJobScreen');
      _showSnackBar('You must be a seeker to apply for jobs. Please update your role.');
      return;
    }

    final isEligible = await _checkJobEligibility();
    if (!isEligible) {
      dev.log('Seeker is not eligible for job ${widget.jobId}', name: 'ApplyJobScreen');
      return;
    }

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
          'name': _seekerProfile!['name'] ?? '',
          'email': _seekerProfile!['email'] ?? '',
          'mobileNumber': _seekerProfile!['mobileNumber'] ?? '',
          'skills': _seekerProfile!['skills'] ?? [],
          'education': _seekerProfile!['education'] ?? '',
          'experience': _seekerProfile!['experience'] ?? '',
          'specialization': _seekerProfile!['specialization'] ?? '',
          'currentCompany': _seekerProfile!['currentCompany'] ?? '',
          'currentCtc': _seekerProfile!['currentCtc'] ?? '',
          'expectedCtc': _seekerProfile!['expectedCtc'] ?? '',
          'photoUrl': _seekerProfile!['photoUrl'] ?? '',
          'cvUrl': _seekerProfile!['cvUrl'] ?? '',
        },
      };

      await _authService.applyToJob(widget.jobId, widget.recruiterId, applicationData);
      dev.log('Application submitted for job ${widget.jobId} by ${user.uid}', name: 'ApplyJobScreen');
      _showSnackBar('Application submitted successfully');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      dev.log('Error applying for job ${widget.jobId}: $e', name: 'ApplyJobScreen', error: e);
      if (e is FirebaseException) {
        dev.log('Firebase error details: ${e.code} - ${e.message}', name: 'ApplyJobScreen');
        if (e.code == 'permission-denied') {
          dev.log('Permission denied details: Check Firestore rules for Applications, ApplicationsIndex, and RecruiterNotifications', name: 'ApplyJobScreen');
          _showSnackBar('Permission denied: Ensure seeker role is set and Firestore rules allow write to Applications and ApplicationsIndex');
        } else {
          _showSnackBar('Failed to apply: ${e.code} - ${e.message}');
        }
      } else if (e is AuthException) {
        _showSnackBar(e.message);
      } else {
        _showSnackBar('Failed to apply: $e');
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
                          Text('Specialization: ${_seekerProfile!['specialization'] ?? ''}'),
                          Text('Current Company: ${_seekerProfile!['currentCompany'] ?? ''}'),
                          Text('Current CTC: ${_seekerProfile!['currentCtc'] ?? ''}'),
                          Text('Expected CTC: ${_seekerProfile!['expectedCtc'] ?? ''}'),
                        ],
                      ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _applyForJob,
                        icon: const Icon(Icons.send),
                        label: const Text('Submit Application'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}
