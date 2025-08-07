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
  bool _isCheckingEligibility = false;
  Map<String, dynamic>? _seekerProfile;

  // Specialization options (same as PostJobScreen)
  final List<String> specializationOptions = [
    'Computer Science / IT',
    'Electronics / Electrical / Robotics',
    'Mechanical / Civil / Architecture',
    'Business / Finance / Management',
    'Medicine / Healthcare / Pharma',
    'Law / Political Science / Public Administration',
    'Arts / Humanities / Education',
    'Design / Media / Communication',
    'Hotel / Travel / Event Management',
    'Science / Research / Environment',
    'Others',
  ];

  // Skills by specialization (same as PostJobScreen)
  final Map<String, List<String>> skillsBySpecialization = {
    'Computer Science / IT': [
      'Java', 'Python', 'C++', 'C#', 'Dart', 'Flutter', 'Android Development',
      'iOS Development', 'React', 'Angular', 'Vue.js', 'Node.js', 'Firebase',
      'AWS', 'Docker', 'Kubernetes', 'SQL', 'MongoDB', 'REST APIs', 'GraphQL',
      'Machine Learning', 'Data Structures & Algorithms', 'DevOps', 'Cybersecurity',
      'System Design',
    ],
    'Electronics / Electrical / Robotics': [
      'Embedded Systems', 'PCB Design', 'VLSI', 'MATLAB', 'Simulink', 'Verilog',
      'FPGA Programming', 'Arduino', 'Raspberry Pi', 'IoT Development',
      'Signal Processing', 'Power Systems', 'Automation', 'SCADA',
    ],
    'Mechanical / Civil / Architecture': [
      'AutoCAD', 'SolidWorks', 'CATIA', 'ANSYS', 'STAAD Pro', 'Revit',
      'Structural Analysis', 'Thermodynamics', 'Manufacturing Processes',
      'Fluid Mechanics', 'Construction Management', 'Urban Planning',
    ],
    'Business / Finance / Management': [
      'Financial Analysis', 'Accounting', 'MS Excel', 'Tally', 'Business Intelligence',
      'SAP', 'QuickBooks', 'Digital Marketing', 'Google Ads', 'SEO',
      'Social Media Marketing', 'Project Management', 'Agile', 'Scrum',
      'Business Strategy', 'Market Research', 'Customer Relationship Management (CRM)',
      'Salesforce',
    ],
    'Medicine / Healthcare / Pharma': [
      'Clinical Research', 'Patient Care', 'Surgical Assistance', 'Nursing Procedures',
      'Medical Coding', 'Public Health', 'Pharmacology', 'First Aid', 'CPR',
      'Health Education', 'Lab Testing', 'Radiology', 'Therapeutic Skills',
    ],
    'Law / Political Science / Public Administration': [
      'Legal Research', 'Case Analysis', 'Contract Drafting', 'Litigation',
      'Legal Compliance', 'Constitutional Law', 'Criminal Law', 'International Law',
      'Arbitration', 'Policy Analysis', 'Public Speaking',
    ],
    'Arts / Humanities / Education': [
      'Creative Writing', 'Content Writing', 'Linguistics', 'Public Speaking',
      'Editing & Proofreading', 'Critical Thinking', 'Classroom Management',
      'Curriculum Development', 'E-Learning Tools', 'Art History', 'Philosophical Analysis',
    ],
    'Design / Media / Communication': [
      'Adobe Photoshop', 'Adobe Illustrator', 'Adobe XD', 'Figma', 'Canva',
      'UI/UX Design', 'Video Editing', '3D Modeling', 'Motion Graphics', 'Photography',
      'Copywriting', 'Branding', 'Social Media Content Creation', 'Typography', 'Storyboarding',
      'Final Cut Pro', 'Lightroom',
    ],
    'Hotel / Travel / Event Management': [
      'Event Planning', 'Hospitality Management', 'Customer Service', 'Bartending',
      'Housekeeping', 'Food & Beverage Service', 'Travel Planning', 'Ticketing & Reservations',
      'Catering Services', 'Inventory Management', 'Public Relations', 'Vendor Management',
    ],
    'Science / Research / Environment': [
      'Laboratory Techniques', 'Statistical Analysis', 'Research Writing', 'Data Collection',
      'Environmental Impact Assessment', 'Geographic Information System (GIS)', 'Microscopy',
      'Chemical Analysis', 'Climate Modeling', 'Bioinformatics',
    ],
    'Others': [
      'Communication Skills', 'Problem Solving', 'Teamwork', 'Leadership', 'Time Management',
      'Adaptability', 'Creativity', 'Conflict Resolution', 'Critical Thinking', 'Customer Support',
      'Basic Computer Skills', 'Typing', 'Remote Work Tools (Zoom, Slack, Trello)', 'Virtual Assistant',
      'Content Moderation',
    ],
  };

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
      setState(() => _isLoading = true);
      final profile = await _authService.fetchProfileData(isRecruiter: false);
      if (profile != null && mounted) {
        // Ensure specialization is valid
        if (profile['specialization'] != null && !specializationOptions.contains(profile['specialization'])) {
          profile['specialization'] = 'Others';
        }
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkJobEligibility() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      dev.log('No authenticated user for eligibility check', name: 'ApplyJobScreen');
      _showSnackBar('Please log in to apply');
      return false;
    }

    try {
      setState(() => _isCheckingEligibility = true);
      // Check if application already exists
      final applicationIndexDoc = await FirebaseFirestore.instance
          .collection('ApplicationsIndex')
          .doc('${currentUser.uid}_${widget.jobId}')
          .get();
      if (applicationIndexDoc.exists) {
        dev.log('ApplicationsIndex/${currentUser.uid}_${widget.jobId} already exists', name: 'ApplyJobScreen');
        _showSnackBar('You have already applied for this job');
        return false;
      } else {
        dev.log('ApplicationsIndex/${currentUser.uid}_${widget.jobId} does not exist', name: 'ApplyJobScreen');
      }

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
        _showSnackBar('Profile data not available. Please complete your profile.');
        return false;
      }

      // Validate required profile fields
      if (_seekerProfile!['name'] == null || _seekerProfile!['name'].toString().trim().isEmpty ||
          _seekerProfile!['email'] == null || _seekerProfile!['email'].toString().trim().isEmpty ||
          _seekerProfile!['skills'] == null || (_seekerProfile!['skills'] as List).isEmpty ||
          _seekerProfile!['education'] == null || _seekerProfile!['education'].toString().trim().isEmpty ||
          _seekerProfile!['experience'] == null || _seekerProfile!['experience'].toString().trim().isEmpty ||
          _seekerProfile!['specialization'] == null || _seekerProfile!['specialization'].toString().trim().isEmpty) {
        dev.log('Incomplete seeker profile: $_seekerProfile', name: 'ApplyJobScreen');
        _showSnackBar('Please complete your profile (name, email, skills, education, experience, specialization) before applying.');
        return false;
      }

      final jobData = jobDoc.data()!;
      final jobSkills = (jobData['skills'] as List<dynamic>?)?.cast<String>() ?? [];
      final seekerSkills = (_seekerProfile!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
      final jobEducation = jobData['education']?.toString().toLowerCase() ?? '';
      final seekerEducation = _seekerProfile!['education']?.toString().toLowerCase() ?? '';
      final jobSpecialization = jobData['specialization']?.toString() ?? 'Others';
      final seekerSpecialization = _seekerProfile!['specialization']?.toString() ?? 'Others';
      final jobExperience = _parseExperience(jobData['experience']?.toString() ?? '0');
      final seekerExperience = _parseExperience(_seekerProfile!['experience']?.toString() ?? '0');

      // Validate specialization
      bool specializationMatch = jobSpecialization == 'Others' || seekerSpecialization == jobSpecialization;
      if (!specializationMatch) {
        // Allow partial match if seeker has skills from the job's specialization
        final jobSkillsSet = skillsBySpecialization[jobSpecialization] ?? skillsBySpecialization['Others']!;
        specializationMatch = seekerSkills.any((s) => jobSkillsSet.contains(s));
      }

      // Validate skills (at least one skill must match if job specifies skills)
      bool skillsMatch = jobSkills.isEmpty || seekerSkills.any((s) => jobSkills.contains(s));
      bool educationMatch = jobEducation.isEmpty || seekerEducation.contains(jobEducation);
      bool experienceMatch = seekerExperience >= jobExperience;

      dev.log('Eligibility check for job ${widget.jobId}: specializationMatch=$specializationMatch, skillsMatch=$skillsMatch, educationMatch=$educationMatch, experienceMatch=$experienceMatch', name: 'ApplyJobScreen');
      dev.log('Job skills: $jobSkills, Seeker skills: $seekerSkills', name: 'ApplyJobScreen');
      dev.log('Job education: $jobEducation, Seeker education: $seekerEducation', name: 'ApplyJobScreen');
      dev.log('Job specialization: $jobSpecialization, Seeker specialization: $seekerSpecialization', name: 'ApplyJobScreen');
      dev.log('Job experience: $jobExperience, Seeker experience: $seekerExperience', name: 'ApplyJobScreen');

      if (!specializationMatch || !skillsMatch || !educationMatch || !experienceMatch) {
        _showSnackBar('You are not eligible for this job based on specialization, skills, education, or experience.');
        return false;
      }

      return true;
    } catch (e) {
      dev.log('Error checking job eligibility for ${widget.jobId}: $e', name: 'ApplyJobScreen', error: e);
      if (e is FirebaseException && e.code == 'permission-denied') {
        dev.log('Permission denied reading Recruiters/${widget.recruiterId}/Jobs/${widget.jobId} or ApplicationsIndex/${currentUser.uid}_${widget.jobId}', name: 'ApplyJobScreen');
        _showSnackBar('Permission denied: Cannot access job details. Ensure your profile is complete or contact support. Path: ${e.message?.split(' ').last}');
      } else {
        _showSnackBar('Error checking eligibility: $e');
      }
      return false;
    } finally {
      if (mounted) setState(() => _isCheckingEligibility = false);
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
      _showSnackBar('Profile data not available. Please complete your profile.');
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
          'specialization': _seekerProfile!['specialization'] ?? 'Others',
          'currentCompany': _seekerProfile!['currentCompany'] ?? '',
          'currentCtc': _seekerProfile!['currentCtc'] ?? '',
          'expectedCtc': _seekerProfile!['expectedCtc'] ?? '',
          'photoUrl': _seekerProfile!['photoUrl'] ?? '',
          'cvUrl': _seekerProfile!['cvUrl'] ?? '',
        },
      };

      dev.log('Submitting application for job ${widget.jobId}: $applicationData', name: 'ApplyJobScreen');
      await _authService.applyToJob(widget.jobId, widget.recruiterId, applicationData);
      dev.log('Application submitted for job ${widget.jobId} by ${user.uid}', name: 'ApplyJobScreen');
      _showSnackBar('Application submitted successfully');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      dev.log('Error applying for job ${widget.jobId}: $e', name: 'ApplyJobScreen', error: e);
      if (e is FirebaseException) {
        dev.log('Firebase error details: code=${e.code}, message=${e.message}, path=Applications/${widget.jobId}/AppliedJobs or ApplicationsIndex/${user.uid}_${widget.jobId} or RecruiterNotifications/${widget.recruiterId}/Notifications', name: 'ApplyJobScreen');
        if (e.code == 'permission-denied') {
          _showSnackBar('Permission denied: Unable to submit application. Ensure your profile is complete or contact support. Path: ${e.message?.split(' ').last}');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          action: message.contains('Permission denied')
              ? SnackBarAction(
                  label: 'Contact Support',
                  onPressed: () {
                    dev.log('User clicked Contact Support', name: 'ApplyJobScreen');
                    // TODO: Implement support contact logic (e.g., open email client or support page)
                  },
                )
              : null,
        ),
      );
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
      body: _isLoading || _isCheckingEligibility
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
                          Text('Name: ${_seekerProfile!['name'] ?? 'N/A'}'),
                          Text('Email: ${_seekerProfile!['email'] ?? 'N/A'}'),
                          Text('Mobile Number: ${_seekerProfile!['mobileNumber'] ?? 'N/A'}'),
                          Text('Skills: ${(_seekerProfile!['skills'] as List?)?.join(', ') ?? 'N/A'}'),
                          Text('Education: ${_seekerProfile!['education'] ?? 'N/A'}'),
                          Text('Experience: ${_seekerProfile!['experience'] ?? 'N/A'}'),
                          Text('Specialization: ${_seekerProfile!['specialization'] ?? 'N/A'}'),
                          Text('Current Company: ${_seekerProfile!['currentCompany'] ?? 'N/A'}'),
                          Text('Current CTC: ${_seekerProfile!['currentCtc'] ?? 'N/A'}'),
                          Text('Expected CTC: ${_seekerProfile!['expectedCtc'] ?? 'N/A'}'),
                        ],
                      )
                    else
                      const Text('Loading profile...', style: TextStyle(fontSize: 16, color: Colors.grey)),
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