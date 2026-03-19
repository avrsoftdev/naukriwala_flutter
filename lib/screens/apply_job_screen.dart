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

  // Test related variables
  Map<String, dynamic>? _jobData;
  List<int?> _selectedAnswerIndices = [];
  bool _testSubmitted = false;

  Set<String> _extractSkillKeywords(List<String> skills) {
    final keywords = <String>{};
    final tokenPattern = RegExp(r'[a-z0-9]+');
    for (final skill in skills) {
      final matches = tokenPattern.allMatches(skill.toLowerCase());
      for (final match in matches) {
        final token = match.group(0);
        if (token != null && token.isNotEmpty) {
          keywords.add(token);
        }
      }
    }
    return keywords;
  }

  final List<String> experienceOptions = [
    'Fresher',
    '1-2 years',
    '2-4 years',
    '4-6 years',
    '6-8 years',
    '8-10 years',
    '10-12 years',
    '12+ years', // Added to cover more experienced candidates
  ];

// Education options
  final List<String> educationOptions = [
    'Secondary (Class 10)',
    'Higher Secondary (Class 12)',
    'Diploma/Certificate',
    'Undergraduate (Bachelor\'s Degree)',
    'Postgraduate Diploma',
    'Postgraduate (Master\'s Degree)',
    'Doctorate/PhD/MPhil',
    'Professional Certification',
    'Vocational Training',
  ];

// Specialization options
  final List<String> specializationOptions = [
    'Computer Science / IT',
    'Artificial Intelligence / Machine Learning / Data Science',
    'Electronics / Electrical / Robotics',
    'Mechanical / Civil / Architecture',
    'Aerospace / Aeronautical / Automotive',
    'Chemical / Petroleum / Environmental',
    'Biomedical / Biotechnology / Nanotechnology',
    'Business / Finance / Management',
    'Medicine / Healthcare / Pharma',
    'Physiotherapy / Public Health / Veterinary Science',
    'Law / Political Science / Public Administration',
    'Arts / Humanities / Education',
    'Design / Media / Communication',
    'Hotel / Travel / Event Management',
    'Science / Research / Environment',
    'Astronomy / Astrophysics / Planetary Science',
    'Vocational/Domestic Services',
    'Others',
  ];

