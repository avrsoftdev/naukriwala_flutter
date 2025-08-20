import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as dev;
import '../../services/auth_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
  String? _errorMessage;

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
      'Adaptability', 'Creativity', 'Work Ethic', 'Negotiation', 'Decision Making',
      'Emotional Intelligence', 'Presentation Skills',
    ],
  };

  @override
  void initState() {
    super.initState();
    _seekerProfile = widget.seekerProfile;
    // Log Firestore settings for debugging
    dev.log('[2025-08-13 23:31 IST] Firestore settings: ${FirebaseFirestore.instance.settings}',
        name: 'ApplyJobScreen');
    _checkEligibility();
  }

  Future<void> _checkEligibility() async {
    if (mounted) {
      setState(() => _isCheckingEligibility = true);
    }
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      dev.log('[2025-08-13 23:31 IST] Checking eligibility for job ${widget.jobId}, user UID: $uid',
          name: 'ApplyJobScreen');
      if (uid == null) {
        throw const AuthException('User not logged in');
      }
      if (uid != '4IxgjmIy4jReBJIsmxGNDDlE2u82') {
        dev.log('[2025-08-13 23:31 IST] UID mismatch: expected 4IxgjmIy4jReBJIsmxGNDDlE2u82, got $uid',
            name: 'ApplyJobScreen');
      }

      // Check seeker document existence
      final seekerDoc = await FirebaseFirestore.instance
          .collection('Seekers')
          .doc(uid)
          .get();
      dev.log('[2025-08-13 23:31 IST] Seeker document exists: ${seekerDoc.exists}, data: ${seekerDoc.data()}',
          name: 'ApplyJobScreen');

      if (!seekerDoc.exists) {
        throw const AuthException('Seeker profile not found. Please complete your profile.');
      }

      final jobDoc = await FirebaseFirestore.instance
          .collection('Recruiters')
          .doc(widget.recruiterId)
          .collection('Jobs')
          .doc(widget.jobId)
          .get();

      dev.log('[2025-08-13 23:31 IST] Job document exists: ${jobDoc.exists}, data: ${jobDoc.data()}',
          name: 'ApplyJobScreen');
      if (!jobDoc.exists) {
        throw const AuthException('Job does not exist');
      }
      if (jobDoc.data()!['status'] != 'open') {
        throw const AuthException('This job is no longer accepting applications');
      }

      // Check if the seeker has already applied
      final applicationDoc = await FirebaseFirestore.instance
          .collection('Applications')
          .doc('${uid}_${widget.jobId}')
          .get();

      dev.log('[2025-08-13 23:31 IST] Application document exists: ${applicationDoc.exists}, id: ${uid}_${widget.jobId}',
          name: 'ApplyJobScreen');
      if (applicationDoc.exists) {
        throw const AuthException('You have already applied for this job');
      }

      // Extract job requirements
      final jobData = jobDoc.data()!;
      final requiredSkills = (jobData['requiredSkills'] as List<dynamic>?)?.cast<String>().map((s) => s.toLowerCase()).toList() ?? [];
      final minExperience = (jobData['minExperience'] as num?)?.toDouble() ?? 0.0;
      final requiredEducation = (jobData['requiredEducation'] as String?)?.toLowerCase() ?? '';
      final requiredSpecialization = (jobData['requiredSpecialization'] as String?)?.toLowerCase() ?? '';

      // Extract seeker profile data
      final seekerData = seekerDoc.data()!;
      final seekerSkills = seekerData['skills'] is String
          ? seekerData['skills'].split(',').map((s) => s.trim().toLowerCase()).toList()
          : (seekerData['skills'] as List<dynamic>?)?.cast<String>().map((s) => s.toLowerCase()).toList() ?? [];
      final seekerExperience = double.tryParse(seekerData['experience']?.toString() ?? '0') ?? 0.0;
      final seekerEducation = (seekerData['education'] as String?)?.toLowerCase() ?? '';
      final seekerSpecialization = (seekerData['specialization'] as String?)?.toLowerCase() ?? '';

      // Validate skills (at least 30% match)
      if (requiredSkills.isNotEmpty) {
        final matchingSkills = requiredSkills.where((skill) => seekerSkills.contains(skill)).length;
        final skillMatchPercentage = (matchingSkills / requiredSkills.length) * 100;
        if (skillMatchPercentage < 30) {
          throw AuthException('Your skills do not sufficiently match the job requirements. Required: ${requiredSkills.join(', ')}');
        }
      }

      // Validate experience
      if (seekerExperience < minExperience) {
        throw AuthException('You do not meet the experience requirement. Required: $minExperience years');
      }

      // Validate education
      if (requiredEducation.isNotEmpty && seekerEducation != requiredEducation) {
        throw AuthException('Your education does not match the job requirements. Required: $requiredEducation');
      }

      // Validate specialization
      if (requiredSpecialization.isNotEmpty && seekerSpecialization != requiredSpecialization) {
        throw AuthException('Your specialization does not match the job requirements. Required: $requiredSpecialization');
      }

    } catch (e, stackTrace) {
      dev.log('[2025-08-13 23:31 IST] Error checking eligibility for job ${widget.jobId}: $e',
          name: 'ApplyJobScreen', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _errorMessage = e.toString().contains('PERMISSION_DENIED')
            ? 'Unable to verify application status due to permission restrictions. Please contact support.'
            : e.toString().replaceFirst('AuthException: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingEligibility = false);
      }
    }
  }

  Future<void> _applyForJob() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _errorMessage = 'Please enter a cover letter');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() => _errorMessage = 'Please log in to apply');
      }
      return;
    }

    if (_seekerProfile == null) {
      if (mounted) {
        setState(() => _errorMessage = 'Profile not loaded. Please complete your profile in the Profile section.');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      dev.log('[2025-08-13 23:31 IST] Applying for job ${widget.jobId}, seeker profile: $_seekerProfile',
          name: 'ApplyJobScreen');
      String? fcmToken = await _messaging.getToken();
      await _authService.applyToJob(
        jobId: widget.jobId,
        jobTitle: widget.jobTitle,
        recruiterId: widget.recruiterId,
        coverLetter: _coverLetterController.text.trim(),
        seekerProfile: _seekerProfile!,
        fcmToken: fcmToken ?? '',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application submitted successfully'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e, stackTrace) {
      dev.log('[2025-08-13 23:31 IST] Error applying for job ${widget.jobId}: $e',
          name: 'ApplyJobScreen', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _errorMessage = 'Failed to apply: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _coverLetterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Apply for ${widget.jobTitle}', style: TextStyle(fontSize: 20.sp)),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          body: _isLoading || _isCheckingEligibility
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        if (_errorMessage != null)
                          Padding(
                            padding: EdgeInsets.only(bottom: 16.h),
                            child: Card(
                              color: Colors.red.shade50,
                              child: Padding(
                                padding: EdgeInsets.all(12.w),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 16.sp),
                                ),
                              ),
                            ),
                          ),
                        const Text(
                          'Cover Letter',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10.h),
                        TextFormField(
                          controller: _coverLetterController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(color: Colors.teal, width: 2),
                            ),
                            hintText: 'Write your cover letter here...',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty ? 'Please enter a cover letter' : null,
                        ),
                        SizedBox(height: 20.h),
                        if (_seekerProfile != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Resume Details',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 10.h),
                              Text('Name: ${_seekerProfile!['name'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                              Text('Email: ${_seekerProfile!['email'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                              Text('Mobile Number: ${_seekerProfile!['mobileNumber'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                              Text('Skills: ${(_seekerProfile!['skills'] as List?)?.join(', ') ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                              Text('Education: ${_seekerProfile!['education'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                              Text('Experience: ${_seekerProfile!['experience'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                              Text('Specialization: ${_seekerProfile!['specialization'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                              Text('Current Company: ${_seekerProfile!['currentCompany'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                              Text('Current CTC: ${_seekerProfile!['currentCtc'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                              Text('Expected CTC: ${_seekerProfile!['expectedCtc'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                              Text('Resume URL: ${_seekerProfile!['resumeUrl'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                            ],
                          )
                        else
                          Text(
                            'Loading profile...',
                            style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                          ),
                        SizedBox(height: 20.h),
                        Center(
                          child: AnimatedScaleButton(
                            onPressed: _applyForJob,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade700, Colors.teal.shade400],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                                boxShadow: [
                                  BoxShadow(
                                    // ignore: deprecated_member_use
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Submit Application',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}

class AnimatedScaleButton extends StatefulWidget {
  final VoidCallback onPressed;
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
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}