import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as dev;
import '../../services/auth_service.dart' as authService; // Prefix to resolve conflict
import '../../services/auth_middleware.dart';

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
  final authService.AuthService _authService = authService.AuthService();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _isLoading = false;
  Map<String, dynamic>? _seekerProfile;

  @override
  void initState() {
    super.initState();
    _seekerProfile = widget.seekerProfile;
    dev.log('ApplyJobScreen initialized: jobId=${widget.jobId}, recruiterId=${widget.recruiterId}, jobTitle=${widget.jobTitle}, seekerProfileProvided=${_seekerProfile != null}', name: 'ApplyJobScreen');
    if (_seekerProfile == null) _fetchSeekerProfile();
    _updateFcmToken();
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
      await AuthMiddleware.requireRole('seeker');
      final profile = await _authService.fetchProfileData(isRecruiter: false);
      if (profile != null && mounted) {
        setState(() {
          _seekerProfile = profile;
        });
        dev.log('Fetched seeker profile for ${currentUser.uid}: $_seekerProfile', name: 'ApplyJobScreen');
      } else {
        dev.log('No profile found for ${currentUser.uid} after AuthMiddleware', name: 'ApplyJobScreen');
        _showSnackBar('Please complete your profile before applying');
      }
    } catch (e) {
      dev.log('Error fetching seeker profile: $e', name: 'ApplyJobScreen', error: e);
      if (e is FirebaseException && e.code == 'permission-denied') {
        dev.log('Permission denied reading Seekers/${currentUser.uid}', name: 'ApplyJobScreen');
        _showSnackBar('Permission error: Cannot access profile. Contact support.');
      } else if (e is AuthException) {
        _showSnackBar(e.message);
      } else {
        _showSnackBar('Error loading profile: $e');
      }
    }
  }

  Future<bool> _checkJobEligibility() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      dev.log('No authenticated user', name: 'ApplyJobScreen');
      _showSnackBar('Please log in to apply');
      return false;
    }

    try {
      // Check prior application using seeker-side path
      final seekerAppDoc = await FirebaseFirestore.instance
          .collection('Applications')
          .doc(uid)
          .collection('AppliedJobs')
          .doc(widget.jobId)
          .get();
      if (seekerAppDoc.exists) {
        dev.log('Seeker $uid already applied to job ${widget.jobId}', name: 'ApplyJobScreen');
        _showSnackBar('You have already applied to this job');
        return false;
      }

      // Check job existence and status
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
      final jobData = jobDoc.data()!;
      if (jobData['status'] != 'open') {
        dev.log('Job ${widget.jobId} is not open: status=${jobData['status']}', name: 'ApplyJobScreen');
        _showSnackBar('This job is no longer open for applications');
        return false;
      }
      if (jobData['recruiterId'] != widget.recruiterId) {
        dev.log('Job ${widget.jobId} recruiterId mismatch: expected ${widget.recruiterId}, got ${jobData['recruiterId']}', name: 'ApplyJobScreen');
        _showSnackBar('Invalid job details');
        return false;
      }

      if (_seekerProfile == null) {
        dev.log('Seeker profile is null for $uid', name: 'ApplyJobScreen');
        _showSnackBar('Please complete your profile before applying');
        return false;
      }

      // Match job and seeker requirements
      final jobSkills = (jobData['skills'] as List<dynamic>?)?.cast<String>() ?? [];
      final seekerSkills = (_seekerProfile!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
      final jobEducation = jobData['education']?.toString().toLowerCase() ?? '';
      final seekerEducation = _seekerProfile!['education']?.toString().toLowerCase() ?? '';
      final jobExperience = _parseExperience(jobData['experience']?.toString() ?? '0');
      final seekerExperience = _parseExperience(_seekerProfile!['experience']?.toString() ?? '0');

      bool skillsMatch = jobSkills.isEmpty || seekerSkills.any((s) => jobSkills.contains(s));
      bool educationMatch = jobEducation.isEmpty || seekerEducation.isNotEmpty;
      bool experienceMatch = jobExperience == 0 || seekerExperience >= jobExperience;

      dev.log('Eligibility check for job ${widget.jobId}: skillsMatch=$skillsMatch, educationMatch=$educationMatch, experienceMatch=$experienceMatch', name: 'ApplyJobScreen');
      dev.log('Job skills: $jobSkills, Seeker skills: $seekerSkills', name: 'ApplyJobScreen');
      dev.log('Job education: $jobEducation, Seeker education: $seekerEducation', name: 'ApplyJobScreen');
      dev.log('Job experience: $jobExperience, Seeker experience: $seekerExperience', name: 'ApplyJobScreen');

      if (!skillsMatch) {
        dev.log('Seeker $uid ineligible: Skills do not match', name: 'ApplyJobScreen');
        _showSnackBar('Your skills do not match the job requirements');
        return false;
      }
      if (!educationMatch) {
        dev.log('Seeker $uid ineligible: Education does not match', name: 'ApplyJobScreen');
        _showSnackBar('Your education does not meet the job requirements');
        return false;
      }
      if (!experienceMatch) {
        dev.log('Seeker $uid ineligible: Insufficient experience', name: 'ApplyJobScreen');
        _showSnackBar('You do not have enough experience for this job');
        return false;
      }

      return true;
    } catch (e) {
      dev.log('Error checking job eligibility for ${widget.jobId}: $e', name: 'ApplyJobScreen', error: e);
      if (e is FirebaseException && e.code == 'permission-denied') {
        dev.log('Permission denied reading Recruiters/${widget.recruiterId}/Jobs/${widget.jobId}', name: 'ApplyJobScreen');
        _showSnackBar('Permission error: Cannot access job details. Contact support.');
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
      _showSnackBar('Please complete your profile before applying');
      return;
    }

    final isEligible = await _checkJobEligibility();
    if (!isEligible) {
      dev.log('Seeker is not eligible for job ${widget.jobId}', name: 'ApplyJobScreen');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthMiddleware.requireRole('seeker');
      dev.log('Seeker role verified for ${user.uid}', name: 'ApplyJobScreen');

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
      if (e is FirebaseException && e.code == 'permission-denied') {
        dev.log('Permission denied writing to Applications/${widget.jobId} or related paths', name: 'ApplyJobScreen');
        _showSnackBar('Permission error: Cannot submit application. Ensure job is open and contact support.');
      } else if (e is authService.AuthException || e is AuthException) {
        _showSnackBar(e.toString());
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
                        labelText: 'Cover Letter',
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
                          const Text('Profile Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        icon: const Icon(Icons.check),
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