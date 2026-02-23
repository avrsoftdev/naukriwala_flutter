// ignore_for_file: unrelated_type_equality_checks

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:naukariwala/services/auth_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
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
  final TextEditingController _companyProfileController =
      TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _currentCtcController = TextEditingController();
  final TextEditingController _expectedCtcController = TextEditingController();

  // Non-editable fields
  String? _mobileNumber;
  String? _email;
  String? _profilePhotoUrl;

  // Dropdown and multi-select fields for seekers
  String? _selectedSpecialization;
  String? _selectedEducation;
  List<String> _selectedSkills = [];

  // Track if profile has been updated
  bool _isProfileUpdated = false;
  bool _isUploadingProfilePhoto = false;

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

  final List<String> specializationOptions = [
    'Others',
    'IT/Software',
    'Business / Finance / Management',
    'Design / Media / Communication',
    'Medicine / Healthcare / Pharma',
    'Engineering',
  ];

  final List<String> educationOptions = [
    'Secondary (Class 10)',
    'Higher Secondary (Class 12)',
    'Diploma/Certificate',
    'Undergraduate (Bachelor\'s Degree)',
    'Postgraduate (Master\'s Degree)',
  ];

  final Map<String, List<String>> skillsBySpecialization = {
    'Others': ['Communication Skills', 'Problem Solving', 'Teamwork'],
    'IT/Software': ['Java', 'Python', 'Dart', 'Flutter', 'React', 'Node.js'],
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
      final data = await _authService.fetchProfileData(
        isRecruiter: widget.isRecruiter,
      );
      if (mounted) {
        if (data != null) {
          dev.log('Firestore data: $data', name: 'ProfileScreen');
          setState(() {
            _nameController.text = data['name']?.toString().trim() ?? '';
            _mobileNumber =
                data['mobileNumber']?.toString().trim() ??
                data['mobile']?.toString().trim() ??
                data['Mobile Number']?.toString().trim();
            if (_mobileNumber == null || _mobileNumber!.isEmpty) {
              dev.log(
                'Warning: Mobile number not found in Firestore data for UID: ${user.uid}',
                name: 'ProfileScreen',
              );
            }
            _email = user.email?.trim() ?? '';
            _profilePhotoUrl = data['photoUrl']?.toString().trim();
            if (_profilePhotoUrl != null && _profilePhotoUrl!.isEmpty) {
              _profilePhotoUrl = null;
            }
            if (widget.isRecruiter) {
              _companyNameController.text =
                  data['companyName']?.toString().trim() ?? '';
              _companyProfileController.text =
                  data['companyProfile']?.toString().trim() ?? '';
              _designationController.text =
                  data['designation']?.toString().trim() ?? '';
            } else {
              _experienceController.text =
                  data['experience']?.toString().trim() ?? '';
              final education = data['education']?.toString().trim();
              _selectedEducation =
                  education != null && educationOptions.contains(education)
                  ? education
                  : education != null && education.isNotEmpty
                  ? 'Other'
                  : null;
              _selectedSkills =
                  (data['skills'] as List<dynamic>?)?.cast<String>() ?? [];
              _selectedSpecialization =
                  specializationOptions.contains(data['specialization'])
                  ? data['specialization']
                  : 'Others';
              _currentCtcController.text = _formatCtc(
                data['currentCtc']?.toString().trim() ?? '',
              );
              _expectedCtcController.text = _formatCtc(
                data['expectedCtc']?.toString().trim() ?? '',
              );
            }
            _isProfileUpdated =
                data['name'] != null &&
                data['name'].toString().trim().isNotEmpty &&
                (widget.isRecruiter
                    ? data['companyName'] != null
                    : data['education'] != null);
          });
        } else {
          setState(() {
            errorMessage = 'Profile not found';
            dev.log(
              'No profile data found for UID: ${user.uid}',
              name: 'ProfileScreen',
            );
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

  Future<void> _pickAndUploadProfilePhoto() async {
    if (_isUploadingProfilePhoto) return;

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image == null) return;

      if (mounted) {
        setState(() => _isUploadingProfilePhoto = true);
      }

      final photoUrl = await _authService.uploadProfilePhoto(
        file: File(image.path),
        isRecruiter: widget.isRecruiter,
      );

      if (mounted) {
        setState(() {
          _profilePhotoUrl = photoUrl;
          _isUploadingProfilePhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      dev.log(
        'Error uploading profile photo: $e',
        name: 'ProfileScreen',
        error: e,
      );
      if (mounted) {
        setState(() => _isUploadingProfilePhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload profile photo: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    final controller =
        _currentCtcController ==
            FocusScope.of(context).focusedChild?.context?.widget
        ? _currentCtcController
        : _expectedCtcController;

    final value = controller.text;
    final formattedValue = _formatCtc(value);
    if (controller.text != formattedValue) {
      final selection = controller.selection;
      controller.text = formattedValue;
      controller.selection = selection.extent.offset == value.length
          ? TextSelection.fromPosition(
              TextPosition(offset: formattedValue.length),
            )
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
      'currentCtc': _currentCtcController.text
          .replaceAll(' LPA (INR)', '')
          .trim(),
      'expectedCtc': _expectedCtcController.text
          .replaceAll(' LPA (INR)', '')
          .trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _updateProfile(
    Map<String, dynamic> profileData,
    Function setDialogState,
  ) async {
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
      setDialogState(
        () => errorMessage =
            'Mobile number is required. Please ensure it is set in your profile.',
      );
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
        setDialogState(
          () => errorMessage = 'Please select a valid experience level',
        );
        return;
      }
      if (profileData['specialization'] == null) {
        setDialogState(() => errorMessage = 'Specialization is required');
        return;
      }
    }

    setDialogState(() => isLoading = true);
    try {
      dev.log(
        'Updating profile with data: $profileData',
        name: 'ProfileScreen',
      );
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
            _expectedCtcController.text = _formatCtc(
              profileData['expectedCtc'],
            );
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

  InputDecoration _fieldDecoration(
    String label, {
    IconData? icon,
    bool enabled = true,
  }) {
    final borderColor = enabled
        ? Colors.blueGrey.shade200
        : Colors.blueGrey.shade100;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.blueGrey.shade600,
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 18.sp, color: Colors.blueGrey.shade500),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(14.r),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.teal.shade500, width: 1.8.w),
        borderRadius: BorderRadius.circular(14.r),
      ),
      disabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blueGrey.shade100),
        borderRadius: BorderRadius.circular(14.r),
      ),
      filled: true,
      fillColor: enabled ? Colors.white : Colors.blueGrey.shade50,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
    );
  }

  IconData _iconForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'email':
        return Icons.mail_outline;
      case 'mobile number':
        return Icons.phone_outlined;
      case 'name':
        return Icons.person_outline;
      case 'company name':
        return Icons.apartment_outlined;
      case 'company profile':
        return Icons.business_center_outlined;
      case 'designation':
        return Icons.badge_outlined;
      case 'specialization':
        return Icons.auto_awesome_mosaic_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'experience':
        return Icons.timeline_outlined;
      case 'current ctc':
      case 'expected ctc':
        return Icons.currency_rupee_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 18.h,
            decoration: BoxDecoration(
              color: Colors.teal.shade500,
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label, {
    bool isPassword = false,
    bool multiline = false,
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: TextFormField(
          controller: controller,
          obscureText: isPassword,
          maxLines: multiline ? 4 : 1,
          maxLength: multiline ? 500 : 100,
          decoration: _fieldDecoration(
            label,
            icon: _iconForLabel(label),
          ).copyWith(counterText: multiline ? null : ''),
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
          decoration: _fieldDecoration(
            label,
            enabled: false,
            icon: _iconForLabel(label),
          ),
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.blueGrey.shade700,
            fontWeight: FontWeight.w500,
          ),
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
          initialValue: _selectedSpecialization,
          decoration: _fieldDecoration(
            'Specialization',
            enabled: enabled,
            icon: _iconForLabel('Specialization'),
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
          validator: (value) =>
              value == null ? 'Specialization is required' : null,
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
          initialValue: _selectedEducation,
          decoration: _fieldDecoration(
            'Education',
            enabled: enabled,
            icon: _iconForLabel('Education'),
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
          initialValue:
              _experienceController.text.isNotEmpty &&
                  experienceOptions.contains(_experienceController.text)
              ? _experienceController.text
              : null,
          decoration: _fieldDecoration(
            'Experience',
            enabled: enabled,
            icon: _iconForLabel('Experience'),
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
    final availableSkills =
        skillsBySpecialization[_selectedSpecialization ?? 'Others'] ?? [];
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Container(
          constraints: BoxConstraints(maxWidth: 300.w),
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
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.teal.shade700,
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Container(
                  constraints: BoxConstraints(maxWidth: 250.w),
                  child: Text(
                    _selectedSkills.isEmpty
                        ? 'Select skills'
                        : _selectedSkills.join(', '),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: _selectedSkills.isEmpty
                          ? Colors.grey
                          : Colors.black87,
                    ),
                  ),
                ),
                if (_selectedSkills.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Text(
                      'At least one skill is required',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.red.shade700,
                      ),
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
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              widget.isRecruiter ? 'Recruiter Profile' : 'Seeker Profile',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 18.sp,
              ),
            ),
            centerTitle: true,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.teal.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            elevation: 0,
            actions: [
              if (!widget.isRecruiter) ...[
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.description_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.all(2.w),
                    onPressed: () {
                      dev.log('Opening resume preview', name: 'ProfileScreen');
                      final resumeData = _generateResumeData();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          title: Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade700,
                                  Colors.blue.shade900,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16.r),
                              ),
                            ),
                            child: const Text(
                              'Resume Preview',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          content: SingleChildScrollView(
                            child: Container(
                              constraints: BoxConstraints(maxWidth: 300.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Email: ${resumeData['email'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  Text(
                                    'Mobile: ${resumeData['mobileNumber'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  Text(
                                    'Name: ${resumeData['name'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    'Skills:',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 6.w,
                                    runSpacing: 4.h,
                                    children:
                                        (resumeData['skills'] as List<dynamic>?)
                                            ?.cast<String>()
                                            .map(
                                              (skill) => Chip(
                                                label: Text(
                                                  skill,
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                  ),
                                                ),
                                                backgroundColor:
                                                    Colors.teal.shade100,
                                                labelStyle: TextStyle(
                                                  color: Colors.teal.shade900,
                                                ),
                                              ),
                                            )
                                            .toList() ??
                                        [
                                          const Chip(
                                            label: Text(
                                              'N/A',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    'Education: ${resumeData['education'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  Text(
                                    'Experience: ${resumeData['experience'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  Text(
                                    'Specialization: ${resumeData['specialization'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  Text(
                                    'Current CTC: ${_formatCtc(resumeData['currentCtc'] ?? '0.0')}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  Text(
                                    'Expected CTC: ${_formatCtc(resumeData['expectedCtc'] ?? '0.0')}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  color: Colors.teal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(
                    right: 8.w,
                    left: 4.w,
                    top: 6.h,
                    bottom: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.all(2.w),
                    onPressed: _showUpdateProfileDialog,
                  ),
                ),
              ],
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade50,
                  Colors.teal.shade50,
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.teal.shade500,
                      ),
                      strokeWidth: 3.5.w,
                    ),
                  )
                : errorMessage != null
                ? Center(
                    child: Container(
                      margin: EdgeInsets.all(18.w),
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade700,
                                Colors.teal.shade500,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withValues(alpha: 0.25),
                                blurRadius: 16.r,
                                offset: Offset(0, 8.h),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 52.w,
                                    height: 52.w,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                      image: _profilePhotoUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(_profilePhotoUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: _profilePhotoUrl == null
                                        ? Icon(
                                            Icons.person_rounded,
                                            color: Colors.white,
                                            size: 28.sp,
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    right: -1.w,
                                    bottom: -1.h,
                                    child: GestureDetector(
                                      onTap: _pickAndUploadProfilePhoto,
                                      child: Container(
                                        width: 20.w,
                                        height: 20.w,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.teal.shade400,
                                            width: 1.5.w,
                                          ),
                                        ),
                                        child: _isUploadingProfilePhoto
                                            ? Padding(
                                                padding: EdgeInsets.all(4.w),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.w,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<Color>(
                                                        Colors.teal.shade600,
                                                      ),
                                                ),
                                              )
                                            : Icon(
                                                Icons.camera_alt_rounded,
                                                size: 11.sp,
                                                color: Colors.teal.shade700,
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _nameController.text.isNotEmpty
                                          ? _nameController.text
                                          : 'Your Profile',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16.sp,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      _email ?? 'No email',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 12.sp,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(30.r),
                                ),
                                child: Text(
                                  widget.isRecruiter ? 'Recruiter' : 'Seeker',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 14.h),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueGrey.withValues(alpha: 0.08),
                                blurRadius: 18.r,
                                offset: Offset(0, 8.h),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(14.w),
                            child: Form(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader('Basic Information'),
                                  _buildNonEditableField('Email', _email),
                                  _buildNonEditableField(
                                    'Mobile Number',
                                    _mobileNumber,
                                  ),
                                  if (_isProfileUpdated)
                                    _buildNonEditableField(
                                      'Name',
                                      _nameController.text,
                                    )
                                  else
                                    _buildTextField(
                                      'Name',
                                      controller: _nameController,
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? 'Name is required'
                                          : null,
                                    ),
                                  SizedBox(height: 8.h),
                                  _buildSectionHeader(
                                    widget.isRecruiter
                                        ? 'Organization Details'
                                        : 'Career Details',
                                  ),
                                  if (widget.isRecruiter) ...[
                                    if (_isProfileUpdated)
                                      _buildNonEditableField(
                                        'Company Name',
                                        _companyNameController.text,
                                      )
                                    else
                                      _buildTextField(
                                        'Company Name',
                                        controller: _companyNameController,
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? 'Company Name is required'
                                            : null,
                                      ),
                                    if (_isProfileUpdated)
                                      _buildNonEditableField(
                                        'Company Profile',
                                        _companyProfileController.text,
                                      )
                                    else
                                      _buildTextField(
                                        'Company Profile',
                                        multiline: true,
                                        controller: _companyProfileController,
                                      ),
                                    if (_isProfileUpdated)
                                      _buildNonEditableField(
                                        'Designation',
                                        _designationController.text,
                                      )
                                    else
                                      _buildTextField(
                                        'Designation',
                                        controller: _designationController,
                                      ),
                                  ] else ...[
                                    if (_isProfileUpdated)
                                      _buildNonEditableField(
                                        'Specialization',
                                        _selectedSpecialization,
                                      )
                                    else
                                      _buildSpecializationDropdown(),
                                    if (_isProfileUpdated)
                                      _buildNonEditableField(
                                        'Skills',
                                        _selectedSkills.isEmpty
                                            ? 'N/A'
                                            : _selectedSkills.join(', '),
                                      )
                                    else
                                      _buildSkillsMultiSelect(),
                                    if (_isProfileUpdated)
                                      _buildNonEditableField(
                                        'Education',
                                        _selectedEducation,
                                      )
                                    else
                                      _buildEducationDropdown(),
                                    if (_isProfileUpdated)
                                      _buildNonEditableField(
                                        'Experience',
                                        _experienceController.text,
                                      )
                                    else
                                      _buildExperienceDropdown(),
                                    if (_isProfileUpdated)
                                      _buildNonEditableField(
                                        'Current CTC',
                                        _currentCtcController.text,
                                      )
                                    else
                                      _buildTextField(
                                        'Current CTC',
                                        controller: _currentCtcController,
                                      ),
                                    if (_isProfileUpdated)
                                      _buildNonEditableField(
                                        'Expected CTC',
                                        _expectedCtcController.text,
                                      )
                                    else
                                      _buildTextField(
                                        'Expected CTC',
                                        controller: _expectedCtcController,
                                      ),
                                  ],
                                  SizedBox(height: 14.h),
                                  if (!_isProfileUpdated)
                                    AnimatedScaleButton(
                                      onPressed: _showUpdateProfileDialog,
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12.h,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue.shade700,
                                              Colors.teal.shade500,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14.r,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.teal.withValues(
                                                alpha: 0.24,
                                              ),
                                              blurRadius: 12.r,
                                              offset: Offset(0, 5.h),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.verified_outlined,
                                              color: Colors.white,
                                              size: 18.sp,
                                            ),
                                            SizedBox(width: 8.w),
                                            Text(
                                              'Update Profile',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  SizedBox(height: 4.h),
                                ],
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
    _companyNameController = TextEditingController(
      text: widget.initialData['companyName'],
    );
    _companyProfileController = TextEditingController(
      text: widget.initialData['companyProfile'],
    );
    _designationController = TextEditingController(
      text: widget.initialData['designation'],
    );
    _experienceController = TextEditingController(
      text: widget.initialData['experience'],
    );
    _currentCtcController = TextEditingController(
      text: widget.initialData['currentCtc'],
    );
    _expectedCtcController = TextEditingController(
      text: widget.initialData['expectedCtc'],
    );
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

  Widget _buildTextField(
    String label, {
    bool multiline = false,
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) {
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
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 10.h,
            ),
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
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
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              _buildTextField(
                'Name',
                controller: _nameController,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Name is required'
                    : null,
              ),
              if (widget.isRecruiter) ...[
                _buildTextField(
                  'Company Name',
                  controller: _companyNameController,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Company Name is required'
                      : null,
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
                      initialValue: _specialization,
                      decoration: InputDecoration(
                        labelText: 'Specialization',
                        labelStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 12.sp,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.teal,
                            width: 2.w,
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                      ),
                      isExpanded: true,
                      menuMaxHeight: 300.h,
                      items: widget.specializationOptions.map((
                        String specialization,
                      ) {
                        return DropdownMenuItem<String>(
                          value: specialization,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: 250.w),
                            child: Text(
                              specialization,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12.sp,
                              ),
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
                      validator: (value) =>
                          value == null ? 'Specialization is required' : null,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
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
                              items:
                                  widget
                                      .skillsBySpecialization[_specialization ??
                                      'Others'] ??
                                  [],
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
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            SizedBox(height: 6.h),
                            Container(
                              constraints: BoxConstraints(maxWidth: 250.w),
                              child: Text(
                                _skills.isEmpty
                                    ? 'Select skills'
                                    : _skills.join(', '),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: _skills.isEmpty
                                      ? Colors.grey
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            if (_skills.isEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 6.h),
                                child: Text(
                                  'At least one skill is required',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: Colors.red.shade700,
                                  ),
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
                      initialValue: _education,
                      decoration: InputDecoration(
                        labelText: 'Education',
                        labelStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 12.sp,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.teal,
                            width: 2.w,
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
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
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12.sp,
                              ),
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
                      validator: (value) =>
                          value == null ? 'Education is required' : null,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 300.w),
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          _experienceController.text.isNotEmpty &&
                              widget.experienceOptions.contains(
                                _experienceController.text,
                              )
                          ? _experienceController.text
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Experience',
                        labelStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 12.sp,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.teal,
                            width: 2.w,
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
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
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12.sp,
                              ),
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
                      validator: (value) =>
                          value == null ? 'Experience is required' : null,
                    ),
                  ),
                ),
                _buildTextField(
                  'Current CTC',
                  controller: _currentCtcController,
                ),
                _buildTextField(
                  'Expected CTC',
                  controller: _expectedCtcController,
                ),
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
                          'companyProfile': _companyProfileController.text
                              .trim(),
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
                          'currentCtc': _currentCtcController.text
                              .replaceAll(' LPA (INR)', '')
                              .trim(),
                          'expectedCtc': _expectedCtcController.text
                              .replaceAll(' LPA (INR)', '')
                              .trim(),
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

  const AnimatedScaleButton({
    required this.onPressed,
    required this.child,
    super.key,
  });

  @override
  AnimatedScaleButtonState createState() => AnimatedScaleButtonState();
}

class AnimatedScaleButtonState extends State<AnimatedScaleButton>
    with SingleTickerProviderStateMixin {
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
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

class MultiSelectDialog extends StatefulWidget {
  final List<String> items;
  final List<String> selectedItems;

  const MultiSelectDialog({
    required this.items,
    required this.selectedItems,
    super.key,
  });

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
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
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
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, _tempSelectedItems);
          },
          child: const Text(
            'OK',
            style: TextStyle(color: Colors.teal, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
