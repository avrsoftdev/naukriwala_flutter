// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as dev;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../widgets/skills_autocomplete_multi_select.dart';

class EditJobScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobData;

  const EditJobScreen({
    super.key,
    required this.jobId,
    required this.jobData,
  });

  @override
  State<EditJobScreen> createState() => _EditJobScreenState();
}

class _EditJobScreenState extends State<EditJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> updatedJobData = {};
  final AuthService _authService = AuthService();

  // Controllers for salary fields
  final TextEditingController _minSalaryController = TextEditingController();
  final TextEditingController _maxSalaryController = TextEditingController();

  // State for employment type dropdown
  String? _selectedJobType;

  // State for new dropdown fields
  List<String> _selectedSkills = [];
  String? _selectedEducation;
  String? _selectedExperience;
  String? _selectedSpecialization;

  // Test questions state
  List<Map<String, dynamic>> _testQuestions = [];
  bool _includeTest = false;

  // Job Type options
  final List<String> jobTypeOptions = ['Full-Time', 'Part-Time', 'Freelancer'];

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

  // Specialization options
  List<String> get specializationOptions => _authService.specializationOptions;

  @override
  void initState() {
    super.initState();
    // Pre-fill data and validate recruiterId
    final recruiterId = widget.jobData['recruiterId']?.toString();
    if (recruiterId == null) {
      dev.log('Missing recruiterId in jobData', name: 'EditJobScreen');
      return; // Prevent further initialization if recruiterId is missing
    }
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId != recruiterId) {
      dev.log('Unauthorized access attempt by $currentUserId for jobId ${widget.jobId}',
          name: 'EditJobScreen');
    }
    // Initialize updatedJobData with the actual job data using correct field names
    final fieldMapping = {
      'jobType': 'Employment Type',
      'salary': 'Salary Range',
      'skills': 'Skills',
      'education': 'Education',
      'experience': 'Experience',
      'specialization': 'Specialization',
    };

    widget.jobData.forEach((key, value) {
      if (value is String) {
        updatedJobData[key] = value;
      }
    });

    // Initialize salary controllers and job type
    _initializeSalaryAndJobType();
    
    // Initialize new dropdown fields
    _initializeNewFields();

    // Initialize test questions
    _initializeTestQuestions();

    dev.log('EditJobScreen initialized with job data: ${widget.jobData.keys}', name: 'EditJobScreen');
    dev.log('Updated job data keys: ${updatedJobData.keys}', name: 'EditJobScreen');
  }

  void _initializeNewFields() {
    // Initialize skills
    final skills = widget.jobData['skills'];
    if (skills != null) {
      if (skills is List) {
        _selectedSkills = skills.map((s) => s.toString()).toList();
      } else if (skills is String) {
        final skillsString = skills.toString().trim();
        if (skillsString.isNotEmpty) {
          _selectedSkills = skillsString.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        }
      }
    }

    // Initialize education
    final education = widget.jobData['education'];
    if (education != null && educationOptions.contains(education.toString())) {
      _selectedEducation = education.toString();
    }

    // Initialize experience
    final experience = widget.jobData['experience'];
    if (experience != null && experienceOptions.contains(experience.toString())) {
      _selectedExperience = experience.toString();
    }

    // Initialize specialization
    final specialization = widget.jobData['specialization'];
    if (specialization != null && specializationOptions.contains(specialization.toString())) {
      _selectedSpecialization = specialization.toString();
    }
  }

  void _initializeTestQuestions() {
    // Initialize test questions from job data
    _includeTest = widget.jobData['includeTest'] ?? false;
    if (_includeTest && widget.jobData['testQuestions'] != null) {
      _testQuestions = List<Map<String, dynamic>>.from(widget.jobData['testQuestions']);
    } else if (_includeTest && widget.jobData['testQuestion'] != null) {
      // Handle legacy single test question format
      final testQuestion = widget.jobData['testQuestion'] as Map<String, dynamic>;
      _testQuestions = [{
        'question': testQuestion['question'] ?? '',
        'options': testQuestion['options'] ?? ['', '', '', ''],
        'correctOptionIndex': testQuestion['correctOptionIndex'] ?? 0,
      }];
    }
  }

  void _initializeSalaryAndJobType() {
    // Parse salary range from existing data
    final salaryRange = widget.jobData['salary'];
    if (salaryRange != null && salaryRange.toString().isNotEmpty) {
      final salaryStr = salaryRange.toString();
      // Handle formats like "1.8-2.0 LPA (INR)" or "1.8-2.0"
      final parts = salaryStr.split('-');
      if (parts.length >= 2) {
        _minSalaryController.text = parts[0].trim();
        _maxSalaryController.text = parts[1].trim().replaceAll(' LPA (INR)', '').trim();
      }
    }

    // Set job type from existing data
    final jobType = widget.jobData['jobType'];
    if (jobType != null && jobTypeOptions.contains(jobType.toString())) {
      _selectedJobType = jobType.toString();
    }
  }

  @override
  void dispose() {
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final recruiterId = widget.jobData['recruiterId']?.toString();
    if (currentUserId == null || recruiterId == null || currentUserId != recruiterId) {
      return ScreenUtilInit(
        designSize: const Size(360, 690), // Base design size for responsiveness
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Edit Job',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Text(
                    'You are not authorized to edit this job.',
                    style: TextStyle(fontSize: 16.sp, color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return ScreenUtilInit(
      designSize: const Size(360, 690), // Base design size for responsiveness
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Edit Job',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white),
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
            padding: EdgeInsets.all(16.w),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  _buildJobTypeDropdown(required: true),
                  _buildSkillsDropdown(),
                  _buildEducationDropdown(),
                  _buildExperienceDropdown(),
                  _buildSpecializationDropdown(),
                  _buildTestSection(),
                  SizedBox(height: 20.h),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(
                      'Save Changes',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        _updateJobInFirestore(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 20.w),
                      minimumSize: Size(double.infinity, 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
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

  Widget _buildJobTypeDropdown({bool required = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Employment Type',
          labelStyle: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
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
        ),
        items: jobTypeOptions.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
        value: _selectedJobType,
        onChanged: (value) => setState(() => _selectedJobType = value),
        validator: required
            ? (value) => value == null || value.isEmpty ? 'Required field' : null
            : null,
        onSaved: (value) => updatedJobData['jobType'] = value ?? '',
      ),
    );
  }

  Widget _buildSalaryFields() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _minSalaryController,
              decoration: InputDecoration(
                labelText: 'Min Salary',
                labelStyle: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
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
              ),
              style: TextStyle(fontSize: 14.sp),
              validator: (value) => value == null || value.trim().isEmpty ? 'Required field' : null,
              onSaved: (value) => updatedJobData['minSalary'] = value ?? '',
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: TextFormField(
              controller: _maxSalaryController,
              decoration: InputDecoration(
                labelText: 'Max Salary',
                labelStyle: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
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
              ),
              style: TextStyle(fontSize: 14.sp),
              validator: (value) => value == null || value.trim().isEmpty ? 'Required field' : null,
              onSaved: (value) => updatedJobData['maxSalary'] = value ?? '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsDropdown() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Container(
          constraints: BoxConstraints(maxWidth: double.infinity),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.cyan.shade50, Colors.teal.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.teal.shade100),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bolt_outlined,
                    size: 18.sp,
                    color: Colors.teal.shade700,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Skills',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.teal.shade800,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              SkillsAutocompleteMultiSelect(
                value: _selectedSkills,
                onChanged: (skills) {
                  setState(() {
                    _selectedSkills = skills;
                    updatedJobData['skills'] = skills.join(', ');
                  });
                },
                labelText: '',
                hintText: 'Type to search skills',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEducationDropdown() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Education',
          labelStyle: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
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
        ),
        items: educationOptions.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Container(
              constraints: BoxConstraints(maxWidth: 250.w),
              child: Text(
                option,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TextStyle(fontSize: 12.sp),
              ),
            ),
          );
        }).toList(),
        value: _selectedEducation,
        onChanged: (value) {
          setState(() => _selectedEducation = value);
          updatedJobData['education'] = value ?? '';
        },
        onSaved: (value) => updatedJobData['education'] = value ?? '',
      ),
    );
  }

  Widget _buildExperienceDropdown() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Experience',
          labelStyle: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
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
        ),
        items: experienceOptions.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
        value: _selectedExperience,
        onChanged: (value) {
          setState(() => _selectedExperience = value);
          updatedJobData['experience'] = value ?? '';
        },
        onSaved: (value) => updatedJobData['experience'] = value ?? '',
      ),
    );
  }

  Widget _buildSpecializationDropdown() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Specialization',
          labelStyle: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
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
        ),
        items: specializationOptions.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Container(
              constraints: BoxConstraints(maxWidth: 250.w),
              child: Text(
                option,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TextStyle(fontSize: 12.sp),
              ),
            ),
          );
        }).toList(),
        value: _selectedSpecialization,
        onChanged: (value) {
          setState(() => _selectedSpecialization = value);
          updatedJobData['specialization'] = value ?? '';
        },
        onSaved: (value) => updatedJobData['specialization'] = value ?? '',
      ),
    );
  }

  Widget _buildTestSection() {
    const accentColor = Color(0xFF0F766E);
    
    List<Widget> testChildren = [
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
    ];
    
    if (_includeTest) {
      testChildren.add(
        Column(
          children: [
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
        ),
      );
    }
    
    return _buildSectionCard(
      icon: Icons.quiz_outlined,
      title: 'Test Question (Optional)',
      subtitle: 'Add a screening test for candidates.',
      children: testChildren,
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

  Map<String, dynamic> _getFormattedUpdatedData() {
    final updatedData = Map<String, dynamic>.from(updatedJobData);
    
    // Combine min and max salary into salary range
    final minSalary = updatedData.remove('minSalary');
    final maxSalary = updatedData.remove('maxSalary');
    
    if (minSalary != null && maxSalary != null) {
      updatedData['salary'] = '$minSalary-$maxSalary LPA (INR)';
    }
    
    // Add test data if included
    updatedData['includeTest'] = _includeTest;
    if (_includeTest) {
      updatedData['testQuestions'] = _testQuestions;
    }
    
    return updatedData;
  }

  Future<void> _updateJobInFirestore(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('Recruiters')
          .doc(uid)
          .collection('Jobs')
          .doc(widget.jobId)
          .update(_getFormattedUpdatedData());

      if (!mounted) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job updated successfully!')),
        );
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      dev.log('Failed to update job: $e', name: 'EditJobScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update job: $e')),
        );
      }
    }
  }
}