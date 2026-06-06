// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_middleware.dart';
import 'preview_job_screen.dart';
import 'posted_jobs_view.dart';
import 'dart:developer' as dev;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:naukariwala/widgets/skills_autocomplete_multi_select.dart';
import 'package:naukariwala/widgets/address_autocomplete_field.dart';

class PostJobScreen extends StatefulWidget {
  final Map<String, dynamic>? editJobData;

  const PostJobScreen({super.key, this.editJobData});

  @override
  PostJobScreenState createState() => PostJobScreenState();
}

class PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> jobData = {};
  bool isLoading = false;
  bool _isFeatured = false;

  // Controllers for form fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _minSalaryController = TextEditingController();
  final TextEditingController _maxSalaryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Test questions list
  List<Map<String, dynamic>> _testQuestions = [];

  // State variables for spinners and multi-select
  String? _selectedEducation;
  String? _selectedExperience;
  String? _selectedSpecialization;
  String? _selectedJobType;
  String? _selectedGender;
  List<String> _selectedSkills = [];
  bool _includeTest = false;

  // Job Type options
  final List<String> jobTypeOptions = ['Full-Time', 'Part-Time', 'Freelancer'];

  // Gender options
  final List<String> genderOptions = ['Male', 'Female', 'Any'];

  // Experience options
  final List<String> experienceOptions = [
    'Intern',
    'Fresher',
    '1-2 years',
    '2-4 years',
    '4-6 years',
    '6-8 years',
    '8-10 years',
    '10-12 years',
    '12+ years',
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
    if (widget.editJobData != null) {
      _mapEditData();
    } else {
      _loadRecruiterLocation();
      _minSalaryController.text = '';
      _maxSalaryController.text = '';
    }
  }

  void _mapEditData() {
    _titleController.text = widget.editJobData!['title']?.toString() ?? widget.editJobData!['Job Title']?.toString() ?? '';
    _companyController.text = widget.editJobData!['company']?.toString() ?? widget.editJobData!['Company Name']?.toString() ?? '';
    _locationController.text = widget.editJobData!['location']?.toString() ?? widget.editJobData!['Location (Remote, On-site, Hybrid)']?.toString() ?? '';
    _selectedExperience = widget.editJobData!['experience']?.toString() ?? widget.editJobData!['Experience Required']?.toString();
    final salary = widget.editJobData!['salary']?.toString() ?? widget.editJobData!['Salary Range']?.toString() ?? '0.0-0.0 LPA (INR)';
    final parts = salary.split('-');
    if (parts.length == 2) {
      _minSalaryController.text = parts[0].trim().replaceAll(' LPA (INR)', '');
      _maxSalaryController.text = parts[1].trim().replaceAll(' LPA (INR)', '');
    } else {
      _minSalaryController.text = '1.8';
      _maxSalaryController.text = '2.0';
    }
    _selectedJobType = widget.editJobData!['jobType']?.toString() ?? widget.editJobData!['Job Type (Full-time, Part-time)']?.toString();
    _descriptionController.text = widget.editJobData!['description']?.toString() ?? widget.editJobData!['Job Description']?.toString() ?? '';
    _selectedSkills = (widget.editJobData!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
    _selectedEducation = widget.editJobData!['education']?.toString();
    _selectedSpecialization = widget.editJobData!['specialization']?.toString();
    _selectedGender = widget.editJobData!['gender']?.toString();
    _isFeatured = widget.editJobData!['isFeatured'] ?? false;
    
    // Map test question data if exists
    _includeTest = widget.editJobData!['includeTest'] ?? false;
    if (_includeTest && widget.editJobData!['testQuestions'] != null) {
      _testQuestions = List<Map<String, dynamic>>.from(widget.editJobData!['testQuestions']);
    } else if (_includeTest && widget.editJobData!['testQuestion'] != null) {
      // Handle legacy single test question format
      final testQuestion = widget.editJobData!['testQuestion'] as Map<String, dynamic>;
      _testQuestions = [{
        'question': testQuestion['question'] ?? '',
        'options': testQuestion['options'] ?? ['', '', '', ''],
        'correctOptionIndex': testQuestion['correctOptionIndex'] ?? 0,
      }];
    }
    if (_selectedExperience != null && !experienceOptions.contains(_selectedExperience)) {
      _selectedExperience = null;
    }
    if (_selectedEducation != null && !educationOptions.contains(_selectedEducation)) {
      _selectedEducation = null;
    }
    if (_selectedSpecialization != null && !specializationOptions.contains(_selectedSpecialization)) {
      _selectedSpecialization = null;
    }
    if (_selectedJobType != null && !jobTypeOptions.contains(_selectedJobType)) {
      _selectedJobType = null;
    }
    if (_selectedGender != null && !genderOptions.contains(_selectedGender)) {
      _selectedGender = null;
    }
    dev.log('Mapped edit data: ${_getFormData()}', name: 'PostJobScreen');
  }

  // Methods to manage test questions
  void _addTestQuestion() {
    setState(() {
      _testQuestions.add({
        'question': '',
        'options': ['', '', '', ''],
        'correctOptionIndex': 0,
      });
    });
  }

  void _removeTestQuestion(int index) {
    setState(() {
      _testQuestions.removeAt(index);
    });
  }

  void _updateTestQuestion(int index, String field, dynamic value) {
    setState(() {
      _testQuestions[index][field] = value;
    });
  }

  Future<void> _loadRecruiterLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('Recruiters').doc(uid).get();
      final location = doc.data()?['location'];
      if (location != null && _locationController.text.isEmpty) {
        setState(() {
          _locationController.text = location;
        });
      }
    } catch (e) {
      dev.log('Error loading recruiter location: $e', name: 'PostJobScreen');
    }
  }

  String _formatSalary(String value) {
    value = value.replaceAll(' LPA (INR)', '').trim();
    if (value.isEmpty) {
      return '';
    }
    double? number = double.tryParse(value);
    if (number == null) {
      return value;
    }
    return number.toStringAsFixed(1);
  }

  Map<String, dynamic> _getFormData() {
    String minSalary = _formatSalary(_minSalaryController.text);
    String maxSalary = _formatSalary(_maxSalaryController.text);
    minSalary = minSalary.isEmpty ? '0.0' : minSalary;
    maxSalary = maxSalary.isEmpty ? '0.0' : maxSalary;

    return {
      'title': _titleController.text.trim(),
      'company': _companyController.text.trim(),
      'location': _locationController.text.trim(),
      'experience': _selectedExperience ?? '',
      'salary': '$minSalary-$maxSalary LPA (INR)',
      'jobType': _selectedJobType ?? '',
      'description': _descriptionController.text.trim(),
      'skills': _selectedSkills,
      'education': _selectedEducation ?? '',
      'specialization': _selectedSpecialization ?? '',
      'gender': _selectedGender ?? '',
      'isFeatured': _isFeatured,
      'includeTest': _includeTest,
      if (_includeTest) 'testQuestions': _testQuestions,
    };
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) {
      _showSnack('Please fill all required fields correctly.');
      return;
    }

    _formKey.currentState!.save();
    final formData = _getFormData();
    dev.log('Form data before preview: $formData', name: 'PostJobScreen');

    try {
      await AuthMiddleware.requireRole('recruiter');
    } catch (e) {
      _showSnack('Unauthorized: recruiter role required.');
      return;
    }

    final confirmed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewJobScreen(jobData: formData),
      ),
    );

    if (confirmed != true) {
      dev.log('Preview cancelled, form data retained: $formData', name: 'PostJobScreen');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('User not logged in.');
      return;
    }

    final uid = user.uid;
    final createdAt = FieldValue.serverTimestamp();

    setState(() => isLoading = true);

    try {
      final jobsRef = FirebaseFirestore.instance
          .collection('Recruiters')
          .doc(uid)
          .collection('Jobs');

      if (widget.editJobData != null && widget.editJobData!['jobId'] != null) {
        final jobId = widget.editJobData!['jobId'];
        await jobsRef.doc(jobId).update({
          ...formData,
          'updatedAt': createdAt,
        });
        if (!mounted) return;
        _showSnack('Job updated successfully');
      } else {
        final newDoc = jobsRef.doc();
        final jobDataToSet = {
          'jobId': newDoc.id,
          'recruiterId': uid,
          'status': 'open',
          'createdAt': createdAt,
          ...formData,
        };
        dev.log('Writing to ${newDoc.path} with data: $jobDataToSet', name: 'PostJobScreen');
        await newDoc.set(jobDataToSet);
        final docSnap = await newDoc.get();
        if (docSnap.exists) {
          dev.log('Write verified: ${docSnap.data()}', name: 'PostJobScreen');
        } else {
          dev.log('Write failed: Document not found after set', name: 'PostJobScreen');
          throw Exception('Write verification failed');
        }
        if (!mounted) return;
        _showSnack('Job posted successfully');
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostedJobsScreen()),
      );
    } catch (e) {
      dev.log('Error submitting job: $e', name: 'PostJobScreen');
      if (!mounted) return;
      _showSnack('Failed to submit job: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message.contains('Failed') ? Colors.red : Colors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _experienceController.dispose();
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    _descriptionController.dispose();
    
    // Test questions list doesn't need disposal
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.editJobData != null;
    const primaryColor = Color(0xFF1D4ED8);
    const accentColor = Color(0xFF0F766E);

    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F7FC),
          appBar: AppBar(
            title: Text(
              isEditMode ? 'Edit Job' : 'Post a Job',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 20.sp,
              ),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            elevation: 0,
          ),
          body: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                )
              : SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          _buildIntroCard(isEditMode: isEditMode, accentColor: accentColor),
                          SizedBox(height: 12.h),
                          _buildSectionCard(
                            icon: Icons.work_outline_rounded,
                            title: 'Basic Details',
                            subtitle: 'Core information candidates see first.',
                            children: [
                              _buildTextField(
                                controller: _titleController,
                                labelText: 'Job Title',
                                hintText: 'e.g., Senior Flutter Developer',
                                prefixIcon: Icons.badge_outlined,
                                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter Job Title' : null,
                              ),
                              _buildTextField(
                                controller: _companyController,
                                labelText: 'Company Name',
                                hintText: 'e.g., Naukariwala Technologies',
                                prefixIcon: Icons.apartment_rounded,
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: AddressAutocompleteField(
                                  controller: _locationController,
                                  labelText: 'Location (City, State)',
                                  helperText: 'Start typing to see suggestions',
                                  textInputAction: TextInputAction.next,
                                  validator: (value) => value == null || value.trim().isEmpty
                                      ? 'Please enter Location (City, State)'
                                      : null,
                                  decoration: _inputDecoration(
                                    labelText: 'Location (City, State)',
                                    prefixIcon: Icons.location_on_outlined,
                                  ),
                                ),
                              ),
                              _buildDropdownField(
                                labelText: 'Experience Required',
                                value: _selectedExperience,
                                items: experienceOptions,
                                prefixIcon: Icons.trending_up_rounded,
                                onChanged: (newValue) {
                                  setState(() {
                                    _selectedExperience = newValue;
                                  });
                                },
                                validator: (value) => value == null ? 'Please select an experience level' : null,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _minSalaryController,
                                      labelText: 'Minimum Salary',
                                      keyboardType: TextInputType.number,
                                      prefixIcon: Icons.currency_rupee_rounded,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Enter Minimum Salary';
                                        }
                                        final min = double.tryParse(value.trim());
                                        if (min == null) {
                                          return 'Enter a valid number';
                                        }
                                        final max = double.tryParse(_maxSalaryController.text.trim()) ?? double.infinity;
                                        if (min > max && _maxSalaryController.text.isNotEmpty) {
                                          return 'Min > max';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _maxSalaryController,
                                      labelText: 'Maximum Salary',
                                      keyboardType: TextInputType.number,
                                      prefixIcon: Icons.currency_rupee_rounded,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Enter Maximum Salary';
                                        }
                                        final max = double.tryParse(value.trim());
                                        if (max == null) {
                                          return 'Enter a valid number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              _buildDropdownField(
                                labelText: 'Job Type',
                                value: _selectedJobType,
                                items: jobTypeOptions,
                                prefixIcon: Icons.schedule_rounded,
                                onChanged: (newValue) {
                                  setState(() {
                                    _selectedJobType = newValue;
                                  });
                                },
                                validator: (value) => value == null ? 'Please select a job type' : null,
                              ),
                              _buildDropdownField(
                                labelText: 'Gender Preference (Optional)',
                                value: _selectedGender,
                                items: genderOptions,
                                prefixIcon: Icons.person_outline_rounded,
                                onChanged: (newValue) {
                                  setState(() {
                                    _selectedGender = newValue;
                                  });
                                },
                                validator: (value) => null, // Optional field, no validation
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          _buildSectionCard(
                            icon: Icons.school_outlined,
                            title: 'Qualifications',
                            subtitle: 'Set education, specialization, and skills.',
                            children: [
                              _buildDropdownField(
                                labelText: 'Education Required',
                                value: _selectedEducation,
                                items: educationOptions,
                                prefixIcon: Icons.menu_book_rounded,
                                onChanged: (newValue) {
                                  setState(() {
                                    _selectedEducation = newValue;
                                  });
                                },
                                validator: (value) => value == null ? 'Please select an education level' : null,
                              ),
                              _buildDropdownField(
                                labelText: 'Specialization',
                                value: _selectedSpecialization,
                                items: specializationOptions,
                                prefixIcon: Icons.psychology_alt_outlined,
                                onChanged: (newValue) {
                                  setState(() {
                                    _selectedSpecialization = newValue;
                                    _selectedSkills = [];
                                  });
                                },
                                validator: (value) => value == null ? 'Please select a specialization' : null,
                              ),
                              _buildSkillsSummary(),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    inputDecorationTheme: InputDecorationTheme(
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Color(0xFFD6DFEE),
                                        ),
                                        borderRadius: BorderRadius.circular(14.r),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: accentColor,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(14.r),
                                      ),
                                    ),
                                  ),
                                  child: SkillsAutocompleteMultiSelect(
                                    value: _selectedSkills,
                                    onChanged: (v) => setState(() => _selectedSkills = v),
                                    labelText: 'Required Skills',
                                    hintText: 'Type to search skills',
                                    validator: (values) =>
                                        values == null || values.isEmpty
                                            ? 'Please select at least one skill'
                                            : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          _buildSectionCard(
                            icon: Icons.quiz_outlined,
                            title: 'Test Question (Optional)',
                            subtitle: 'Add a screening test for candidates.',
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: SwitchListTile(
                                  title: Text(
                                    'Include Test Question',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      color: const Color(0xFF0F172A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Candidates will answer this question when applying',
                                    style: TextStyle(fontSize: 13.sp, color: const Color(0xFF64748B)),
                                  ),
                                  value: _includeTest,
                                  onChanged: (value) {
                                    setState(() {
                                      _includeTest = value;
                                      if (!value) {
                                        _testQuestions.clear();
                                      }
                                    });
                                  },
                                  activeColor: accentColor,
                                  activeTrackColor: accentColor.withValues(alpha: 0.25),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                    side: const BorderSide(color: Color(0xFFD6DFEE)),
                                  ),
                                  tileColor: const Color(0xFFF8FAFC),
                                ),
                              ),
                              if (_includeTest) ...[
                                // Add Question Button
                                Container(
                                  width: double.infinity,
                                  margin: EdgeInsets.only(bottom: 12.h),
                                  child: ElevatedButton.icon(
                                    onPressed: _addTestQuestion,
                                    icon: Icon(Icons.add, size: 18.sp),
                                    label: Text(
                                      'Add Question',
                                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1D4ED8),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Display Questions
                                ...List.generate(_testQuestions.length, (questionIndex) {
                                  final question = _testQuestions[questionIndex];
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 16.h),
                                    padding: EdgeInsets.all(16.w),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFD1D5DB)),
                                      borderRadius: BorderRadius.circular(12.r),
                                      color: Colors.white,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Question Header
                                        Row(
                                          children: [
                                            Text(
                                              'Question ${questionIndex + 1}',
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (_testQuestions.length > 1)
                                              IconButton(
                                                onPressed: () => _removeTestQuestion(questionIndex),
                                                icon: Icon(Icons.delete, color: Colors.red, size: 20.sp),
                                                tooltip: 'Remove Question',
                                              ),
                                          ],
                                        ),
                                        SizedBox(height: 12.h),
                                        
                                        // Question Input
                                        Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8.h),
                                          child: TextFormField(
                                            initialValue: question['question'],
                                            decoration: _inputDecoration(
                                              labelText: 'Question',
                                              prefixIcon: Icons.help_outline_rounded,
                                              hintText: 'Enter your screening question',
                                            ),
                                            validator: (value) => _includeTest && (value == null || value.trim().isEmpty) ? 'Please enter a question' : null,
                                            onChanged: (value) => _updateTestQuestion(questionIndex, 'question', value),
                                          ),
                                        ),
                                        SizedBox(height: 12.h),
                                        
                                        // Options Header
                                        Text(
                                          'Answer Options',
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        SizedBox(height: 8.h),
                                        
                                        // Options
                                        ...List.generate(4, (optionIndex) {
                                          return Padding(
                                            padding: EdgeInsets.only(bottom: 8.h),
                                            child: Row(
                                              children: [
                                                Radio<int>(
                                                  value: optionIndex,
                                                  groupValue: question['correctOptionIndex'],
                                                  onChanged: (value) {
                                                    _updateTestQuestion(questionIndex, 'correctOptionIndex', value);
                                                  },
                                                  activeColor: accentColor,
                                                ),
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue: question['options'][optionIndex],
                                                    decoration: InputDecoration(
                                                      labelText: 'Option ${optionIndex + 1}',
                                                      hintText: 'Enter option ${optionIndex + 1}',
                                                      prefixIcon: const Icon(Icons.radio_button_unchecked),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12.r),
                                                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12.r),
                                                        borderSide: const BorderSide(color: accentColor, width: 1.3),
                                                      ),
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                                    ),
                                                    validator: (value) => _includeTest && (value == null || value.trim().isEmpty) ? 'Please enter option ${optionIndex + 1}' : null,
                                                    onChanged: (value) {
                                                      final options = List<String>.from(question['options']);
                                                      options[optionIndex] = value;
                                                      _updateTestQuestion(questionIndex, 'options', options);
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                        
                                        // Correct Answer Indicator
                                        if (question['correctOptionIndex'] != null)
                                          Container(
                                            width: double.infinity,
                                            margin: EdgeInsets.only(top: 8.h),
                                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0FDF4),
                                              borderRadius: BorderRadius.circular(12.r),
                                              border: Border.all(color: const Color(0xFF86EFAC)),
                                            ),
                                            child: Text(
                                              'Correct answer: Option ${question['correctOptionIndex'] + 1}',
                                              style: TextStyle(
                                                color: const Color(0xFF166534),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13.sp,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                                
                                if (_testQuestions.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(16.w),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(color: const Color(0xFFD1D5DB)),
                                    ),
                                    child: Text(
                                      'No questions added yet. Click "Add Question" to create a screening test.',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: const Color(0xFF64748B),
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                          SizedBox(height: 12.h),
                          _buildSectionCard(
                            icon: Icons.description_outlined,
                            title: 'Description & Publishing',
                            subtitle: 'Define responsibilities and visibility.',
                            children: [
                              _buildTextField(
                                controller: _descriptionController,
                                labelText: 'Job Description',
                                maxLines: 4,
                                hintText: 'Describe role, responsibilities, and requirements',
                                prefixIcon: Icons.notes_rounded,
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: SwitchListTile(
                                  title: Text(
                                    'Feature this Job',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      color: const Color(0xFF0F172A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Make this job appear at the top of job listings',
                                    style: TextStyle(fontSize: 13.sp, color: const Color(0xFF64748B)),
                                  ),
                                  value: _isFeatured,
                                  onChanged: (value) {
                                    setState(() {
                                      _isFeatured = value;
                                    });
                                  },
                                  activeColor: accentColor,
                                  activeTrackColor: accentColor.withValues(alpha: 0.25),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                    side: const BorderSide(color: Color(0xFFD6DFEE)),
                                  ),
                                  tileColor: const Color(0xFFF8FAFC),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20.h),
                          AnimatedScaleButton(
                            onPressed: _submitJob,
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [primaryColor, accentColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.25),
                                    blurRadius: 10.r,
                                    offset: Offset(0, 4.h),
                                  ),
                                ],
                              ),
                              child: Text(
                                isEditMode ? 'Update Job' : 'Preview & Post',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16.sp,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildIntroCard({
    required bool isEditMode,
    required Color accentColor,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFD6DFEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(Icons.tips_and_updates_outlined, color: accentColor, size: 20.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditMode ? 'Update your posting' : 'Create a strong posting',
                  style: TextStyle(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                    fontSize: 15.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Clear job details improve candidate quality and reduce irrelevant applications.',
                  style: TextStyle(
                    color: const Color(0xFF64748B),
                    fontSize: 13.sp,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFD6DFEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1D4ED8), size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.sp,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 10.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSkillsSummary() {
    final summary = _selectedSkills.isEmpty
        ? 'No skills selected'
        : '${_selectedSkills.length} skill${_selectedSkills.length > 1 ? 's' : ''} selected';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        summary,
        style: TextStyle(
          color: const Color(0xFF1E3A8A),
          fontWeight: FontWeight.w600,
          fontSize: 13.sp,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    IconData? prefixIcon,
    String? hintText,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF475569), size: 20.sp) : null,
      labelStyle: TextStyle(color: const Color(0xFF64748B), fontSize: 14.sp),
      hintStyle: TextStyle(color: const Color(0xFF94A3B8), fontSize: 13.sp),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: Color(0xFFD6DFEE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: Color(0xFFD6DFEE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      suffixText: suffixText,
      suffixStyle: TextStyle(color: const Color(0xFF64748B), fontSize: 13.sp),
    );
  }

  Widget _buildDropdownField({
    required String labelText,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String? Function(String?) validator,
    IconData? prefixIcon,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: DropdownButtonFormField<String>(
        decoration: _inputDecoration(
          labelText: labelText,
          prefixIcon: prefixIcon,
        ),
        value: value,
        items: items.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(
              option,
              style: TextStyle(color: const Color(0xFF0F172A), fontSize: 14.sp),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        isExpanded: true,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    String? hintText,
    IconData? prefixIcon,
    bool readOnly = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        decoration: _inputDecoration(
          labelText: labelText,
          prefixIcon: prefixIcon,
          hintText: hintText,
          suffixText: labelText.contains('Salary') ? 'LPA (INR)' : null,
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator ??
            (labelText.contains('Salary')
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter $labelText';
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null) {
                      return 'Please enter a valid number';
                    }
                    if (labelText.contains('Minimum')) {
                      final max = double.tryParse(_maxSalaryController.text.trim()) ?? double.infinity;
                      if (parsed > max && _maxSalaryController.text.isNotEmpty) {
                        return 'Min salary cannot be greater than max salary';
                      }
                    }
                    return null;
                  }
                : (value) => value == null || value.trim().isEmpty ? 'Please enter $labelText' : null),
        onSaved: (value) {
          // No need for onSaved since controllers handle state
        },
      ),
    );
  }
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

