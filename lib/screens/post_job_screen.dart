import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_middleware.dart';
import 'preview_job_screen.dart';
import 'posted_jobs_screen.dart'; // Import PostedJobsScreen (adjust path as needed)
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
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

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
    _skillsController.text = (widget.editJobData!['skills'] as List<dynamic>?)?.join(', ') ?? widget.editJobData!['Required Skills']?.toString() ?? '';
    _educationController.text = widget.editJobData!['education']?.toString() ?? widget.editJobData!['Education Required']?.toString() ?? '';
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
    final skills = _skillsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return {
      'title': _titleController.text.trim(),
      'company': _companyController.text.trim(),
      'location': _locationController.text.trim(),
      'experience': _experienceController.text.trim(),
      'salary': _salaryController.text.trim(),
      'jobType': _jobTypeController.text.trim(),
      'description': _descriptionController.text.trim(),
      'skills': skills,
      'education': _educationController.text.trim(),
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
        // Verify the write
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
      // Navigate to PostedJobsScreen instead of popping
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PostedJobsScreen()), // Adjust as needed
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _experienceController.dispose();
    _salaryController.dispose();
    _jobTypeController.dispose();
    _skillsController.dispose();
    _educationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.editJobData != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Job' : 'Post a Job'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
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
                    _buildTextField(
                      controller: _skillsController,
                      labelText: 'Required Skills (comma-separated, e.g., Java, Python)',
                      maxLines: 2,
                    ),
                    _buildTextField(
                      controller: _educationController,
                      labelText: 'Education Required (e.g., Bachelor\'s in Computer Science)',
                    ),
                    _buildTextField(
                      controller: _descriptionController,
                      labelText: 'Job Description',
                      maxLines: 4,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submitJob,
                      child: Text(isEditMode ? 'Update Job' : 'Preview & Post'),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
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