// ignore_for_file: unrelated_type_equality_checks

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:naukariwala/services/auth_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:developer' as dev;

class ProfileScreen extends StatefulWidget {
  final bool isRecruiter;

  const ProfileScreen({this.isRecruiter = false, super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  // Controllers for editable fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyProfileController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _currentCtcController = TextEditingController();
  final TextEditingController _expectedCtcController = TextEditingController();

  // Non-editable fields
  String? _mobileNumber;
  String? _email;

  // Dropdown and multi-select fields for seekers
  String? _selectedSpecialization;
  String? _selectedEducation;
  List<String> _selectedSkills = [];

  // Track if profile has been updated
  bool _isProfileUpdated = false;

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

  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _currentCtcController.addListener(_formatCtcOnChange);
    _expectedCtcController.addListener(_formatCtcOnChange);
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => errorMessage = 'No user logged in');
      }
      return;
    }

    try {
      setState(() => isLoading = true);
      final data = await _authService.fetchProfileData(isRecruiter: widget.isRecruiter);
      if (mounted) {
        if (data != null) {
          dev.log('Firestore data: $data', name: 'ProfileScreen');
          setState(() {
            _nameController.text = data['name']?.toString().trim() ?? '';
            _mobileNumber = data['mobileNumber']?.toString().trim() ??
                data['mobile']?.toString().trim() ??
                data['Mobile Number']?.toString().trim();
            if (_mobileNumber == null || _mobileNumber!.isEmpty) {
              dev.log('Warning: Mobile number not found in Firestore data for UID: ${user.uid}', name: 'ProfileScreen');
            }
            _email = user.email?.trim() ?? '';
            if (widget.isRecruiter) {
              _companyNameController.text = data['companyName']?.toString().trim() ?? '';
              _companyProfileController.text = data['companyProfile']?.toString().trim() ?? '';
              _designationController.text = data['designation']?.toString().trim() ?? '';
            } else {
              _experienceController.text = data['experience']?.toString().trim() ?? '';
              final education = data['education']?.toString().trim();
              _selectedEducation = education != null && educationOptions.contains(education)
                  ? education
                  : education != null && education.isNotEmpty
                      ? 'Other'
                      : null;
              _selectedSkills = (data['skills'] as List<dynamic>?)?.cast<String>() ?? [];
              _selectedSpecialization = specializationOptions.contains(data['specialization'])
                  ? data['specialization']
                  : 'Others';
              _currentCtcController.text = _formatCtc(data['currentCtc']?.toString().trim() ?? '');
              _expectedCtcController.text = _formatCtc(data['expectedCtc']?.toString().trim() ?? '');
            }
            _isProfileUpdated = data['name'] != null && data['name'].toString().trim().isNotEmpty &&
                (widget.isRecruiter ? data['companyName'] != null : data['education'] != null);
          });
        } else {
          setState(() {
            errorMessage = 'Profile not found';
            dev.log('No profile data found for UID: ${user.uid}', name: 'ProfileScreen');
          });
        }
      }
    } catch (e) {
      dev.log('Error loading profile: $e', name: 'ProfileScreen', error: e);
      if (mounted) {
        setState(() => errorMessage = 'Error loading profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _formatCtc(String value) {
    value = value.replaceAll(' LPA (INR)', '').trim();
    double? number = double.tryParse(value);
    if (number == null) {
      return '0.0 LPA (INR)';
    }
    return '${number.toStringAsFixed(1)} LPA (INR)';
  }

  void _formatCtcOnChange() {
    final controller = _currentCtcController == FocusScope.of(context).focusedChild?.context?.widget
        ? _currentCtcController
        : _expectedCtcController;

    final value = controller.text;
    final formattedValue = _formatCtc(value);
    if (controller.text != formattedValue) {
      final selection = controller.selection;
      controller.text = formattedValue;
      controller.selection = selection.extent.offset == value.length
          ? TextSelection.fromPosition(TextPosition(offset: formattedValue.length))
          : TextSelection.collapsed(offset: selection.extent.offset);
    }
  }

  Map<String, dynamic> _generateResumeData() {
    if (widget.isRecruiter) return {};
    return {
      'name': _nameController.text.trim(),
      'email': _email ?? '',
      'mobileNumber': _mobileNumber ?? '',
      'skills': _selectedSkills,
      'education': _selectedEducation ?? 'Other',
      'experience': _experienceController.text.trim(),
      'specialization': _selectedSpecialization ?? 'Others',
      'currentCtc': _currentCtcController.text.replaceAll(' LPA (INR)', '').trim(),
      'expectedCtc': _expectedCtcController.text.replaceAll(' LPA (INR)', '').trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _updateProfile(Map<String, dynamic> profileData, Function setDialogState) async {
    final user = _auth.currentUser;
    if (user == null) {
      setDialogState(() => errorMessage = 'No user logged in');
      return;
    }

    if (profileData['name'].trim().isEmpty) {
      setDialogState(() => errorMessage = 'Name is required');
      return;
    }
    if (_mobileNumber == null || _mobileNumber!.trim().isEmpty) {
      setDialogState(() => errorMessage = 'Mobile number is required. Please ensure it is set in your profile.');
      return;
    }
    if (widget.isRecruiter) {
      if (profileData['companyName'].trim().isEmpty) {
        setDialogState(() => errorMessage = 'Company Name is required');
        return;
      }
    } else {
      if (profileData['skills'].isEmpty) {
        setDialogState(() => errorMessage = 'At least one skill is required');
        return;
      }
      if (profileData['education'] == null) {
        setDialogState(() => errorMessage = 'Education is required');
        return;
      }
      if (profileData['experience'].trim().isEmpty) {
        setDialogState(() => errorMessage = 'Experience is required');
        return;
      }
      if (!experienceOptions.contains(profileData['experience'].trim())) {
        setDialogState(() => errorMessage = 'Please select a valid experience level');
        return;
      }
      if (profileData['specialization'] == null) {
        setDialogState(() => errorMessage = 'Specialization is required');
        return;
      }
    }

    setDialogState(() => isLoading = true);
    try {
      dev.log('Updating profile with data: $profileData', name: 'ProfileScreen');
      await _authService.storeSignupData(
        isRecruiter: widget.isRecruiter,
        data: profileData,
      );

      if (mounted) {
        setState(() {
          _isProfileUpdated = true;
          _nameController.text = profileData['name'];
          if (widget.isRecruiter) {
            _companyNameController.text = profileData['companyName'];
            _companyProfileController.text = profileData['companyProfile'];
            _designationController.text = profileData['designation'];
          } else {
            _selectedSkills = List<String>.from(profileData['skills']);
            _selectedEducation = profileData['education'];
            _experienceController.text = profileData['experience'];
            _selectedSpecialization = profileData['specialization'];
            _currentCtcController.text = _formatCtc(profileData['currentCtc']);
            _expectedCtcController.text = _formatCtc(profileData['expectedCtc']);
          }
          errorMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      dev.log('Error updating profile: $e', name: 'ProfileScreen', error: e);
      if (mounted) {
        setDialogState(() => errorMessage = 'Error updating profile: $e');
      }
    } finally {
      if (mounted) {
        setDialogState(() => isLoading = false);
      }
    }
  }

  void _showUpdateProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => ProfileDialog(
        isRecruiter: widget.isRecruiter,
        initialData: {
          'name': _nameController.text,
          'companyName': _companyNameController.text,
          'companyProfile': _companyProfileController.text,
          'designation': _designationController.text,
          'experience': _experienceController.text,
          'currentCtc': _currentCtcController.text,
          'expectedCtc': _expectedCtcController.text,
          'specialization': _selectedSpecialization,
          'education': _selectedEducation,
          'skills': List<String>.from(_selectedSkills),
        },
        experienceOptions: experienceOptions,
        specializationOptions: specializationOptions,
        educationOptions: educationOptions,
        skillsBySpecialization: skillsBySpecialization,
        isProfileUpdated: _isProfileUpdated,
        mobileNumber: _mobileNumber,
        onUpdate: _updateProfile,
      ),
    );
  }

  Widget _buildTextField(String label,
      {bool isPassword = false,
      bool multiline = false,
      TextEditingController? controller,
      String? Function(String?)? validator}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: TextFormField(
          controller: controller,
          obscureText: isPassword,
          maxLines: multiline ? 4 : 1,
          maxLength: multiline ? 500 : 100,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.teal, width: 2.w),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            counterText: multiline ? null : '',
          ),
          validator: validator,
          onChanged: (value) {
            if (mounted) setState(() => errorMessage = null);
          },
        ),
      ),
    );
  }

  Widget _buildNonEditableField(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: TextFormField(
          initialValue: value ?? 'N/A',
          enabled: false,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.teal, width: 2.w),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          ),
          style: TextStyle(fontSize: 14.sp, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildSpecializationDropdown({bool enabled = true}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: DropdownButtonFormField<String>(
          value: _selectedSpecialization,
          decoration: InputDecoration(
            labelText: 'Specialization',
            labelStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12.r),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.teal, width: 2.w),
              borderRadius: BorderRadius.circular(12.r),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          ),
          isExpanded: true,
          menuMaxHeight: 300.h,
          items: specializationOptions.map((String specialization) {
            return DropdownMenuItem<String>(
              value: specialization,
              child: Container(
                constraints: BoxConstraints(maxWidth: 250.w),
                child: Text(
                  specialization,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.black87, fontSize: 12.sp),
                ),
              ),
            );
          }).toList(),
          onChanged: enabled
              ? (value) {
                  if (mounted) {
                    setState(() {
                      _selectedSpecialization = value;
                      _selectedSkills = [];
                      errorMessage = null;
                    });
                  }
                }
              : null,
          validator: (value) => value == null ? 'Specialization is required' : null,
        ),
      ),
    );
  }

  Widget _buildEducationDropdown({bool enabled = true}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: DropdownButtonFormField<String>(
          value: _selectedEducation,
          decoration: InputDecoration(
            labelText: 'Education',
            labelStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12.r),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.teal, width: 2.w),
              borderRadius: BorderRadius.circular(12.r),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          ),
          isExpanded: true,
          menuMaxHeight: 300.h,
          items: educationOptions.map((String education) {
            return DropdownMenuItem<String>(
              value: education,
              child: Container(
                constraints: BoxConstraints(maxWidth: 250.w),
                child: Text(
                  education,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.black87, fontSize: 12.sp),
                ),
              ),
            );
          }).toList(),
          onChanged: enabled
              ? (value) {
                  if (mounted) {
                    setState(() {
                      _selectedEducation = value;
                      errorMessage = null;
                    });
                  }
                }
              : null,
          validator: (value) => value == null ? 'Education is required' : null,
        ),
      ),
    );
  }

  Widget _buildExperienceDropdown({bool enabled = true}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: DropdownButtonFormField<String>(
          value: _experienceController.text.isNotEmpty &&
                  experienceOptions.contains(_experienceController.text)
              ? _experienceController.text
              : null,
          decoration: InputDecoration(
            labelText: 'Experience',
            labelStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12.r),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.teal, width: 2.w),
              borderRadius: BorderRadius.circular(12.r),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          ),
          isExpanded: true,
          menuMaxHeight: 300.h,
          items: experienceOptions.map((String experience) {
            return DropdownMenuItem<String>(
              value: experience,
              child: Container(
                constraints: BoxConstraints(maxWidth: 250.w),
                child: Text(
                  experience,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.black87, fontSize: 12.sp),
                ),
              ),
            );
          }).toList(),
          onChanged: enabled
              ? (value) {
                  if (mounted) {
                    setState(() {
                      _experienceController.text = value ?? '';
                      errorMessage = null;
                    });
                  }
                }
              : null,
          validator: (value) => value == null ? 'Experience is required' : null,
        ),
      ),
    );
  }

  Widget _buildSkillsMultiSelect({bool enabled = true}) {
    final availableSkills = skillsBySpecialization[_selectedSpecialization ?? 'Others'] ?? [];
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        child: Container(
          constraints: BoxConstraints(maxWidth: 300.w),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: GestureDetector(
            onTap: enabled
                ? () async {
                    final selected = await showDialog<List<String>>(
                      context: context,
                      builder: (context) => MultiSelectDialog(
                        items: availableSkills,
                        selectedItems: _selectedSkills,
                      ),
                    );
                    if (selected != null && mounted) {
                      setState(() {
                        _selectedSkills = selected;
                        errorMessage = null;
                      });
                    }
                  }
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skills',
                  style: TextStyle(fontSize: 12.sp, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                SizedBox(height: 6.h),
                Container(
                  constraints: BoxConstraints(maxWidth: 250.w),
                  child: Text(
                    _selectedSkills.isEmpty ? 'Select skills' : _selectedSkills.join(', '),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: _selectedSkills.isEmpty ? Colors.grey : Colors.black87,
                    ),
                  ),
                ),
                if (_selectedSkills.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Text(
                      'At least one skill is required',
                      style: TextStyle(fontSize: 10.sp, color: Colors.red.shade700),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentCtcController.removeListener(_formatCtcOnChange);
    _expectedCtcController.removeListener(_formatCtcOnChange);
    _nameController.dispose();
    _companyNameController.dispose();
    _companyProfileController.dispose();
    _designationController.dispose();
    _experienceController.dispose();
    _currentCtcController.dispose();
    _expectedCtcController.dispose();
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
            title: Text(
              widget.isRecruiter ? 'Recruiter Profile' : 'Seeker Profile',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18.sp),
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
            actions: [
              if (!widget.isRecruiter)
                IconButton(
                  icon: const Icon(Icons.description, color: Colors.white, size: 22),
                  padding: EdgeInsets.all(2.w),
                  onPressed: () {
                    dev.log('Opening resume preview', name: 'ProfileScreen');
                    final resumeData = _generateResumeData();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        title: Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade700, Colors.blue.shade900],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                          ),
                          child: const Text(
                            'Resume Preview',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        content: SingleChildScrollView(
                          child: Container(
                            constraints: BoxConstraints(maxWidth: 300.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Email: ${resumeData['email'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                                Text('Mobile: ${resumeData['mobileNumber'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                                Text('Name: ${resumeData['name'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                                SizedBox(height: 6.h),
                                Text('Skills:', style: TextStyle(fontSize: 12.sp, color: Colors.blue.shade800)),
                                Wrap(
                                  spacing: 6.w,
                                  runSpacing: 4.h,
                                  children: (resumeData['skills'] as List<dynamic>?)?.cast<String>().map((skill) => Chip(
                                        label: Text(skill, style: TextStyle(fontSize: 12.sp)),
                                        backgroundColor: Colors.teal.shade100,
                                        labelStyle: TextStyle(color: Colors.teal.shade900),
                                      )).toList() ??
                                      [
                                        Chip(
                                          label: const Text('N/A', style: TextStyle(fontSize: 12)),
                                          backgroundColor: Colors.grey.shade200,
                                        )
                                      ],
                                ),
                                Text('Education: ${resumeData['education'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                                Text('Experience: ${resumeData['experience'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                                Text('Specialization: ${resumeData['specialization'] ?? 'N/A'}', style: TextStyle(fontSize: 14.sp)),
                                Text('Current CTC: ${_formatCtc(resumeData['currentCtc'] ?? '0.0')}', style: TextStyle(fontSize: 14.sp)),
                                Text('Expected CTC: ${_formatCtc(resumeData['expectedCtc'] ?? '0.0')}', style: TextStyle(fontSize: 14.sp)),
                              ],
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close', style: TextStyle(color: Colors.teal, fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          body: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                    strokeWidth: 4.w,
                  ),
                )
              : errorMessage != null
                  ? Center(
                      child: Card(
                        elevation: 4,
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: EdgeInsets.all(12.w),
                          child: Text(
                            errorMessage!,
                            style: TextStyle(color: Colors.red.shade700, fontSize: 14.sp),
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(16.w),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        child: Padding(
                          padding: EdgeInsets.all(12.w),
                          child: Form(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 16.h),
                                _buildNonEditableField('Email', _email),
                                _buildNonEditableField('Mobile Number', _mobileNumber),
                                if (_isProfileUpdated)
                                  _buildNonEditableField('Name', _nameController.text)
                                else
                                  _buildTextField(
                                    'Name',
                                    controller: _nameController,
                                    validator: (value) => value == null || value.trim().isEmpty ? 'Name is required' : null,
                                  ),
                                if (widget.isRecruiter) ...[
                                  if (_isProfileUpdated)
                                    _buildNonEditableField('Company Name', _companyNameController.text)
                                  else
                                    _buildTextField(
                                      'Company Name',
                                      controller: _companyNameController,
                                      validator: (value) => value == null || value.trim().isEmpty ? 'Company Name is required' : null,
                                    ),
                                  if (_isProfileUpdated)
                                    _buildNonEditableField('Company Profile', _companyProfileController.text)
                                  else
                                    _buildTextField('Company Profile', multiline: true, controller: _companyProfileController),
                                  if (_isProfileUpdated)
                                    _buildNonEditableField('Designation', _designationController.text)
                                  else
                                    _buildTextField('Designation', controller: _designationController),
                                ] else ...[
                                  if (_isProfileUpdated)
                                    _buildNonEditableField('Specialization', _selectedSpecialization)
                                  else
                                    _buildSpecializationDropdown(),
                                  if (_isProfileUpdated)
                                    _buildNonEditableField('Skills', _selectedSkills.isEmpty ? 'N/A' : _selectedSkills.join(', '))
                                  else
                                    _buildSkillsMultiSelect(),
                                  if (_isProfileUpdated)
                                    _buildNonEditableField('Education', _selectedEducation)
                                  else
                                    _buildEducationDropdown(),
                                  if (_isProfileUpdated)
                                    _buildNonEditableField('Experience', _experienceController.text)
                                  else
                                    _buildExperienceDropdown(),
                                  if (_isProfileUpdated)
                                    _buildNonEditableField('Current CTC', _currentCtcController.text)
                                  else
                                    _buildTextField('Current CTC', controller: _currentCtcController),
                                  if (_isProfileUpdated)
                                    _buildNonEditableField('Expected CTC', _expectedCtcController.text)
                                  else
                                    _buildTextField('Expected CTC', controller: _expectedCtcController),
                                ],
                                SizedBox(height: 16.h),
                                Center(
                                  child: AnimatedScaleButton(
                                    onPressed: _showUpdateProfileDialog,
                                    child: Container(
                                      constraints: BoxConstraints(maxWidth: 200.w),
                                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
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
                                        _isProfileUpdated ? 'Edit Profile' : 'Update Profile',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12.h),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
        );
      },
    );
  }
}

class ProfileDialog extends StatefulWidget {
  final bool isRecruiter;
  final Map<String, dynamic> initialData;
  final List<String> experienceOptions;
  final List<String> specializationOptions;
  final List<String> educationOptions;
  final Map<String, List<String>> skillsBySpecialization;
  final bool isProfileUpdated;
  final String? mobileNumber;
  final Future<void> Function(Map<String, dynamic>, Function) onUpdate;

  const ProfileDialog({
    required this.isRecruiter,
    required this.initialData,
    required this.experienceOptions,
    required this.specializationOptions,
    required this.educationOptions,
    required this.skillsBySpecialization,
    required this.isProfileUpdated,
    required this.mobileNumber,
    required this.onUpdate,
    super.key,
  });

  @override
  ProfileDialogState createState() => ProfileDialogState();
}

class ProfileDialogState extends State<ProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _companyNameController;
  late final TextEditingController _companyProfileController;
  late final TextEditingController _designationController;
  late final TextEditingController _experienceController;
  late final TextEditingController _currentCtcController;
  late final TextEditingController _expectedCtcController;
  String? _specialization;
  String? _education;
  List<String> _skills = [];
  // ignore: prefer_final_fields
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData['name']);
    _companyNameController = TextEditingController(text: widget.initialData['companyName']);
    _companyProfileController = TextEditingController(text: widget.initialData['companyProfile']);
    _designationController = TextEditingController(text: widget.initialData['designation']);
    _experienceController = TextEditingController(text: widget.initialData['experience']);
    _currentCtcController = TextEditingController(text: widget.initialData['currentCtc']);
    _expectedCtcController = TextEditingController(text: widget.initialData['expectedCtc']);
    _specialization = widget.initialData['specialization'];
    _education = widget.initialData['education'];
    _skills = List<String>.from(widget.initialData['skills']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyNameController.dispose();
    _companyProfileController.dispose();
    _designationController.dispose();
    _experienceController.dispose();
    _currentCtcController.dispose();
    _expectedCtcController.dispose();
    super.dispose();
  }

  Widget _buildTextField(String label,
      {bool multiline = false, TextEditingController? controller, String? Function(String?)? validator}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: TextFormField(
          controller: controller,
          maxLines: multiline ? 4 : 1,
          maxLength: multiline ? 500 : 100,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12.r),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.teal, width: 2.w),
              borderRadius: BorderRadius.circular(12.r),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            counterText: multiline ? null : '',
          ),
          validator: validator,
          onChanged: (value) {
            if (mounted) setState(() => _errorMessage = null);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        child: Text(
          widget.isProfileUpdated ? 'Edit Profile' : 'Update Profile',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      content: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(maxWidth: 300.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12.sp),
                  ),
                ),
              _buildTextField(
                'Name',
                controller: _nameController,
                validator: (value) => value == null || value.trim().isEmpty ? 'Name is required' : null,
              ),
              if (widget.isRecruiter) ...[
                _buildTextField(
                  'Company Name',
                  controller: _companyNameController,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Company Name is required' : null,
                ),
                _buildTextField(
                  'Company Profile',
                  multiline: true,
                  controller: _companyProfileController,
                ),
                _buildTextField(
                  'Designation',
                  controller: _designationController,
                ),
              ] else ...[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 300.w),
                    child: DropdownButtonFormField<String>(
                      value: _specialization,
                      decoration: InputDecoration(
                        labelText: 'Specialization',
                        labelStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal, width: 2.w),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      ),
                      isExpanded: true,
                      menuMaxHeight: 300.h,
                      items: widget.specializationOptions.map((String specialization) {
                        return DropdownMenuItem<String>(
                          value: specialization,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: 250.w),
                            child: Text(
                              specialization,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.black87, fontSize: 12.sp),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _specialization = value;
                          _skills = [];
                          _errorMessage = null;
                        });
                      },
                      validator: (value) => value == null ? 'Specialization is required' : null,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 300.w),
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade50, Colors.blue.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: GestureDetector(
                        onTap: () async {
                          final selected = await showDialog<List<String>>(
                            context: context,
                            builder: (context) => MultiSelectDialog(
                              items: widget.skillsBySpecialization[_specialization ?? 'Others'] ?? [],
                              selectedItems: _skills,
                            ),
                          );
                          if (selected != null) {
                            setState(() {
                              _skills = selected;
                              _errorMessage = null;
                            });
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Skills',
                              style: TextStyle(fontSize: 12.sp, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            SizedBox(height: 6.h),
                            Container(
                              constraints: BoxConstraints(maxWidth: 250.w),
                              child: Text(
                                _skills.isEmpty ? 'Select skills' : _skills.join(', '),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: _skills.isEmpty ? Colors.grey : Colors.black87,
                                ),
                              ),
                            ),
                            if (_skills.isEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 6.h),
                                child: Text(
                                  'At least one skill is required',
                                  style: TextStyle(fontSize: 10.sp, color: Colors.red.shade700),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 300.w),
                    child: DropdownButtonFormField<String>(
                      value: _education,
                      decoration: InputDecoration(
                        labelText: 'Education',
                        labelStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal, width: 2.w),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      ),
                      isExpanded: true,
                      menuMaxHeight: 300.h,
                      items: widget.educationOptions.map((String education) {
                        return DropdownMenuItem<String>(
                          value: education,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: 250.w),
                            child: Text(
                              education,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.black87, fontSize: 12.sp),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _education = value;
                          _errorMessage = null;
                        });
                      },
                      validator: (value) => value == null ? 'Education is required' : null,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 300.w),
                    child: DropdownButtonFormField<String>(
                      value: _experienceController.text.isNotEmpty &&
                              widget.experienceOptions.contains(_experienceController.text)
                          ? _experienceController.text
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Experience',
                        labelStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal, width: 2.w),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      ),
                      isExpanded: true,
                      menuMaxHeight: 300.h,
                      items: widget.experienceOptions.map((String experience) {
                        return DropdownMenuItem<String>(
                          value: experience,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: 250.w),
                            child: Text(
                              experience,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.black87, fontSize: 12.sp),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _experienceController.text = value ?? '';
                          _errorMessage = null;
                        });
                      },
                      validator: (value) => value == null ? 'Experience is required' : null,
                    ),
                  ),
                ),
                _buildTextField('Current CTC', controller: _currentCtcController),
                _buildTextField('Expected CTC', controller: _expectedCtcController),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(
            'Back',
            style: TextStyle(color: Colors.grey, fontSize: 12.sp),
          ),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  final profileData = widget.isRecruiter
                      ? {
                          'name': _nameController.text.trim(),
                          'mobileNumber': widget.mobileNumber!.trim(),
                          'companyName': _companyNameController.text.trim(),
                          'companyProfile': _companyProfileController.text.trim(),
                          'designation': _designationController.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        }
                      : {
                          'name': _nameController.text.trim(),
                          'mobileNumber': widget.mobileNumber!.trim(),
                          'skills': _skills,
                          'education': _education,
                          'experience': _experienceController.text.trim(),
                          'specialization': _specialization,
                          'currentCtc': _currentCtcController.text.replaceAll(' LPA (INR)', '').trim(),
                          'expectedCtc': _expectedCtcController.text.replaceAll(' LPA (INR)', '').trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        };
                  widget.onUpdate(profileData, setState);
                },
          child: _isLoading
              ? SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.w,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                  ),
                )
              : Text(
                  'Save',
                  style: TextStyle(color: Colors.teal, fontSize: 12.sp),
                ),
        ),
      ],
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

class MultiSelectDialog extends StatefulWidget {
  final List<String> items;
  final List<String> selectedItems;

  const MultiSelectDialog({required this.items, required this.selectedItems, super.key});

  @override
  MultiSelectDialogState createState() => MultiSelectDialogState();
}

class MultiSelectDialogState extends State<MultiSelectDialog> {
  late List<String> _tempSelectedItems;

  @override
  void initState() {
    super.initState();
    _tempSelectedItems = List.from(widget.selectedItems);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        child: const Text(
          'Select Skills',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      content: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(maxWidth: 300.w),
          child: Column(
            children: widget.items.map((item) {
              return CheckboxListTile(
                title: Text(
                  item,
                  style: TextStyle(color: Colors.black87, fontSize: 12.sp),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                value: _tempSelectedItems.contains(item),
                activeColor: Colors.teal,
                checkColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _tempSelectedItems.add(item);
                    } else {
                      _tempSelectedItems.remove(item);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, _tempSelectedItems);
          },
          child: const Text('OK', style: TextStyle(color: Colors.teal, fontSize: 12)),
        ),
      ],
    );
  }
}