// Skills by specialization
  final Map<String, List<String>> skillsBySpecialization = {
    'Computer Science / IT': [
      'Java', 'Python', 'C++', 'C#', 'Dart', 'Flutter', 'Android Development',
      'iOS Development', 'React', 'Angular', 'Vue.js', 'Node.js', 'Firebase',
      'AWS', 'Azure', 'Google Cloud', 'Docker', 'Kubernetes', 'SQL', 'NoSQL',
      'MongoDB', 'REST APIs', 'GraphQL', 'Data Structures & Algorithms', 'DevOps',
      'Cybersecurity', 'System Design', 'Web Development', 'Unit Testing', 'Git',
      'Jenkins', 'Agile Methodologies',
    ],
    'Artificial Intelligence / Machine Learning / Data Science': [
      'Python', 'R', 'TensorFlow', 'PyTorch', 'Keras', 'Scikit-learn', 'Pandas',
      'NumPy', 'Data Visualization', 'Tableau', 'Power BI', 'Big Data', 'Hadoop',
      'Spark', 'Deep Learning', 'Natural Language Processing', 'Computer Vision',
      'Statistical Modeling', 'Data Mining', 'Machine Learning Algorithms',
      'Time Series Analysis', 'SQL', 'Feature Engineering', 'Model Deployment',
      'Cloud Computing (AWS, Azure)', 'Jupyter Notebooks',
    ],
    'Electronics / Electrical / Robotics': [
      'Embedded Systems', 'PCB Design', 'VLSI', 'MATLAB', 'Simulink', 'Verilog',
      'VHDL', 'FPGA Programming', 'Arduino', 'Raspberry Pi', 'IoT Development',
      'Signal Processing', 'Power Systems', 'Control Systems', 'SCADA', 'PLC Programming',
      'Circuit Design', 'Robotics Programming', 'Sensor Integration', 'Microcontrollers',
      'Power Electronics', 'Automation', 'Proteus', 'Multisim',
      'Calculus', 'Algebra', 'Differential Equations', 'Electromagnetism',
      'Circuit Theory', 'Ohm\'s Law', 'Basic Electrical Components',
      'Power Systems Design', 'C Programming', 'C++ Programming', 'Python Programming',
      'SPICE Simulation', 'System Design & Analysis', 'Troubleshooting Electronics',
      'Microprocessor Design', 'Hardware Applications',
      'Problem-Solving', 'Technical Communication', 'Team Collaboration',
      'Attention to Detail', 'Critical Thinking', 'Creativity in Design',
    ],
    'Mechanical / Civil / Architecture': [
      'AutoCAD', 'SolidWorks', 'CATIA', 'ANSYS', 'STAAD Pro', 'Revit', 'ETABS',
      'Structural Analysis', 'Thermodynamics', 'Fluid Mechanics', 'Manufacturing Processes',
      'Finite Element Analysis', 'Construction Management', 'Urban Planning', 'BIM (Building Information Modeling)',
      'Geotechnical Engineering', 'Hydraulics', 'Surveying', 'CAD/CAM', 'HVAC Design',
      '3D Printing', 'Project Estimation', 'Material Science',
    ],
    'Aerospace / Aeronautical / Automotive': [
      'CATIA', 'ANSYS Fluent', 'SolidWorks', 'MATLAB', 'Aerodynamics', 'Propulsion Systems',
      'Flight Mechanics', 'Automotive Design', 'Vehicle Dynamics', 'CFD (Computational Fluid Dynamics)',
      'Finite Element Analysis', 'Aerospace Materials', 'Avionics', 'AutoCAD', 'Structural Design',
      'Engine Testing', 'CAD/CAM', 'Thermal Analysis', 'Manufacturing Processes', 'Simulation Tools',
    ],
    'Chemical / Petroleum / Environmental': [
      'Aspen HYSYS', 'MATLAB', 'Chemical Process Design', 'Petroleum Refining', 'Environmental Impact Assessment',
      'Waste Management', 'Water Treatment', 'Process Simulation', 'Thermodynamics', 'Mass Transfer',
      'Heat Transfer', 'Piping Design', 'HSE (Health, Safety, Environment)', 'Geochemical Analysis',
      'Reservoir Engineering', 'Pollution Control', 'Sustainable Design', 'Chemical Safety',
    ],
    'Biomedical / Biotechnology / Nanotechnology': [
      'Bioinformatics', 'Molecular Biology', 'Genetic Engineering', 'Cell Culture', 'PCR Techniques',
      'Biomedical Instrumentation', 'Biomaterials', 'Nanoparticle Synthesis', 'Microscopy', 'Lab Techniques',
      'Proteomics', 'Genomics', 'Biomedical Imaging', 'Tissue Engineering', 'Biosensors', 'MATLAB',
      'Biostatistics', 'Drug Delivery Systems', 'Nanofabrication', 'Biochemical Analysis',
    ],
    'Business / Finance / Management': [
      'Financial Analysis', 'Accounting', 'Tally ERP', 'QuickBooks', 'MS Excel', 'SAP FICO',
      'Financial Modeling', 'Taxation', 'Auditing', 'Cost Accounting', 'Business Strategy',
      'Market Research', 'Entrepreneurship Development', 'Investment Analysis', 'Risk Management',
      'Corporate Finance', 'Budgeting', 'Financial Reporting', 'Business Plan Development',
      'Venture Capital Analysis', 'GST Compliance', 'Digital Marketing', 'Google Ads', 'SEO',
      'Social Media Marketing', 'Project Management', 'Agile', 'Scrum', 'Salesforce',
      'Customer Relationship Management (CRM)',
    ],
    'Medicine / Healthcare / Pharma': [
      'Clinical Diagnosis', 'Patient Care', 'Surgical Assistance', 'Nursing Procedures', 'Pharmacology',
      'Medical Coding', 'First Aid', 'CPR', 'Dental Procedures', 'Orthodontics', 'Prescription Management',
      'Clinical Pharmacy', 'Drug Dispensing', 'Wound Care', 'Vital Signs Monitoring', 'Patient Counseling',
      'Anesthesia Administration', 'Infection Control', 'Medical Ethics', 'Health Education',
    ],
    'Physiotherapy / Public Health / Veterinary Science': [
      'Manual Therapy', 'Exercise Prescription', 'Electrotherapy', 'Rehabilitation Techniques',
      'Epidemiology', 'Public Health Policy', 'Health Program Management', 'Community Health',
      'Veterinary Diagnosis', 'Animal Surgery', 'Veterinary Pharmacology', 'Animal Husbandry',
      'Biostatistics', 'Health Promotion', 'Injury Assessment', 'Kinesiology', 'Vaccination Protocols',
      'Zoonotic Disease Management', 'Public Health Surveillance',
    ],
    'Law / Political Science / Public Administration': [
      'Legal Research', 'Case Analysis', 'Contract Drafting', 'Litigation', 'Legal Writing',
      'Constitutional Law Analysis', 'International Law Compliance', 'Arbitration', 'Mediation',
      'Intellectual Property Law', 'Criminal Law Practice', 'Corporate Law', 'Legal Compliance',
      'Courtroom Advocacy', 'Policy Analysis', 'Public Speaking', 'Governance Studies',
      'International Diplomacy', 'Conflict Resolution', 'Public Policy Formulation',
      'Political Research', 'Legislative Analysis', 'International Trade Policy',
      'Geopolitical Analysis', 'Public Administration Management',
    ],
    'Arts / Humanities / Education': [
      'Creative Writing', 'Literary Analysis', 'Historical Research', 'Archival Studies',
      'Philosophical Analysis', 'Critical Thinking', 'Content Writing', 'Editing & Proofreading',
      'Cultural Studies', 'Art Criticism', 'Translation', 'Manuscript Analysis', 'Oral History',
      'Ethnography', 'Research Methodologies', 'Academic Writing', 'Classroom Management',
      'Curriculum Design', 'Lesson Planning', 'E-Learning Tools', 'Pedagogical Techniques',
      'Special Education Strategies', 'Inclusive Education', 'Assessment Design',
      'Educational Technology', 'Student Counseling',
    ],
    'Design / Media / Communication': [
      'Adobe Photoshop', 'Adobe Illustrator', 'Figma', 'Adobe XD', 'Canva', 'UI/UX Design',
      'Fashion Illustration', 'Pattern Making', 'Textile Design', '3D Modeling', 'Blender',
      'SketchUp', 'Graphic Design', 'Typography', 'Branding', 'Motion Graphics', 'Color Theory',
      'Video Editing', 'Adobe Premiere Pro', 'Final Cut Pro', 'Journalism Ethics', 'News Writing',
      'Copywriting', 'Broadcast Journalism', 'Photojournalism', 'Social Media Content Creation',
      'Public Relations', 'Storyboarding', 'Media Production', 'Podcast Production',
    ],
    'Hotel / Travel / Event Management': [
      'Hospitality Management', 'Event Planning', 'Customer Service', 'Food & Beverage Service',
      'Culinary Techniques', 'Menu Planning', 'Bartending', 'Housekeeping Management',
      'Travel Planning', 'Tour Operations', 'Ticketing & Reservations', 'Catering Management',
      'Hotel Operations', 'Guest Relations', 'Inventory Management', 'Sustainable Tourism',
      'Vendor Management', 'Event Logistics', 'Budget Planning', 'Sponsorship Management',
    ],
    'Science / Research / Environment': [
      'Laboratory Techniques', 'Chemical Analysis', 'Microscopy', 'Spectroscopy', 'Experimental Design',
      'Data Analysis', 'Physics Modeling', 'Organic Chemistry', 'Molecular Biology', 'Biochemistry',
      'Quantum Mechanics', 'Thermodynamics', 'Cell Biology', 'Scientific Writing', 'Lab Safety',
      'Instrumentation', 'Environmental Impact Assessment', 'Geographic Information System (GIS)',
      'Remote Sensing', 'Geological Mapping', 'Climate Modeling', 'Marine Biology', 'Oceanography',
      'Environmental Monitoring', 'Soil Analysis', 'Hydrology', 'Biodiversity Conservation',
    ],
    'Astronomy / Astrophysics / Planetary Science': [
      'Astrometry', 'Telescopic Observation', 'Data Analysis', 'Astrostatistics', 'Orbital Mechanics',
      'Stellar Astrophysics', 'Planetary Geology', 'Spectroscopy', 'Computational Modeling',
      'Space Mission Design', 'Astronomical Software (Stellarium, IRAF)', 'Exoplanet Research',
      'Cosmology', 'Radio Astronomy', 'Image Processing',
    ],
    'Vocational/Domestic Services': [
      'Driving', 'Vehicle Operation (Cars, Trucks, Buses)', 'Defensive Driving', 'Route Navigation',
      'Vehicle Maintenance', 'Traffic Regulations', 'GPS Usage', 'Delivery Scheduling', 'Cargo Handling',
      'Housekeeping', 'Cleaning & Sanitation', 'Inventory Stocking', 'Office Management',
      'Document Handling', 'Filing & Organization', 'Basic Computer Skills (MS Office)', 'Errand Running',
      'Office Equipment Maintenance', 'Mail Distribution', 'Reception Duties', 'Woodworking',
      'Furniture Making', 'Carpentry Tools (Saws, Drills, Chisels)', 'Blueprint Reading', 'Wood Finishing',
      'Cabinet Making', 'Framing', 'Joinery', 'Timber Measurement', 'Wood Carving', 'Cooking',
      'Childcare', 'Elderly Care', 'Gardening', 'Landscaping', 'Basic Maintenance', 'Plumbing',
      'Pipe Fitting', 'Electrical Wiring', 'Masonry', 'Painting', 'Welding', 'Construction Labor',
      'Scaffolding', 'Heavy Machinery Operation', 'Forklift Operation', 'Pest Control',
      'Customer Service', 'Time Management', 'Physical Stamina', 'Teamwork', 'Problem-Solving',
      'Work Safety Practices',
    ],
    'Others': [
      'Communication Skills', 'Problem Solving', 'Teamwork', 'Leadership', 'Time Management',
      'Adaptability', 'Creativity', 'Conflict Resolution', 'Critical Thinking', 'Customer Support',
      'Basic Computer Skills', 'Typing', 'Remote Work Tools (Zoom, Slack, Trello)', 'Virtual Assistant',
      'Content Moderation', 'Ethical Analysis', 'Policy Formulation', 'Interdisciplinary Research',
      'Digital Archiving', 'Data Ethics', 'Climate Policy Analysis', 'Stakeholder Engagement',
      'Text Analysis', 'Digital Storytelling', 'Public Policy Research', 'AI Governance',
      'Environmental Ethics', 'Cross-Cultural Analysis',
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

      // Load job data for test question
      _jobData = jobDoc.data()!;
      
      // Initialize selected answer indices for multiple questions
      if (_jobData!['includeTest'] == true) {
        final testQuestions = _jobData!['testQuestions'] as List<dynamic>? ?? [];
        if (testQuestions.isNotEmpty) {
          _selectedAnswerIndices = List.filled(testQuestions.length, null);
        } else if (_jobData!['testQuestion'] != null) {
          // Handle legacy single test question format
          _selectedAnswerIndices = [null];
        }
      }
      
      dev.log('[2025-08-13 23:31 IST] Job data loaded: $_jobData', name: 'ApplyJobScreen');

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

      // Validate skills (at least one keyword match)
      if (requiredSkills.isNotEmpty) {
        final requiredKeywords = _extractSkillKeywords(requiredSkills);
        final seekerKeywords = _extractSkillKeywords(seekerSkills);
        final hasKeywordMatch = requiredKeywords.any(seekerKeywords.contains);
        if (!hasKeywordMatch) {
          throw AuthException('Your skills do not match the job requirements. Required: ${requiredSkills.join(', ')}');
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

    // Check if test is required but not answered
    if (_jobData?['includeTest'] == true) {
      final testQuestions = _jobData!['testQuestions'] as List<dynamic>? ?? [];
      final hasLegacyQuestion = _jobData!['testQuestion'] != null;
      
      if (testQuestions.isNotEmpty) {
        // Check if all questions are answered
        bool allAnswered = true;
        for (int i = 0; i < _selectedAnswerIndices.length; i++) {
          if (_selectedAnswerIndices[i] == null) {
            allAnswered = false;
            break;
          }
        }
        if (!allAnswered) {
          setState(() => _errorMessage = 'Please answer all test questions');
          return;
        }
      } else if (hasLegacyQuestion && _selectedAnswerIndices.isEmpty) {
        setState(() => _errorMessage = 'Please answer the test question');
        return;
      }
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
      
      // Prepare test answer if test exists
      Map<String, dynamic>? testAnswer;
      if (_jobData?['includeTest'] == true) {
        final testQuestions = _jobData!['testQuestions'] as List<dynamic>? ?? [];
        
        if (testQuestions.isNotEmpty) {
          // Handle multiple questions
          final answers = <Map<String, dynamic>>[];
          for (int i = 0; i < testQuestions.length; i++) {
            if (_selectedAnswerIndices[i] != null) {
              final question = testQuestions[i] as Map<String, dynamic>;
              answers.add({
                'question': question['question'],
                'selectedOption': question['options'][_selectedAnswerIndices[i]!],
                'selectedOptionIndex': _selectedAnswerIndices[i]!,
                'correctOption': question['options'][question['correctOptionIndex']],
                'correctOptionIndex': question['correctOptionIndex'],
                'isCorrect': _selectedAnswerIndices[i] == question['correctOptionIndex'],
              });
            }
          }
          testAnswer = {
            'answers': answers,
            'totalQuestions': testQuestions.length,
            'correctAnswers': answers.where((a) => a['isCorrect'] == true).length,
          };
        } else if (_jobData!['testQuestion'] != null && _selectedAnswerIndices.isNotEmpty && _selectedAnswerIndices[0] != null) {
          // Handle legacy single test question format
          final testQuestion = _jobData!['testQuestion'] as Map<String, dynamic>;
          testAnswer = {
            'question': testQuestion['question'],
            'selectedOption': testQuestion['options'][_selectedAnswerIndices[0]!],
            'selectedOptionIndex': _selectedAnswerIndices[0]!,
            'correctOption': testQuestion['options'][testQuestion['correctOptionIndex']],
            'correctOptionIndex': testQuestion['correctOptionIndex'],
            'isCorrect': _selectedAnswerIndices[0] == testQuestion['correctOptionIndex'],
          };
        }
      }
      
      await _authService.applyToJob(
        jobId: widget.jobId,
        jobTitle: widget.jobTitle,
        recruiterId: widget.recruiterId,
        coverLetter: _coverLetterController.text.trim(),
        seekerProfile: _seekerProfile!,
        fcmToken: fcmToken ?? '',
        testAnswer: testAnswer,
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
                        
                        // Test Questions Section
                        if (_jobData?['includeTest'] == true) ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.quiz, color: const Color(0xFF1D4ED8), size: 20.sp),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Test Questions',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                
                                // Handle multiple questions
                                if (_jobData!['testQuestions'] != null) ...[
                                  ...List.generate((_jobData!['testQuestions'] as List).length, (questionIndex) {
                                    final question = _jobData!['testQuestions'][questionIndex] as Map<String, dynamic>;
                                    return Container(
                                      margin: EdgeInsets.only(bottom: 16.h),
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8.r),
                                        border: Border.all(color: const Color(0xFFD1D5DB)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Question ${questionIndex + 1}',
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          SizedBox(height: 8.h),
                                          Text(
                                            question['question'] ?? '',
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          SizedBox(height: 12.h),
                                          Text(
                                            'Select one answer:',
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                          SizedBox(height: 8.h),
                                          ...List.generate(4, (optionIndex) {
                                            final option = question['options'][optionIndex] ?? '';
                                            return Padding(
                                              padding: EdgeInsets.only(bottom: 8.h),
                                              child: Container(
                                                width: double.infinity,
                                                padding: EdgeInsets.all(12.w),
                                                decoration: BoxDecoration(
                                                  color: _selectedAnswerIndices[questionIndex] == optionIndex
                                                      ? const Color(0xFFDBEAFE)
                                                      : Colors.white,
                                                  borderRadius: BorderRadius.circular(8.r),
                                                  border: Border.all(
                                                    color: _selectedAnswerIndices[questionIndex] == optionIndex
                                                        ? const Color(0xFF3B82F6)
                                                        : const Color(0xFFD1D5DB),
                                                  ),
                                                ),
                                                child: InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedAnswerIndices[questionIndex] = optionIndex;
                                                    });
                                                  },
                                                  child: Row(
                                                    children: [
                                                      Radio<int>(
                                                        value: optionIndex,
                                                        groupValue: _selectedAnswerIndices[questionIndex],
                                                        onChanged: (value) {
                                                          setState(() {
                                                            _selectedAnswerIndices[questionIndex] = value;
                                                          });
                                                        },
                                                        activeColor: const Color(0xFF1D4ED8),
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                          option,
                                                          style: TextStyle(
                                                            fontSize: 14.sp,
                                                            color: const Color(0xFF0F172A),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                          if (_selectedAnswerIndices[questionIndex] != null)
                                            Container(
                                              width: double.infinity,
                                              margin: EdgeInsets.only(top: 8.h),
                                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF0FDF4),
                                                borderRadius: BorderRadius.circular(8.r),
                                                border: Border.all(color: const Color(0xFF86EFAC)),
                                              ),
                                              child: Text(
                                                'You selected: Option ${_selectedAnswerIndices[questionIndex]! + 1}',
                                                style: TextStyle(
                                                  color: const Color(0xFF166534),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12.sp,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                ] else if (_jobData!['testQuestion'] != null) ...[
                                  // Handle legacy single test question format
                                  Text(
                                    _jobData!['testQuestion']['question'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    'Select one answer:',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  ...List.generate(4, (index) {
                                    final option = _jobData!['testQuestion']['options'][index] ?? '';
                                    return Padding(
                                      padding: EdgeInsets.only(bottom: 8.h),
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(12.w),
                                        decoration: BoxDecoration(
                                          color: _selectedAnswerIndices.isNotEmpty && _selectedAnswerIndices[0] == index
                                              ? const Color(0xFFDBEAFE)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(8.r),
                                          border: Border.all(
                                            color: _selectedAnswerIndices.isNotEmpty && _selectedAnswerIndices[0] == index
                                                ? const Color(0xFF3B82F6)
                                                : const Color(0xFFD1D5DB),
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (_selectedAnswerIndices.isEmpty) {
                                                _selectedAnswerIndices.add(index);
                                              } else {
                                                _selectedAnswerIndices[0] = index;
                                              }
                                            });
                                          },
                                          child: Row(
                                            children: [
                                              Radio<int>(
                                                value: index,
                                                groupValue: _selectedAnswerIndices.isNotEmpty ? _selectedAnswerIndices[0] : null,
                                                onChanged: (value) {
                                                  setState(() {
                                                    if (_selectedAnswerIndices.isEmpty) {
                                                      _selectedAnswerIndices.add(value!);
                                                    } else {
                                                      _selectedAnswerIndices[0] = value!;
                                                    }
                                                  });
                                                },
                                                activeColor: const Color(0xFF1D4ED8),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  option,
                                                  style: TextStyle(
                                                    fontSize: 14.sp,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  if (_selectedAnswerIndices.isNotEmpty && _selectedAnswerIndices[0] != null)
                                    Container(
                                      width: double.infinity,
                                      margin: EdgeInsets.only(top: 8.h),
                                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(8.r),
                                        border: Border.all(color: const Color(0xFF86EFAC)),
                                      ),
                                      child: Text(
                                        'You selected: Option ${_selectedAnswerIndices[0]! + 1}',
                                        style: TextStyle(
                                          color: const Color(0xFF166534),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: 20.h),
                        ],
                        
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
                            onPressed: _testSubmitted ? () {} : () => _applyForJob(),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                gradient: _testSubmitted
                                    ? LinearGradient(
                                        colors: [Colors.grey.shade400, Colors.grey.shade600],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : LinearGradient(
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
                              child: Text(
                                _testSubmitted ? 'Application Submitted' : 'Submit Application',
                                style: const TextStyle(
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
