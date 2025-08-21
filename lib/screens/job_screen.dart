// ignore_for_file: deprecated_member_use, unnecessary_null_comparison

import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:naukariwala/screens/apply_job_screen.dart';
import 'package:naukariwala/screens/edit_job_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class JobScreen extends StatefulWidget {
  final bool isSeekerProfileView;

  const JobScreen({super.key, this.isSeekerProfileView = false});

  @override
  JobScreenState createState() => JobScreenState();
}

class JobScreenState extends State<JobScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> jobs = [];
  List<Map<String, dynamic>> filteredJobs = [];
  bool isLoading = true;
  bool isJobDetailsLoading = false;
  String? errorMessage;
  Map<String, dynamic>? _seekerProfile;
  final Set<String> _appliedJobIds = {};
  Map<String, dynamic>? _selectedJob;
  Stream<QuerySnapshot>? _applicantsStream;
  Map<String, dynamic>? _jobData;
  bool _isEligible = false;
  String? _ineligibilityReason;

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
      'Adaptability', 'Creativity', 'Conflict Resolution', 'Critical Thinking', 'Customer Support',
      'Basic Computer Skills', 'Typing', 'Remote Work Tools (Zoom, Slack, Trello)', 'Virtual Assistant',
      'Content Moderation',
    ],
  };

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(() => _filterJobs(_searchController.text));
    dev.log('[2025-08-21 12:55 IST] JobScreen initialized, isSeekerProfileView: ${widget.isSeekerProfileView}', name: 'JobScreen');
  }

  Future<void> _initializeData() async {
    await fetchSeekerProfile();
    if (_seekerProfile != null || FirebaseAuth.instance.currentUser == null) {
      await fetchJobsFromFirestore();
    }
  }

  Future<void> fetchSeekerProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      dev.log('[2025-08-21 12:55 IST] No authenticated user', name: 'JobScreen');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
          final applications = await FirebaseFirestore.instance
              .collection('Applications')
              .where('seekerId', isEqualTo: currentUser.uid)
              .get();
          setState(() {
            _appliedJobIds.addAll(applications.docs.map((doc) => doc['jobId'] as String));
          });
          dev.log('[2025-08-21 12:55 IST] Fetched seeker profile for ${currentUser.uid}', name: 'JobScreen');
          if (mounted && isLoading) {
            await fetchJobsFromFirestore();
          }
        } else {
          dev.log('[2025-08-21 12:55 IST] No seeker profile found for ${currentUser.uid}', name: 'JobScreen');
          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }
        }
      }
    } catch (e, stackTrace) {
      dev.log('[2025-08-21 12:55 IST] Error fetching seeker profile: $e', name: 'JobScreen', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error loading profile: $e';
        });
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
      dev.log('[2025-08-21 12:55 IST] Fetching jobs with collection group query, emulator: ${kDebugMode ? "localhost:8080" : "default"}', name: 'JobScreen');
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

      dev.log('[2025-08-21 12:55 IST] Fetched ${snapshot.docs.length} jobs, docs: ${snapshot.docs.map((d) => d.id).toList()}', name: 'JobScreen');
      final jobList = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'jobId': doc.id,
          'recruiterId': data['recruiterId'],
          'postedAt': (data['createdAt'] as Timestamp?)?.toDate(),
          'isEligible': _seekerProfile != null ? _checkJobCompatibilityForJob(data) : false, // Default to false if no profile
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
    } catch (e, stackTrace) {
      dev.log('[2025-08-21 12:55 IST] Error fetching jobs: $e', name: 'JobScreen', error: e, stackTrace: stackTrace);
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

  Future<void> _selectJob(Map<String, dynamic> job) async {
    setState(() {
      _selectedJob = job;
      isJobDetailsLoading = true;
      _jobData = null;
      _applicantsStream = null;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        isJobDetailsLoading = false;
        _isEligible = false;
        _ineligibilityReason = 'Please log in to view eligibility.';
      });
      return;
    }

    try {
      final jobDoc = await FirebaseFirestore.instance
          .collection('Recruiters')
          .doc(job['recruiterId']?.toString())
          .collection('Jobs')
          .doc(job['jobId']?.toString())
          .get();

      if (!jobDoc.exists || jobDoc.data()?['status'] != 'open') {
        setState(() {
          isJobDetailsLoading = false;
          _isEligible = false;
          _ineligibilityReason = 'This job is no longer available.';
        });
        return;
      }

      _jobData = {...job, ...jobDoc.data()!};

      if (currentUser.uid == job['recruiterId']?.toString()) {
        setState(() {
          isJobDetailsLoading = false;
          _isEligible = true; // Recruiters are always eligible to view
        });
        _fetchApplicants();
        return;
      }

      if (_seekerProfile == null) {
        final seekerDoc = await FirebaseFirestore.instance
            .collection('Seekers')
            .doc(currentUser.uid)
            .get();
        if (!seekerDoc.exists) {
          setState(() {
            isJobDetailsLoading = false;
            _isEligible = false;
            _ineligibilityReason = 'Please complete your profile to determine eligibility.';
          });
          return;
        }
        _seekerProfile = seekerDoc.data()!;
        if (_seekerProfile!['specialization'] != null && !specializationOptions.contains(_seekerProfile!['specialization'])) {
          _seekerProfile!['specialization'] = 'Others';
        }
      }

      setState(() {
        _isEligible = job['isEligible'] ?? _checkJobCompatibility();
        isJobDetailsLoading = false;
        _ineligibilityReason = _isEligible ? null : _getIneligibilityReason();
      });
      _fetchApplicants();
    } catch (e, stackTrace) {
      dev.log('[2025-08-21 12:55 IST] Error fetching job details: $e', name: 'JobScreen', error: e, stackTrace: stackTrace);
      setState(() {
        isJobDetailsLoading = false;
        _isEligible = false;
        _ineligibilityReason = 'Failed to load job details: $e';
      });
    }
  }

  Future<void> _fetchApplicants() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != _selectedJob?['recruiterId']?.toString()) return;
    setState(() {
      _applicantsStream = FirebaseFirestore.instance
          .collection('Applications')
          .doc(_selectedJob?['jobId']?.toString())
          .collection('AppliedJobs')
          .snapshots();
    });
  }

  bool _checkJobCompatibilityForJob(Map<String, dynamic> jobData) {
    if (_seekerProfile == null || jobData == null) return false;

    final jobSkills = (jobData['skills'] as List<dynamic>?)?.cast<String>().map((s) => s.toLowerCase()).toList() ?? [];
    final seekerSkills = (_seekerProfile!['skills'] as List<dynamic>?)?.cast<String>().map((s) => s.toLowerCase()).toList() ?? [];
    final jobEducation = jobData['education']?.toString().toLowerCase() ?? '';
    final seekerEducation = _seekerProfile!['education']?.toString().toLowerCase() ?? '';
    final jobSpecialization = jobData['specialization']?.toString().toLowerCase() ?? '';
    final seekerSpecialization = _seekerProfile!['specialization']?.toString().toLowerCase() ?? '';
    final jobExperience = _parseExperience(jobData['experience']?.toString() ?? '0');
    final seekerExperience = _parseExperience(_seekerProfile!['experience']?.toString() ?? '0');

    final matchingSkills = jobSkills.where((skill) => seekerSkills.contains(skill)).length;
    final skillMatchPercentage = jobSkills.isEmpty ? 100.0 : (matchingSkills / jobSkills.length) * 100;
    final skillsMatch = skillMatchPercentage >= 30;
    final educationMatch = jobEducation.isEmpty || jobEducation == seekerEducation;
    final specializationMatch = jobSpecialization.isEmpty || jobSpecialization == seekerSpecialization;
    final experienceMatch = seekerExperience >= jobExperience;

    dev.log('[2025-08-21 12:55 IST] Pre-check compatibility for job ${jobData['jobId']}: Skills match=$skillsMatch ($skillMatchPercentage%), Education match=$educationMatch, Specialization match=$specializationMatch, Experience match=$experienceMatch',
        name: 'JobScreen');
    return skillsMatch && educationMatch && specializationMatch && experienceMatch;
  }

  bool _checkJobCompatibility() {
    if (_seekerProfile == null || _jobData == null) return false;

    final jobSkills = (_jobData!['skills'] as List<dynamic>?)?.cast<String>().map((s) => s.toLowerCase()).toList() ?? [];
    final seekerSkills = (_seekerProfile!['skills'] as List<dynamic>?)?.cast<String>().map((s) => s.toLowerCase()).toList() ?? [];
    final jobEducation = _jobData!['education']?.toString().toLowerCase() ?? '';
    final seekerEducation = _seekerProfile!['education']?.toString().toLowerCase() ?? '';
    final jobSpecialization = _jobData!['specialization']?.toString().toLowerCase() ?? '';
    final seekerSpecialization = _seekerProfile!['specialization']?.toString().toLowerCase() ?? '';
    final jobExperience = _parseExperience(_jobData!['experience']?.toString() ?? '0');
    final seekerExperience = _parseExperience(_seekerProfile!['experience']?.toString() ?? '0');

    final matchingSkills = jobSkills.where((skill) => seekerSkills.contains(skill)).length;
    final skillMatchPercentage = jobSkills.isEmpty ? 100.0 : (matchingSkills / jobSkills.length) * 100;
    final skillsMatch = skillMatchPercentage >= 30;
    final educationMatch = jobEducation.isEmpty || jobEducation == seekerEducation;
    final specializationMatch = jobSpecialization.isEmpty || jobSpecialization == seekerSpecialization;
    final experienceMatch = seekerExperience >= jobExperience;

    dev.log('[2025-08-21 12:55 IST] Compatibility check for job ${_jobData!['jobId']}: Skills match=$skillsMatch ($skillMatchPercentage%), Education match=$educationMatch, Specialization match=$specializationMatch, Experience match=$experienceMatch',
        name: 'JobScreen');
    return skillsMatch && educationMatch && specializationMatch && experienceMatch;
  }

  String _getIneligibilityReason() {
    if (_seekerProfile == null || _jobData == null) {
      return 'Unable to verify eligibility due to missing profile or job data.';
    }

    final jobSkills = (_jobData!['skills'] as List<dynamic>?)?.cast<String>().map((s) => s.toLowerCase()).toList() ?? [];
    final seekerSkills = (_seekerProfile!['skills'] as List<dynamic>?)?.cast<String>().map((s) => s.toLowerCase()).toList() ?? [];
    final jobEducation = _jobData!['education']?.toString().toLowerCase() ?? '';
    final seekerEducation = _seekerProfile!['education']?.toString().toLowerCase() ?? '';
    final jobSpecialization = _jobData!['specialization']?.toString().toLowerCase() ?? '';
    final seekerSpecialization = _seekerProfile!['specialization']?.toString().toLowerCase() ?? '';
    final jobExperience = _parseExperience(_jobData!['experience']?.toString() ?? '0');
    final seekerExperience = _parseExperience(_seekerProfile!['experience']?.toString() ?? '0');

    List<String> reasons = [];
    if (jobSkills.isNotEmpty) {
      final matchingSkills = jobSkills.where((skill) => seekerSkills.contains(skill)).length;
      final skillMatchPercentage = (matchingSkills / jobSkills.length) * 100;
      if (skillMatchPercentage < 30) {
        reasons.add('Your skills do not match at least 30% of the required skills (${jobSkills.join(', ')}).');
      }
    }
    if (jobEducation.isNotEmpty && jobEducation != seekerEducation) {
      reasons.add('Your education does not match the requirement ($jobEducation).');
    }
    if (jobSpecialization.isNotEmpty && jobSpecialization != seekerSpecialization) {
      reasons.add('Your specialization does not match the requirement ($jobSpecialization).');
    }
    if (seekerExperience < jobExperience) {
      reasons.add('Your experience (${seekerExperience.toInt()} years) is less than required ($jobExperience years).');
    }
    return reasons.isEmpty
        ? 'This job does not match your education, specialization, skills (at least 30%), or experience.'
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
      dev.log('[2025-08-21 12:55 IST] Error navigating to ApplyJobScreen: $e', name: 'JobScreen', error: e, stackTrace: stackTrace);
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

  Future<void> _deleteJob() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != _selectedJob?['recruiterId']?.toString()) return;

    try {
      await FirebaseFirestore.instance
          .collection('Recruiters')
          .doc(user.uid)
          .collection('Jobs')
          .doc(_selectedJob?['jobId']?.toString())
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Job deleted successfully'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _selectedJob = null;
          filteredJobs = filteredJobs.where((job) => job['jobId'] != _selectedJob?['jobId']).toList();
        });
      }
    } catch (e, stackTrace) {
      dev.log('[2025-08-21 12:55 IST] Error deleting job: $e', name: 'JobScreen', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete job: $e'),
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
              : ListView.builder(
                  itemCount: filteredJobs.length,
                  itemBuilder: (context, index) {
                    final job = filteredJobs[index];
                    final isApplied = _appliedJobIds.contains(job['jobId']);
                    Color cardColor = _seekerProfile != null ? (job['isEligible'] == true ? Colors.green.shade100 : Colors.red.shade100) : Colors.grey.shade200;
                    return Column(
                      children: [
                        AnimatedListItem(
                          child: Card(
                            elevation: 3,
                            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            color: cardColor,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [cardColor, cardColor.withOpacity(0.8)],
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
                                onTap: () => _selectJob(job),
                              ),
                            ),
                          ),
                        ),
                        if (_selectedJob != null && _selectedJob!['jobId'] == job['jobId'])
                          isJobDetailsLoading
                              ? Center(
                                  child: CircularProgressIndicator(
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                                  ),
                                )
                              : Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                  child: Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                    child: Padding(
                                      padding: EdgeInsets.all(16.w),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _jobData?['title']?.toString() ?? _selectedJob!['title']?.toString() ?? 'Job Details',
                                            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                          ),
                                          SizedBox(height: 12.h),
                                          Text(
                                            '${_jobData?['company']?.toString() ?? _selectedJob!['company']?.toString() ?? 'Unknown Company'} • '
                                            '${_jobData?['location']?.toString() ?? _selectedJob!['location']?.toString() ?? 'Unknown Location'} • '
                                            '${_jobData?['jobType']?.toString() ?? _selectedJob!['jobType']?.toString() ?? 'Unknown Type'}',
                                            style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade700),
                                          ),
                                          SizedBox(height: 12.h),
                                          Text('Salary: ${_jobData?['salary']?.toString() ?? _selectedJob!['salary']?.toString() ?? 'Not specified'}', style: TextStyle(fontSize: 16.sp)),
                                          Text('Experience Required: ${_jobData?['experience']?.toString() ?? _selectedJob!['experience']?.toString() ?? 'N/A'}', style: TextStyle(fontSize: 16.sp)),
                                          Text('Skills: ${(_jobData?['skills'] as List<dynamic>?)?.cast<String>().join(', ') ?? _selectedJob!['skills']?.toString() ?? 'N/A'}', style: TextStyle(fontSize: 16.sp)),
                                          Text('Education: ${_jobData?['education']?.toString() ?? _selectedJob!['education']?.toString() ?? 'N/A'}', style: TextStyle(fontSize: 16.sp)),
                                          Text('Specialization: ${_jobData?['specialization']?.toString() ?? _selectedJob!['specialization']?.toString() ?? 'N/A'}', style: TextStyle(fontSize: 16.sp)),
                                          SizedBox(height: 20.h),
                                          Text(
                                            'Job Description',
                                            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                          ),
                                          SizedBox(height: 8.h),
                                          Text(
                                            _jobData?['description']?.toString() ?? _selectedJob!['description']?.toString() ?? 'No description provided',
                                            style: TextStyle(fontSize: 16.sp),
                                          ),
                                          SizedBox(height: 20.h),
                                          Text(
                                            _isEligible ? 'Eligible' : 'Non-Eligible',
                                            style: TextStyle(
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.bold,
                                              color: _isEligible ? Colors.green : Colors.red,
                                            ),
                                          ),
                                          if (_ineligibilityReason != null)
                                            Padding(
                                              padding: EdgeInsets.only(top: 8.h),
                                              child: Text(
                                                _ineligibilityReason!,
                                                style: TextStyle(fontSize: 14.sp, color: Colors.red.shade700),
                                              ),
                                            ),
                                          SizedBox(height: 20.h),
                                          if (FirebaseAuth.instance.currentUser?.uid == _selectedJob?['recruiterId']?.toString())
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: [
                                                AnimatedScaleButton(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => EditJobScreen(
                                                          jobId: _selectedJob!['jobId']?.toString() ?? '',
                                                          jobData: _jobData ?? _selectedJob!,
                                                        ),
                                                      ),
                                                    );
                                                  },
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
                                                          color: Colors.black.withValues(alpha: 0.2),
                                                          blurRadius: 4.r,
                                                          offset: Offset(0, 2.h),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.edit, color: Colors.white),
                                                        SizedBox(width: 8.w),
                                                        const Text(
                                                          'Edit',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                AnimatedScaleButton(
                                                  onPressed: _deleteJob,
                                                  child: Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [Colors.red.shade600, Colors.red.shade800],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                      ),
                                                      borderRadius: BorderRadius.circular(12.r),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.2),
                                                          blurRadius: 4.r,
                                                          offset: Offset(0, 2.h),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.delete, color: Colors.white),
                                                        SizedBox(width: 8.w),
                                                        const Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (FirebaseAuth.instance.currentUser?.uid == _selectedJob?['recruiterId']?.toString() && _applicantsStream != null)
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                SizedBox(height: 20.h),
                                                Text(
                                                  'Applicants',
                                                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                                ),
                                                SizedBox(height: 10.h),
                                                StreamBuilder<QuerySnapshot>(
                                                  stream: _applicantsStream,
                                                  builder: (context, snapshot) {
                                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                                      return const Center(
                                                        child: CircularProgressIndicator(
                                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                                                        ),
                                                      );
                                                    }
                                                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                                      return const Text('No applicants yet.', style: TextStyle(fontSize: 16, color: Colors.grey));
                                                    }
                                                    return ListView.builder(
                                                      shrinkWrap: true,
                                                      physics: const NeverScrollableScrollPhysics(),
                                                      itemCount: snapshot.data!.docs.length,
                                                      itemBuilder: (context, index) {
                                                        final applicant = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                                                        final resume = applicant['resume'] as Map<String, dynamic>? ?? {};
                                                        return AnimatedListItem(
                                                          child: Card(
                                                            elevation: 3,
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
                                                                contentPadding: EdgeInsets.all(16.w),
                                                                title: Text(
                                                                  resume['name'] ?? 'Unknown Applicant',
                                                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                                                                ),
                                                                subtitle: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text('Job: ${applicant['jobTitle'] ?? 'Unknown Job'}'),
                                                                    Text('Skills: ${(resume['skills'] as List<dynamic>?)?.cast<String>().join(', ') ?? 'N/A'}'),
                                                                    Text('Education: ${resume['education'] ?? 'N/A'}'),
                                                                    Text('Experience: ${resume['experience'] ?? 'N/A'}'),
                                                                    Text('Specialization: ${resume['specialization'] ?? 'N/A'}'),
                                                                    Text('Email: ${resume['email'] ?? 'N/A'}'),
                                                                    Text('Mobile: ${resume['mobileNumber'] ?? 'N/A'}'),
                                                                  ],
                                                                ),
                                                                onTap: () {
                                                                  showDialog(
                                                                    context: context,
                                                                    builder: (context) => AlertDialog(
                                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                                                                      title: Container(
                                                                        padding: EdgeInsets.all(16.w),
                                                                        decoration: BoxDecoration(
                                                                          gradient: LinearGradient(
                                                                            colors: [Colors.blue.shade700, Colors.blue.shade900],
                                                                            begin: Alignment.topLeft,
                                                                            end: Alignment.bottomRight,
                                                                          ),
                                                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                                                        ),
                                                                        child: Text(
                                                                          'Applicant: ${resume['name'] ?? 'Unknown'}',
                                                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                                        ),
                                                                      ),
                                                                      content: SingleChildScrollView(
                                                                        child: Column(
                                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                                          children: [
                                                                            Text('Job: ${applicant['jobTitle'] ?? 'Unknown Job'}'),
                                                                            Text('Skills: ${(resume['skills'] as List<dynamic>?)?.cast<String>().join(', ') ?? 'N/A'}'),
                                                                            Text('Education: ${resume['education'] ?? 'N/A'}'),
                                                                            Text('Experience: ${resume['experience'] ?? 'N/A'}'),
                                                                            Text('Specialization: ${resume['specialization'] ?? 'N/A'}'),
                                                                            Text('Email: ${resume['email'] ?? 'N/A'}'),
                                                                            Text('Mobile: ${resume['mobileNumber'] ?? 'N/A'}'),
                                                                            Text('Current Company: ${resume['currentCompany'] ?? 'N/A'}'),
                                                                            Text('Current CTC: ${resume['currentCtc'] ?? 'N/A'}'),
                                                                            Text('Expected CTC: ${resume['expectedCtc'] ?? 'N/A'}'),
                                                                            Text('Cover Letter: ${applicant['coverLetter'] ?? 'N/A'}'),
                                                                            if (resume['photoUrl']?.isNotEmpty ?? false)
                                                                              Padding(
                                                                                padding: EdgeInsets.only(top: 8.h),
                                                                                child: ClipRRect(
                                                                                  borderRadius: BorderRadius.circular(8.r),
                                                                                  child: Image.network(resume['photoUrl'], height: 100.h, fit: BoxFit.cover),
                                                                                ),
                                                                              ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                      actions: [
                                                                        TextButton(
                                                                          onPressed: () => Navigator.pop(context),
                                                                          child: const Text('Close', style: TextStyle(color: Colors.teal)),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          if (FirebaseAuth.instance.currentUser?.uid != _selectedJob?['recruiterId']?.toString() && _isEligible)
                                            AnimatedScaleButton(
                                              onPressed: isApplied ? null : () => _applyToJob(_selectedJob!),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: isApplied
                                                        ? [Colors.red.shade700, Colors.green.shade400]
                                                        : [Colors.blue.shade700, Colors.teal.shade400],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  borderRadius: BorderRadius.circular(12.r),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.2),
                                                      blurRadius: 4.r,
                                                      offset: Offset(0, 2.h),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  isApplied ? 'Applied' : 'Apply Now',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16.sp,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                              )
                              ],
                    );
                  },
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