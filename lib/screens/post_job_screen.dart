import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../services/auth_middleware.dart';
import 'preview_job_screen.dart';
import 'posted_jobs_screen.dart';
import 'dart:developer' as dev;

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
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _jobTypeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // State variables for spinners and multi-select
  String? _selectedEducation;
  String? _selectedSpecialization;
  List<String> _selectedSkills = [];

  // Education options
  final List<String> educationOptions = [
    'High School (10th)',
    'Higher Secondary (12th)',
    'Diploma',
    'Bachelor\'s Degree',
    'Master\'s Degree',
    'Doctorate (PhD)',
    'Post Doctorate',
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
    if (widget.editJobData != null) {
      _mapEditData();
    } else {
      _loadRecruiterLocation();
    }
  }

  void _mapEditData() {
    _titleController.text = widget.editJobData!['title']?.toString() ?? widget.editJobData!['Job Title']?.toString() ?? '';
    _companyController.text = widget.editJobData!['company']?.toString() ?? widget.editJobData!['Company Name']?.toString() ?? '';
    _locationController.text = widget.editJobData!['location']?.toString() ?? widget.editJobData!['Location (Remote, On-site, Hybrid)']?.toString() ?? '';
    _experienceController.text = widget.editJobData!['experience']?.toString() ?? widget.editJobData!['Experience Required']?.toString() ?? '';
    _salaryController.text = widget.editJobData!['salary']?.toString() ?? widget.editJobData!['Salary Range']?.toString() ?? '';
    _jobTypeController.text = widget.editJobData!['jobType']?.toString() ?? widget.editJobData!['Job Type (Full-time, Part-time)']?.toString() ?? '';
    _descriptionController.text = widget.editJobData!['description']?.toString() ?? widget.editJobData!['Job Description']?.toString() ?? '';
    _selectedSkills = (widget.editJobData!['skills'] as List<dynamic>?)?.cast<String>() ?? [];
    _selectedEducation = widget.editJobData!['education']?.toString();
    _selectedSpecialization = widget.editJobData!['specialization']?.toString();
    // Ensure selected values are valid options
    if (_selectedEducation != null && !educationOptions.contains(_selectedEducation)) {
      _selectedEducation = null;
    }
    if (_selectedSpecialization != null && !specializationOptions.contains(_selectedSpecialization)) {
      _selectedSpecialization = null;
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

  Map<String, dynamic> _getFormData() {
    return {
      'title': _titleController.text.trim(),
      'company': _companyController.text.trim(),
      'location': _locationController.text.trim(),
      'experience': _experienceController.text.trim(),
      'salary': _salaryController.text.trim(),
      'jobType': _jobTypeController.text.trim(),
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
      Navigator.pushReplacement(
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
    _salaryController.dispose();
    _jobTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.editJobData != null;
    final availableSkills = _selectedSpecialization != null
        ? skillsBySpecialization[_selectedSpecialization] ?? skillsBySpecialization['Others']!
        : skillsBySpecialization['Others']!;

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
              padding: const EdgeInsets.all(16.0),
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
                      labelText: 'Location (Remote, On-site, Hybrid)',
                    ),
                    _buildTextField(
                      controller: _experienceController,
                      labelText: 'Experience Required (e.g., 2 years)',
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter Experience Required';
                        }
                        final match = RegExp(r'^\d+\s*(years?|yrs?)?$').hasMatch(value.trim());
                        if (!match) {
                          return 'Please enter experience in format "X years" (e.g., "2 years")';
                        }
                        return null;
                      },
                    ),
                    _buildTextField(
                      controller: _salaryController,
                      labelText: 'Salary Range',
                    ),
                    _buildTextField(
                      controller: _jobTypeController,
                      labelText: 'Job Type (Full-time, Part-time)',
                    ),
                    // Education Dropdown
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Education Required',
                          labelStyle: TextStyle(color: Colors.grey.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.teal, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: _selectedEducation,
                        items: educationOptions.map((String option) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Text(option, style: const TextStyle(color: Colors.black87)),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedEducation = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Please select an education level' : null,
                      ),
                    ),
                    // Specialization Dropdown
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Specialization',
                          labelStyle: TextStyle(color: Colors.grey.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.teal, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: _selectedSpecialization,
                        items: specializationOptions.map((String option) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Text(option, style: const TextStyle(color: Colors.black87)),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedSpecialization = newValue;
                            _selectedSkills = []; // Reset skills when specialization changes
                          });
                        },
                        validator: (value) => value == null ? 'Please select a specialization' : null,
                      ),
                    ),
                    // Skills Multi-Select Dropdown
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: MultiSelectDialogField(
                        items: availableSkills
                            .map((skill) => MultiSelectItem<String>(skill, skill))
                            .toList(),
                        initialValue: _selectedSkills,
                        title: const Text('Required Skills', style: TextStyle(color: Colors.black87)),
                        selectedColor: Colors.teal,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        buttonText: Text(
                          'Select Required Skills',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
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
                    const SizedBox(height: 20),
                    AnimatedScaleButton(
                      onPressed: _submitJob,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade700, Colors.teal.shade400],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
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
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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