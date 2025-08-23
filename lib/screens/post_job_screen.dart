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
  '12+ years', // Added to cover more experienced candidates
];

// Education options
final List<String> educationOptions = [
  'High School (Class 10)',
  'Senior Secondary (Class 12)', // Updated to reflect Indian system
  'Diploma',
  'Associate Degree',
  'Bachelor\'s Degree',
  'Postgraduate Diploma', // Added for Indian and global relevance
  'Master\'s Degree',
  'Doctorate/PhD',
  'Professional Certification',
  'Other',
];

// Specialization options
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
  'Vocational/Domestic Services', // Added for driving, househelp, etc.
  'Others',
];

// Skills by specialization
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
  'Vocational/Domestic Services': [
    'Driving', // Car, motorcycle, or commercial vehicle driving
    'Housekeeping', // Cleaning, laundry, household management
    'Cooking', // Meal preparation, dietary planning
    'Childcare', // Babysitting, child supervision, tutoring
    'Elderly Care', // Assisting elderly with daily tasks
    'Gardening', // Plant care, landscaping
    'Basic Maintenance', // Minor household repairs (plumbing, electrical)
    'Customer Service', // Handling client interactions
    'Inventory Management', // Managing household supplies
    'Event Assistance', // Supporting events (e.g., catering, setup)
  ],
  'Others': [
    'Communication Skills', 'Problem Solving', 'Teamwork', 'Leadership', 'Time Management',
    'Adaptability', 'Creativity', 'Conflict Resolution', 'Critical Thinking', 'Customer Support',
    'Basic Computer Skills', 'Typing', 'Remote Work Tools (Zoom, Slack, Trello)', 'Virtual Assistant',
    'Content Moderation', 'Driving', 'Housekeeping', 'Cooking', 'Childcare', 'Gardening',
    'Basic Maintenance',
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
                                _selectedSkills = []; // Reset skills when specialization changes
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