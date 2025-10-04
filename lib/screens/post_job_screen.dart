// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../services/auth_middleware.dart';
import 'preview_job_screen.dart';
import 'posted_jobs_screen.dart';
import 'dart:developer' as dev;
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
  bool _isFeatured = false; // New state variable for featured status

  // Controllers for form fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _minSalaryController = TextEditingController();
  final TextEditingController _maxSalaryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // State variables for spinners and multi-select
  String? _selectedEducation;
  String? _selectedExperience;
  String? _selectedSpecialization;
  String? _selectedJobType;
  List<String> _selectedSkills = [];

  // Job Type options
  final List<String> jobTypeOptions = ['Full-Time', 'Part-Time', 'Freelancer'];

  // Experience options
  final List<String> experienceOptions = [
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
      _minSalaryController.text = '0.0';
      _maxSalaryController.text = '0.0';
    }
    _minSalaryController.addListener(_formatSalaryOnChange);
    _maxSalaryController.addListener(_formatSalaryOnChange);
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
      _minSalaryController.text = '0.0';
      _maxSalaryController.text = '0.0';
    }
    _selectedJobType = widget.editJobData!['jobType']?.toString() ?? widget.editJobData!['Job Type (Full-time, Part-time)']?.toString();
    _descriptionController.text = widget.editJobData!['description']?.toString() ?? widget.editJobData!['Job Description']?.toString() ?? '';
    _selectedSkills = (widget.editJobData!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
    _selectedEducation = widget.editJobData!['education']?.toString();
    _selectedSpecialization = widget.editJobData!['specialization']?.toString();
    _isFeatured = widget.editJobData!['isFeatured'] ?? false; // Initialize isFeatured from edit data
    // Ensure selected values are valid options
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
    dev.log('Mapped edit data: ${_getFormData()}', name: 'PostJobScreen');
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
    double? number = double.tryParse(value);
    if (number == null) {
      return '0.0';
    }
    return number.toStringAsFixed(1);
  }

  void _formatSalaryOnChange() {
    final controllers = [_minSalaryController, _maxSalaryController];
    for (var controller in controllers) {
      final value = controller.text;
      final formattedValue = _formatSalary(value);
      if (controller.text != formattedValue) {
        final selection = controller.selection;
        controller.text = formattedValue;
        controller.selection = selection.extent.offset == value.length
            ? TextSelection.fromPosition(TextPosition(offset: formattedValue.length))
            : TextSelection.collapsed(offset: selection.extent.offset);
      }
    }
  }

  Map<String, dynamic> _getFormData() {
    return {
      'title': _titleController.text.trim(),
      'company': _companyController.text.trim(),
      'location': _locationController.text.trim(),
      'experience': _selectedExperience ?? '',
      'salary': '${_minSalaryController.text.trim()}-${_maxSalaryController.text.trim()} LPA (INR)',
      'jobType': _selectedJobType ?? '',
      'description': _descriptionController.text.trim(),
      'skills': _selectedSkills,
      'education': _selectedEducation ?? '',
      'specialization': _selectedSpecialization ?? '',
      'isFeatured': _isFeatured, // Include isFeatured in form data
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
        MaterialPageRoute(builder: (_) => const PostedJobsScreen()),
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
    _minSalaryController.removeListener(_formatSalaryOnChange);
    _maxSalaryController.removeListener(_formatSalaryOnChange);
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.editJobData != null;
    final availableSkills = _selectedSpecialization != null
        ? skillsBySpecialization[_selectedSpecialization] ?? skillsBySpecialization['Others']!
        : skillsBySpecialization['Others']!;

    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              isEditMode ? 'Edit Job' : 'Post a Job',
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
          body: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        _buildTextField(
                          controller: _titleController,
                          labelText: 'Job Title',
                          validator: (value) => value == null || value.trim().isEmpty ? 'Please enter Job Title' : null,
                        ),
                        _buildTextField(
                          controller: _companyController,
                          labelText: 'Company Name',
                        ),
                        _buildTextField(
                          controller: _locationController,
                          labelText: 'Location (City, State)',
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Experience Required',
                              labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(color: Colors.grey.shade400),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(color: Colors.teal, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: _selectedExperience,
                            items: experienceOptions.map((String option) {
                              return DropdownMenuItem<String>(
                                value: option,
                                child: Text(
                                  option,
                                  style: TextStyle(color: Colors.black87, fontSize: 14.sp),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedExperience = newValue;
                              });
                            },
                            validator: (value) => value == null ? 'Please select an experience level' : null,
                            dropdownColor: Colors.white,
                            isExpanded: true,
                          ),
                        ),
                        _buildTextField(
                          controller: _minSalaryController,
                          labelText: 'Minimum Salary (LPA (INR))',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter Minimum Salary';
                            }
                            final min = double.tryParse(value.trim());
                            if (min == null) {
                              return 'Please enter a valid number';
                            }
                            final max = double.tryParse(_maxSalaryController.text.trim()) ?? 0.0;
                            if (min > max && _maxSalaryController.text.isNotEmpty) {
                              return 'Min salary cannot be greater than max salary';
                            }
                            return null;
                          },
                        ),
                        _buildTextField(
                          controller: _maxSalaryController,
                          labelText: 'Maximum Salary (LPA (INR))',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter Maximum Salary';
                            }
                            final max = double.tryParse(value.trim());
                            if (max == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Job Type',
                              labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(color: Colors.grey.shade400),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(color: Colors.teal, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: _selectedJobType,
                            items: jobTypeOptions.map((String option) {
                              return DropdownMenuItem<String>(
                                value: option,
                                child: Text(
                                  option,
                                  style: TextStyle(color: Colors.black87, fontSize: 14.sp),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedJobType = newValue;
                              });
                            },
                            validator: (value) => value == null ? 'Please select a job type' : null,
                            dropdownColor: Colors.white,
                            isExpanded: true,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Education Required',
                              labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(color: Colors.grey.shade400),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(color: Colors.teal, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: _selectedEducation,
                            items: educationOptions.map((String option) {
                              return DropdownMenuItem<String>(
                                value: option,
                                child: Text(
                                  option,
                                  style: TextStyle(color: Colors.black87, fontSize: 14.sp),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedEducation = newValue;
                              });
                            },
                            validator: (value) => value == null ? 'Please select an education level' : null,
                            dropdownColor: Colors.white,
                            isExpanded: true,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Specialization',
                              labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(color: Colors.grey.shade400),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(color: Colors.teal, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: _selectedSpecialization,
                            items: specializationOptions.map((String option) {
                              return DropdownMenuItem<String>(
                                value: option,
                                child: Text(
                                  option,
                                  style: TextStyle(color: Colors.black87, fontSize: 14.sp),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedSpecialization = newValue;
                                _selectedSkills = [];
                              });
                            },
                            validator: (value) => value == null ? 'Please select a specialization' : null,
                            dropdownColor: Colors.white,
                            isExpanded: true,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: MultiSelectDialogField(
                            items: availableSkills
                                .map((skill) => MultiSelectItem<String>(skill, skill))
                                .toList(),
                            initialValue: _selectedSkills,
                            title: Text('Required Skills', style: TextStyle(color: Colors.black87, fontSize: 16.sp)),
                            selectedColor: Colors.teal,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4.r,
                                  offset: Offset(0, 2.h),
                                ),
                              ],
                            ),
                            buttonText: Text(
                              'Select Required Skills',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
                            ),
                            buttonIcon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                            validator: (values) =>
                                values == null || values.isEmpty ? 'Please select at least one skill' : null,
                            onConfirm: (values) {
                              setState(() {
                                _selectedSkills = values.cast<String>();
                              });
                            },
                          ),
                        ),
                        _buildTextField(
                          controller: _descriptionController,
                          labelText: 'Job Description',
                          maxLines: 4,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: SwitchListTile(
                            title: Text(
                              'Feature this Job',
                              style: TextStyle(fontSize: 16.sp, color: Colors.black87),
                            ),
                            subtitle: Text(
                              'Make this job appear at the top of job listings',
                              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
                            ),
                            value: _isFeatured,
                            onChanged: (value) {
                              setState(() {
                                _isFeatured = value;
                              });
                            },
                            activeColor: Colors.teal,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            tileColor: Colors.white,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        AnimatedScaleButton(
                          onPressed: _submitJob,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
                            child: Text(
                              isEditMode ? 'Update Job' : 'Preview & Post',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          suffixText: labelText.contains('Salary') ? ' LPA (INR)' : null,
          suffixStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator ??
            ((value) => value == null || value.trim().isEmpty ? 'Please enter $labelText' : null),
        onSaved: (value) {
          // No need for onSaved since controllers handle state
        },
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