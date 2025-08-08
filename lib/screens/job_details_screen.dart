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
  Map<String, dynamic>? _seekerProfile;
  Map<String, dynamic>? _jobData;
  bool _isJobVisible = false;
  bool _isLoading = true;
  String? _ineligibilityReason;
  bool _hasApplied = false;

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
    _fetchJobAndProfile();
    _fetchApplicants();
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

      // Ensure specialization is valid
      final seekerProfile = seekerDoc.data()!;
      if (seekerProfile['specialization'] != null && !specializationOptions.contains(seekerProfile['specialization'])) {
        seekerProfile['specialization'] = 'Others';
      }

      setState(() {
        _seekerProfile = seekerProfile;
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
    if (currentUser == null) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('ApplicationsIndex')
          .doc('${currentUser.uid}_${widget.job['jobId']}')
          .get();
      return doc.exists;
    } catch (e) {
      dev.log('Error checking application status: $e', name: 'JobDetailsScreen');
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

  bool _checkJobCompatibility() {
    if (_seekerProfile == null || _jobData == null) return false;

    final jobSkills = (_jobData!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
    final seekerSkills = (_seekerProfile!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
    final jobEducation = _jobData!['education']?.toString().toLowerCase() ?? '';
    final seekerEducation = _seekerProfile!['education']?.toString().toLowerCase() ?? '';
    final jobSpecialization = _jobData!['specialization']?.toString() ?? 'Others';
    final seekerSpecialization = _seekerProfile!['specialization']?.toString() ?? 'Others';
    final jobExperience = _parseExperience(_jobData!['experience']?.toString() ?? '0');
    final seekerExperience = _parseExperience(_seekerProfile!['experience']?.toString() ?? '0');

    // Check specialization compatibility
    bool specializationMatch = jobSpecialization == 'Others' || seekerSpecialization == jobSpecialization;
    if (!specializationMatch) {
      final jobSkillsSet = skillsBySpecialization[jobSpecialization] ?? skillsBySpecialization['Others']!;
      specializationMatch = seekerSkills.any((s) => jobSkillsSet.contains(s));
    }

    bool skillsMatch = jobSkills.isEmpty || seekerSkills.any((skill) => jobSkills.contains(skill));
    bool educationMatch = jobEducation.isEmpty || seekerEducation.contains(jobEducation);
    bool experienceMatch = seekerExperience >= jobExperience;

    dev.log('Compatibility check for job ${widget.job['jobId']}: specializationMatch=$specializationMatch, skillsMatch=$skillsMatch, educationMatch=$educationMatch, experienceMatch=$experienceMatch',
        name: 'JobDetailsScreen');
    dev.log('Job skills: $jobSkills, Seeker skills: $seekerSkills', name: 'JobDetailsScreen');
    dev.log('Job education: $jobEducation, Seeker education: $seekerEducation', name: 'JobDetailsScreen');
    dev.log('Job specialization: $jobSpecialization, Seeker specialization: $seekerSpecialization', name: 'JobDetailsScreen');
    dev.log('Job experience: $jobExperience, Seeker experience: $seekerExperience', name: 'JobDetailsScreen');

    return specializationMatch && skillsMatch && educationMatch && experienceMatch;
  }

  String _getIneligibilityReason() {
    if (_seekerProfile == null || _jobData == null) {
      return 'Unable to verify eligibility due to missing profile or job data.';
    }

    final jobSkills = (_jobData!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
    final seekerSkills = (_seekerProfile!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
    final jobEducation = _jobData!['education']?.toString().toLowerCase() ?? '';
    final seekerEducation = _seekerProfile!['education']?.toString().toLowerCase() ?? '';
    final jobSpecialization = _jobData!['specialization']?.toString() ?? 'Others';
    final seekerSpecialization = _seekerProfile!['specialization']?.toString() ?? 'Others';
    final jobExperience = _parseExperience(_jobData!['experience']?.toString() ?? '0');
    final seekerExperience = _parseExperience(_seekerProfile!['experience']?.toString() ?? '0');

    List<String> reasons = [];
    if (jobSpecialization != 'Others' && seekerSpecialization != jobSpecialization) {
      final jobSkillsSet = skillsBySpecialization[jobSpecialization] ?? skillsBySpecialization['Others']!;
      if (!seekerSkills.any((s) => jobSkillsSet.contains(s))) {
        reasons.add('Your specialization ($seekerSpecialization) does not match the required specialization ($jobSpecialization).');
      }
    }
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
        ? 'This job does not match your specialization, skills, education, or experience.'
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
          SnackBar(
            content: const Text('Please login to apply'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (currentUser.uid == widget.job['recruiterId']?.toString()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Recruiters cannot apply to their own jobs'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (_hasApplied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You have already applied for this job'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
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
          seekerProfile: _seekerProfile,
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
          SnackBar(
            content: const Text('Job deleted successfully'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
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
  Widget build(BuildContext context) {
    dev.log('Job data in JobDetailsScreen: ${widget.job}', name: 'JobDetailsScreen');

    final jobTitle = _jobData?['title']?.toString() ?? widget.job['title']?.toString() ?? 'Job Details';
    final company = _jobData?['company']?.toString() ?? widget.job['company']?.toString() ?? 'Unknown Company';
    final location = _jobData?['location']?.toString() ?? widget.job['location']?.toString() ?? 'Unknown Location';
    final jobType = _jobData?['jobType']?.toString() ?? widget.job['jobType']?.toString() ?? 'Unknown Type';
    final salary = _jobData?['salary']?.toString() ?? widget.job['salary']?.toString() ?? 'Not specified';
    final experience = _jobData?['experience']?.toString() ?? widget.job['experience']?.toString() ?? 'N/A';
    final skills = (_jobData?['skills'] as List<dynamic>?)?.cast<String>().join(', ') ?? widget.job['skills']?.toString() ?? 'N/A';
    final education = _jobData?['education']?.toString() ?? widget.job['education']?.toString() ?? 'N/A';
    final specialization = _jobData?['specialization']?.toString() ?? widget.job['specialization']?.toString() ?? 'N/A';
    final description = _jobData?['description']?.toString() ?? widget.job['description']?.toString() ?? 'No description provided';
    final currentUser = FirebaseAuth.instance.currentUser;
    final isRecruiter = currentUser != null && currentUser.uid == widget.job['recruiterId']?.toString();

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
          ),
        ),
      );
    }

    if (!_isJobVisible) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Job Not Available',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
        body: Center(
          child: Card(
            elevation: 4,
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _ineligibilityReason ?? 'This job does not match your specialization, skills, education, or experience.',
                style: TextStyle(color: Colors.red.shade700, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          jobTitle,
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Text(
                  jobTitle,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                ),
                const SizedBox(height: 12),
                Text(
                  '$company • $location • $jobType',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                Text('Salary: $salary', style: const TextStyle(fontSize: 16)),
                Text('Experience Required: $experience', style: const TextStyle(fontSize: 16)),
                Text('Skills: $skills', style: const TextStyle(fontSize: 16)),
                Text('Education: $education', style: const TextStyle(fontSize: 16)),
                Text('Specialization: $specialization', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                Text(
                  'Job Description',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                ),
                const SizedBox(height: 8),
                Text(description, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                if (isRecruiter)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      AnimatedScaleButton(
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade700, Colors.teal.shade400],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit, color: Colors.white),
                              const SizedBox(width: 8),
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
                        onPressed: deleteJob,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.red.shade600, Colors.red.shade800],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.delete, color: Colors.white),
                              const SizedBox(width: 8),
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
                const SizedBox(height: 20),
                if (isRecruiter && _applicantsStream != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Applicants',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                      const SizedBox(height: 10),
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
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            title: Container(
                                              padding: const EdgeInsets.all(16),
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
                                                      padding: const EdgeInsets.only(top: 8),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Image.network(resume['photoUrl'], height: 100, fit: BoxFit.cover),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Animated Button Widget
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