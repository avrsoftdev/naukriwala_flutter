// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:naukariwala/screens/recruiter_dashboard.dart';
import 'package:naukariwala/screens/seeker_dashboard.dart';
import 'package:naukariwala/services/auth_service.dart';

class ProfileSetupOnboarding extends StatefulWidget {
  final String role; // 'seeker' | 'recruiter'
  final Map<String, dynamic>? initialData;

  const ProfileSetupOnboarding({
    super.key,
    required this.role,
    this.initialData,
  });

  @override
  State<ProfileSetupOnboarding> createState() => _ProfileSetupOnboardingState();
}

class _ProfileSetupOnboardingState extends State<ProfileSetupOnboarding> {
  final AuthService _authService = AuthService();
  final PageController _pageController = PageController();

  late final bool _isRecruiter;
  late final int _totalSteps;
  late final List<GlobalKey<FormState>> _formKeys;

  int _stepIndex = 0;
  bool _loading = true;
  bool _saving = false;

  String? _photoUrl;
  String? _resumeUrl;
  PlatformFile? _pickedResume;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();

  // Education (Seeker)
  final _tenthPassingYearController = TextEditingController();
  final _tenthScoreController = TextEditingController();
  String _tenthScoreType = 'Percentage';

  String? _afterTenthChoice; // 'Class 12th' | 'Diploma'

  String? _twelfthStream; // 'Science' | 'Commerce' | 'Arts' | 'Other'
  final _twelfthStreamOtherController = TextEditingController();
  final _twelfthPassingYearController = TextEditingController();
  final _twelfthScoreController = TextEditingController();
  String _twelfthScoreType = 'Percentage';

  String?
  _afterTwelfthChoice; // 'Diploma' | 'Graduation' | 'Other certifications' | 'None'

  String? _selectedDiplomaMajor;
  final _diplomaUniversityController = TextEditingController();
  final _diplomaStartYearController = TextEditingController();
  final _diplomaEndYearController = TextEditingController();
  final _diplomaScoreController = TextEditingController();
  String _diplomaScoreType = 'Percentage';
  bool _pursuedGraduationAfterDiploma = false;

  final _graduationDegreeController = TextEditingController();
  final _graduationUniversityController = TextEditingController();
  String? _selectedGraduationMajor;
  final _graduationStartYearController = TextEditingController();
  final _graduationEndYearController = TextEditingController();
  final _graduationScoreController = TextEditingController();
  String _graduationScoreType = 'CGPA';
  bool _graduationCurrentlyStudying = false;

  final List<_CertificationEntry> _certifications = [];

  final _jobTitleController = TextEditingController();
  final _industryController = TextEditingController();
  String? _selectedExperience;
  String? _selectedSpecialization;
  List<String> _selectedSkills = [];

  final _preferredRoleController = TextEditingController();
  final _preferredLocationController = TextEditingController();
  final _expectedSalaryController = TextEditingController();
  String? _selectedWorkType;

  final _companyNameController = TextEditingController();
  final _companyWebsiteController = TextEditingController();
  final _companyIndustryController = TextEditingController();

  final _companySizeController = TextEditingController();
  final _companyHqController = TextEditingController();
  final _companyDescriptionController = TextEditingController();

  final _recruiterNameController = TextEditingController();
  final _recruiterDesignationController = TextEditingController();
  final _recruiterContactController = TextEditingController();

  static const List<String> _experienceOptions = [
    'Fresher (0 years)',
    '0-1 years',
    '1-3 years',
    '3-5 years',
    '5-10 years',
    '10+ years',
  ];

  static const List<String> _workTypeOptions = ['Remote', 'Hybrid', 'On-site'];

  static const List<String> _scoreTypeOptions = ['Percentage', 'CGPA'];

  static const List<String> _afterTenthOptions = ['Class 12th', 'Diploma'];

  static const List<String> _twelfthStreamOptions = [
    'Science',
    'Commerce',
    'Arts',
    'Other',
  ];

  static const List<String> _afterTwelfthOptions = [
    'Diploma',
    'Graduation',
    'Other certifications',
    'None',
  ];

  static const List<String> _majorOptions = [
    'Computer Science',
    'Mechanical',
    'Civil',
    'Electronics',
    'Electrical',
    'Chemical',
    'Information Technology',
    'Automobile',
    'Aeronautical',
    'Biotechnology',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _isRecruiter = widget.role == 'recruiter';
    _totalSteps = _isRecruiter ? 3 : 5;
    _formKeys = List.generate(_totalSteps, (_) => GlobalKey<FormState>());
    _bootstrap();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();

    _tenthPassingYearController.dispose();
    _tenthScoreController.dispose();
    _twelfthStreamOtherController.dispose();
    _twelfthPassingYearController.dispose();
    _twelfthScoreController.dispose();
    _diplomaUniversityController.dispose();
    _diplomaStartYearController.dispose();
    _diplomaEndYearController.dispose();
    _diplomaScoreController.dispose();
    _graduationDegreeController.dispose();
    _graduationUniversityController.dispose();
    _graduationStartYearController.dispose();
    _graduationEndYearController.dispose();
    _graduationScoreController.dispose();
    for (final c in _certifications) {
      c.dispose();
    }

    _jobTitleController.dispose();
    _industryController.dispose();
    _preferredRoleController.dispose();
    _preferredLocationController.dispose();
    _expectedSalaryController.dispose();
    _companyNameController.dispose();
    _companyWebsiteController.dispose();
    _companyIndustryController.dispose();
    _companySizeController.dispose();
    _companyHqController.dispose();
    _companyDescriptionController.dispose();
    _recruiterNameController.dispose();
    _recruiterDesignationController.dispose();
    _recruiterContactController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final profile = await _authService.fetchProfileData(
        isRecruiter: _isRecruiter,
      );
      final merged = <String, dynamic>{
        ...(profile ?? const <String, dynamic>{}),
        ...(widget.initialData ?? const <String, dynamic>{}),
      };

      final name = (merged['name'] ?? merged['Name'])?.toString();
      if (name != null && name.trim().isNotEmpty) {
        _nameController.text = name.trim();
        _recruiterNameController.text = name.trim();
      }

      final email =
          (merged['email'] ??
                  merged['Email Id'] ??
                  FirebaseAuth.instance.currentUser?.email)
              ?.toString();
      if (email != null && email.trim().isNotEmpty) {
        _emailController.text = email.trim();
      }

      final mobile = (merged['mobileNumber'] ?? merged['Mobile Number'])
          ?.toString();
      if (mobile != null && mobile.trim().isNotEmpty) {
        _phoneController.text = _displayPhone(mobile);
        _recruiterContactController.text = _displayPhone(mobile);
      }

      final city = merged['city']?.toString();
      if (city != null && city.trim().isNotEmpty) {
        _locationController.text = city.trim();
        _companyHqController.text = city.trim();
      }

      final companyName = merged['companyName']?.toString();
      if (companyName != null && companyName.trim().isNotEmpty) {
        _companyNameController.text = companyName.trim();
      }

      _photoUrl = merged['photoUrl']?.toString();
      _resumeUrl = merged['resumeUrl']?.toString();

      _jobTitleController.text = merged['jobTitle']?.toString() ?? '';
      _industryController.text = merged['industry']?.toString() ?? '';
      _selectedExperience = merged['experience']?.toString();
      _selectedSpecialization = merged['specialization']?.toString();
      _selectedSkills =
          (merged['skills'] as List<dynamic>?)?.cast<String>() ?? [];

      _preferredRoleController.text =
          merged['preferredJobRole']?.toString() ?? '';
      _preferredLocationController.text =
          merged['preferredLocation']?.toString() ?? '';
      _expectedSalaryController.text =
          merged['expectedSalary']?.toString() ?? '';
      _selectedWorkType = merged['workType']?.toString();

      _companyWebsiteController.text =
          merged['companyWebsite']?.toString() ?? '';
      _companyIndustryController.text =
          merged['companyIndustry']?.toString() ?? '';
      _companySizeController.text = merged['companySize']?.toString() ?? '';
      _companyDescriptionController.text =
          merged['companyProfile']?.toString() ?? '';

      _recruiterDesignationController.text =
          merged['designation']?.toString() ?? '';

      final edu = merged['educationDetails'];
      if (edu is Map) {
        final tenth = edu['tenth'];
        if (tenth is Map) {
          _tenthPassingYearController.text =
              tenth['passingYear']?.toString() ?? '';
          final st = tenth['scoreType']?.toString();
          if (st != null && _scoreTypeOptions.contains(st))
            _tenthScoreType = st;
          _tenthScoreController.text = tenth['score']?.toString() ?? '';
        }

        final afterTenth = edu['afterTenth']?.toString();
        if (afterTenth != null && _afterTenthOptions.contains(afterTenth))
          _afterTenthChoice = afterTenth;

        final twelfth = edu['twelfth'];
        if (twelfth is Map) {
          final stream = twelfth['stream']?.toString();
          if (stream != null && _twelfthStreamOptions.contains(stream))
            _twelfthStream = stream;
          _twelfthStreamOtherController.text =
              twelfth['streamOther']?.toString() ?? '';
          _twelfthPassingYearController.text =
              twelfth['passingYear']?.toString() ?? '';
          final st = twelfth['scoreType']?.toString();
          if (st != null && _scoreTypeOptions.contains(st))
            _twelfthScoreType = st;
          _twelfthScoreController.text = twelfth['score']?.toString() ?? '';
        }

        final afterTwelfth = edu['afterTwelfth']?.toString();
        if (afterTwelfth != null && _afterTwelfthOptions.contains(afterTwelfth))
          _afterTwelfthChoice = afterTwelfth;

        final diploma = edu['diploma'];
        if (diploma is Map) {
          final branch = diploma['branch']?.toString();
          if (branch != null && _majorOptions.contains(branch)) {
            _selectedDiplomaMajor = branch;
          }
          _diplomaUniversityController.text =
              diploma['university']?.toString() ?? '';
          _diplomaStartYearController.text =
              diploma['startYear']?.toString() ?? '';
          _diplomaEndYearController.text = diploma['endYear']?.toString() ?? '';
          final st = diploma['scoreType']?.toString();
          if (st != null && _scoreTypeOptions.contains(st))
            _diplomaScoreType = st;
          _diplomaScoreController.text = diploma['score']?.toString() ?? '';
        }

        _pursuedGraduationAfterDiploma = edu['graduationAfterDiploma'] == true;

        final graduation = edu['graduation'];
        if (graduation is Map) {
          _graduationDegreeController.text =
              graduation['degree']?.toString() ?? '';
          final major = graduation['major']?.toString();
          if (major != null && _majorOptions.contains(major)) {
            _selectedGraduationMajor = major;
          }
          _graduationUniversityController.text =
              graduation['university']?.toString() ?? '';
          _graduationStartYearController.text =
              graduation['startYear']?.toString() ?? '';
          _graduationEndYearController.text =
              graduation['endYear']?.toString() ?? '';
          final st = graduation['scoreType']?.toString();
          if (st != null && _scoreTypeOptions.contains(st))
            _graduationScoreType = st;
          _graduationScoreController.text =
              graduation['score']?.toString() ?? '';
          _graduationCurrentlyStudying =
              graduation['currentlyStudying'] == true;
        }

        final certs = edu['certifications'];
        if (certs is List) {
          for (final item in certs) {
            if (item is Map) {
              final entry = _CertificationEntry();
              entry.name.text = item['name']?.toString() ?? '';
              entry.institute.text = item['institute']?.toString() ?? '';
              entry.year.text = item['year']?.toString() ?? '';
              entry.score.text = item['score']?.toString() ?? '';
              _certifications.add(entry);
            }
          }
        }
      }
    } catch (_) {
      // Non-fatal; onboarding can still proceed with empty fields.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _displayPhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('+91') && trimmed.length >= 13) {
      return trimmed.substring(3);
    }
    if (trimmed.startsWith('+')) return trimmed;
    return trimmed;
  }

  String _normalizePhoneForSave(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('+')) return trimmed;
    final digits = trimmed.replaceAll(RegExp(r'\\D'), '');
    if (digits.length == 10) return '+91$digits';
    return '+$digits';
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required';
    if (v.startsWith('+')) {
      return RegExp(r'^\\+\\d{10,15}$').hasMatch(v)
          ? null
          : 'Enter valid phone number';
    }
    final digits = v.replaceAll(RegExp(r'\\D'), '');
    return digits.length == 10
        ? null
        : 'Enter 10-digit number (or +countrycode)';
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_saving) return;
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (image == null) return;

      setState(() => _saving = true);
      final url = await _authService.uploadProfilePhoto(
        file: File(image.path),
        isRecruiter: _isRecruiter,
      );
      setState(() {
        _photoUrl = url;
        _saving = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _pickAndUploadResume() async {
    if (_saving) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.path == null) return;

      setState(() {
        _pickedResume = file;
        _saving = true;
      });
      final url = await _authService.uploadSeekerResume(File(file.path!));
      setState(() {
        _resumeUrl = url;
        _saving = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Resume upload failed: $e')));
      }
    }
  }

  Future<void> _skipForNow() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _authService.setProfileSetupStatus('deferred');
      _goToDashboard();
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not skip: $e')));
    }
  }

  void _goToDashboard() {
    if (_isRecruiter) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RecruiterDashboard()),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SeekerDashboard(
          seekerName: _nameController.text.trim().isEmpty
              ? 'Seeker'
              : _nameController.text.trim(),
          photoUrl: _photoUrl,
        ),
      ),
    );
  }

  Future<void> _next() async {
    final form = _formKeys[_stepIndex].currentState;
    if (form != null && !form.validate()) return;

    if (!_isRecruiter && _stepIndex == 1) {
      final msg = _validateEducationTimeline();
      if (msg != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }
    }

    if (!_isRecruiter && _stepIndex == 2) {
      if ((_selectedSpecialization ?? '').trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a specialization')),
        );
        return;
      }
      if (_selectedSkills.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one skill')),
        );
        return;
      }
    }

    if (_stepIndex >= _totalSteps - 1) {
      await _finish();
      return;
    }

    setState(() => _stepIndex += 1);
    await _pageController.animateToPage(
      _stepIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _back() async {
    if (_stepIndex == 0) return;
    setState(() => _stepIndex -= 1);
    await _pageController.animateToPage(
      _stepIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw const AuthException('Not logged in');
      }

      if (_isRecruiter) {
        final data = <String, dynamic>{
          'uid': uid,
          'name': _recruiterNameController.text.trim(),
          'mobileNumber': _normalizePhoneForSave(
            _recruiterContactController.text,
          ),
          'companyName': _companyNameController.text.trim(),
          'companyWebsite': _companyWebsiteController.text.trim(),
          'companyIndustry': _companyIndustryController.text.trim(),
          'companySize': _companySizeController.text.trim(),
          'city': _companyHqController.text.trim(),
          'companyProfile': _companyDescriptionController.text.trim(),
          'designation': _recruiterDesignationController.text.trim(),
        };

        await _authService.storeSignupData(isRecruiter: true, data: data);
        await _authService.setProfileSetupStatus('completed');
        _goToDashboard();
        return;
      }

      final data = <String, dynamic>{
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobileNumber': _normalizePhoneForSave(_phoneController.text),
        'city': _locationController.text.trim(),
        'education': _deriveHighestEducation(),
        'educationDetails': _buildEducationDetailsPayload(),
        'jobTitle': _jobTitleController.text.trim(),
        'experience': _selectedExperience?.trim() ?? '',
        'industry': _industryController.text.trim(),
        'specialization': _selectedSpecialization,
        'skills': List<String>.from(_selectedSkills),
        if (_resumeUrl != null) 'resumeUrl': _resumeUrl,
        'preferredJobRole': _preferredRoleController.text.trim(),
        'preferredLocation': _preferredLocationController.text.trim(),
        'expectedSalary': _expectedSalaryController.text.trim(),
        'workType': _selectedWorkType,
      };

      await _authService.storeSignupData(isRecruiter: false, data: data);
      await _authService.setProfileSetupStatus('completed');
      _goToDashboard();
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save profile: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRecruiter
        ? 'Complete Recruiter Profile'
        : 'Set up your Profile';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_stepIndex == 0)
            Tooltip(
              message: 'Complete Basic information to continue',
              child: TextButton(
                onPressed: null,
                child: Text(
                  'Skip for now',
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saving ? null : _skipForNow,
              child: Text(
                'Skip for now',
                style: TextStyle(color: Colors.black, fontSize: 14.sp),
              ),
            ),
          SizedBox(width: 6.w),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Step ${_stepIndex + 1} of $_totalSteps',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.black87,
                              ),
                            ),
                            if (_saving)
                              SizedBox(
                                height: 16.h,
                                width: 16.h,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: LinearProgressIndicator(
                            value: (_stepIndex + 1) / _totalSteps,
                            minHeight: 8.h,
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: _isRecruiter
                          ? _buildRecruiterPages()
                          : _buildSeekerPages(),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_stepIndex == 0 || _saving)
                                ? null
                                : _back,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _next,
                            icon: Icon(
                              _stepIndex == _totalSteps - 1
                                  ? Icons.check
                                  : Icons.arrow_forward,
                            ),
                            label: Text(
                              _stepIndex == _totalSteps - 1
                                  ? (_isRecruiter
                                        ? 'Complete Profile'
                                        : 'Finish Setup')
                                  : 'Next',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildSeekerPages() {
    return [
      _cardStep(
        formKey: _formKeys[0],
        title: 'Basic information',
        children: [
          Center(
            child: InkWell(
              onTap: _saving ? null : _pickAndUploadPhoto,
              borderRadius: BorderRadius.circular(60.r),
              child: CircleAvatar(
                radius: 46.r,
                backgroundColor: Colors.grey.shade200,
                backgroundImage:
                    (_photoUrl != null && _photoUrl!.trim().isNotEmpty)
                    ? NetworkImage(_photoUrl!)
                    : null,
                child: (_photoUrl == null || _photoUrl!.trim().isEmpty)
                    ? Icon(
                        Icons.camera_alt_outlined,
                        size: 28.sp,
                        color: Colors.grey.shade700,
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(height: 14.h),
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          SizedBox(height: 10.h),
          TextFormField(
            controller: _emailController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Email',
              helperText: 'This is your signup email',
            ),
          ),
          SizedBox(height: 10.h),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Phone number'),
            validator: _validatePhone,
          ),
          SizedBox(height: 10.h),
          TextFormField(
            controller: _locationController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Current location (City)',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ],
      ),
      _cardStep(
        formKey: _formKeys[1],
        title: 'Education details',
        children: _buildEducationChildren(),
      ),
      _cardStep(
        formKey: _formKeys[2],
        title: 'Professional details',
        children: [
          TextFormField(
            controller: _jobTitleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Current job title'),
          ),
          SizedBox(height: 10.h),
          DropdownButtonFormField<String>(
            value:
                (_selectedExperience != null &&
                    _experienceOptions.contains(_selectedExperience))
                ? _selectedExperience
                : null,
            decoration: const InputDecoration(labelText: 'Years of experience'),
            items: _experienceOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _selectedExperience = v),
          ),
          SizedBox(height: 10.h),
          TextFormField(
            controller: _industryController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Industry'),
          ),
          SizedBox(height: 10.h),
          DropdownButtonFormField<String>(
            value:
                (_selectedSpecialization != null &&
                    _authService.specializationOptions.contains(
                      _selectedSpecialization,
                    ))
                ? _selectedSpecialization
                : null,
            decoration: const InputDecoration(labelText: 'Specialization'),
            items: _authService.specializationOptions
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedSpecialization = v;
                _selectedSkills = [];
              });
            },
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          SizedBox(height: 10.h),
          MultiSelectDialogField<String>(
            items:
                (_authService.skillsBySpecialization[_selectedSpecialization ??
                            'Others'] ??
                        const <String>[])
                    .map((s) => MultiSelectItem<String>(s, s))
                    .toList(),
            title: const Text('Skills'),
            buttonText: const Text('Select skills'),
            initialValue: _selectedSkills,
            searchable: true,
            onConfirm: (values) => setState(() => _selectedSkills = values),
            chipDisplay: MultiSelectChipDisplay(
              onTap: (item) => setState(() => _selectedSkills.remove(item)),
            ),
          ),
          if (_selectedSkills.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 6.h),
              child: Text(
                'Select at least one skill.',
                style: TextStyle(fontSize: 12.sp, color: Colors.red.shade700),
              ),
            ),
        ],
      ),
      _cardStep(
        formKey: _formKeys[3],
        title: 'Resume upload',
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supported formats: PDF, DOC, DOCX',
                  style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                ),
                SizedBox(height: 8.h),
                Text(
                  _pickedResume?.name ??
                      (_resumeUrl != null
                          ? 'Resume uploaded'
                          : 'No resume selected'),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _pickAndUploadResume,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Upload resume'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  'You can skip this step and upload later from your profile.',
                  style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
      _cardStep(
        formKey: _formKeys[4],
        title: 'Job preferences',
        children: [
          TextFormField(
            controller: _preferredRoleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Preferred job role'),
          ),
          SizedBox(height: 10.h),
          TextFormField(
            controller: _preferredLocationController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Preferred location'),
          ),
          SizedBox(height: 10.h),
          TextFormField(
            controller: _expectedSalaryController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Expected salary'),
          ),
          SizedBox(height: 10.h),
          DropdownButtonFormField<String>(
            value: _workTypeOptions.contains(_selectedWorkType)
                ? _selectedWorkType
                : null,
            decoration: const InputDecoration(labelText: 'Preferred work type'),
            items: _workTypeOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _selectedWorkType = v),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildEducationChildren() {
    final showTwelfth = _afterTenthChoice == 'Class 12th';
    final showDiploma =
        _afterTenthChoice == 'Diploma' ||
        (showTwelfth && _afterTwelfthChoice == 'Diploma');
    final showGraduation =
        (showTwelfth && _afterTwelfthChoice == 'Graduation') ||
        (showDiploma && _pursuedGraduationAfterDiploma);
    final showCertifications =
        showTwelfth && _afterTwelfthChoice == 'Other certifications';

    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Class 10th (required)',
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
        ),
      ),
      SizedBox(height: 10.h),
      Row(
        children: [
          Expanded(
            child: _yearDropdownForController(
              controller: _tenthPassingYearController,
              labelText: 'Passing year',
              requiredField: true,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _scoreTypeOptions.contains(_tenthScoreType)
                  ? _tenthScoreType
                  : _scoreTypeOptions.first,
              decoration: const InputDecoration(labelText: 'Score type'),
              items: _scoreTypeOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _tenthScoreType = v ?? _tenthScoreType),
            ),
          ),
        ],
      ),
      SizedBox(height: 10.h),
      TextFormField(
        controller: _tenthScoreController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Percentage / CGPA'),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
      SizedBox(height: 14.h),
      DropdownButtonFormField<String>(
        value: _afterTenthOptions.contains(_afterTenthChoice)
            ? _afterTenthChoice
            : null,
        decoration: const InputDecoration(
          labelText: 'After Class 10th, what did you pursue?',
        ),
        items: _afterTenthOptions
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) {
          setState(() {
            _afterTenthChoice = v;
            _afterTwelfthChoice = null;
            _pursuedGraduationAfterDiploma = false;
          });
        },
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
      if (showTwelfth) ...[
        SizedBox(height: 16.h),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Class 12th',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(height: 10.h),
        DropdownButtonFormField<String>(
          value: _twelfthStreamOptions.contains(_twelfthStream)
              ? _twelfthStream
              : null,
          decoration: const InputDecoration(labelText: 'Stream'),
          items: _twelfthStreamOptions
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _twelfthStream = v),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        if (_twelfthStream == 'Other') ...[
          SizedBox(height: 10.h),
          TextFormField(
            controller: _twelfthStreamOtherController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Stream (Other)'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ],
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: _yearDropdownForController(
                controller: _twelfthPassingYearController,
                labelText: 'Passing year',
                requiredField: true,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _scoreTypeOptions.contains(_twelfthScoreType)
                    ? _twelfthScoreType
                    : _scoreTypeOptions.first,
                decoration: const InputDecoration(labelText: 'Score type'),
                items: _scoreTypeOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _twelfthScoreType = v ?? _twelfthScoreType),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        TextFormField(
          controller: _twelfthScoreController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Percentage / CGPA'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        SizedBox(height: 14.h),
        DropdownButtonFormField<String>(
          value: _afterTwelfthOptions.contains(_afterTwelfthChoice)
              ? _afterTwelfthChoice
              : null,
          decoration: const InputDecoration(
            labelText: 'After Class 12th, what did you pursue?',
          ),
          items: _afterTwelfthOptions
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            setState(() {
              _afterTwelfthChoice = v;
              _pursuedGraduationAfterDiploma = false;
            });
          },
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      ],
      if (showDiploma) ...[
        SizedBox(height: 16.h),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Diploma',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(height: 10.h),
        DropdownButtonFormField<String>(
          value: _majorOptions.contains(_selectedDiplomaMajor)
              ? _selectedDiplomaMajor
              : null,
          decoration: const InputDecoration(
            labelText: 'Major / Branch',
          ),
          items: _majorOptions
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _selectedDiplomaMajor = v),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        SizedBox(height: 10.h),
        TextFormField(
          controller: _diplomaUniversityController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'College / University'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: _yearDropdownForController(
                controller: _diplomaStartYearController,
                labelText: 'Start year',
                requiredField: true,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _yearDropdownForController(
                controller: _diplomaEndYearController,
                labelText: 'End year',
                requiredField: true,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _scoreTypeOptions.contains(_diplomaScoreType)
                    ? _diplomaScoreType
                    : _scoreTypeOptions.first,
                decoration: const InputDecoration(labelText: 'Score type'),
                items: _scoreTypeOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _diplomaScoreType = v ?? _diplomaScoreType),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: TextFormField(
                controller: _diplomaScoreController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Percentage / CGPA',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pursued Graduation after Diploma?'),
          value: _pursuedGraduationAfterDiploma,
          onChanged: (v) => setState(() => _pursuedGraduationAfterDiploma = v),
        ),
      ],
      if (showGraduation) ...[
        SizedBox(height: 16.h),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Graduation',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(height: 10.h),
        TextFormField(
          controller: _graduationDegreeController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Degree (e.g., B.Tech, B.Sc, B.Com, BA)',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        SizedBox(height: 10.h),
        DropdownButtonFormField<String>(
          value: _majorOptions.contains(_selectedGraduationMajor)
              ? _selectedGraduationMajor
              : null,
          decoration: const InputDecoration(
            labelText: 'Major / Field of study',
          ),
          items: _majorOptions
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _selectedGraduationMajor = v),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        SizedBox(height: 10.h),
        TextFormField(
          controller: _graduationUniversityController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'College / University'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: _yearDropdownForController(
                controller: _graduationStartYearController,
                labelText: 'Start year',
                requiredField: true,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _yearDropdownForController(
                controller: _graduationEndYearController,
                labelText: 'End year',
                requiredField: !_graduationCurrentlyStudying,
                enabled: !_graduationCurrentlyStudying,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Currently studying'),
          value: _graduationCurrentlyStudying,
          onChanged: (v) {
            setState(() {
              _graduationCurrentlyStudying = v;
              if (v) _graduationEndYearController.clear();
            });
          },
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _scoreTypeOptions.contains(_graduationScoreType)
                    ? _graduationScoreType
                    : _scoreTypeOptions.last,
                decoration: const InputDecoration(labelText: 'Score type'),
                items: _scoreTypeOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(
                  () => _graduationScoreType = v ?? _graduationScoreType,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: TextFormField(
                controller: _graduationScoreController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Percentage / CGPA',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
          ],
        ),
      ],
      if (showCertifications) ...[
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: Text(
                'Other certifications',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _certifications.add(_CertificationEntry())),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        if (_certifications.isEmpty)
          Text(
            'No certifications added.',
            style: TextStyle(fontSize: 12.sp, color: Colors.black54),
          ),
        for (final entry in List<_CertificationEntry>.from(_certifications))
          Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: entry.name,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Certification name',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            entry.dispose();
                            _certifications.remove(entry);
                          });
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  TextFormField(
                    controller: entry.institute,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Institute / Platform (optional)',
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: _yearDropdownForController(
                          controller: entry.year,
                          labelText: 'Year (optional)',
                          requiredField: false,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: TextFormField(
                          controller: entry.score,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Score (optional)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    ];
  }

  Widget _yearDropdownForController({
    required TextEditingController controller,
    required String labelText,
    required bool requiredField,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: labelText,
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      onTap: !enabled
          ? null
          : () async {
              final picked = await _pickYearGridDialog(
                initialYear: int.tryParse(controller.text.trim()),
                allowClear: !requiredField,
              );
              if (picked == null) return; // cancelled
              if (picked == -1) {
                controller.clear();
              } else {
                controller.text = picked.toString();
              }
              if (mounted) setState(() {});
            },
      validator: (v) {
        if (!requiredField) return null;
        return (v == null || v.trim().isEmpty) ? 'Required' : null;
      },
    );
  }

  List<int> _yearOptions() {
    final now = DateTime.now().year;
    const min = 1990;
    final max = now + 6;
    return List<int>.generate(max - min + 1, (i) => max - i);
  }

  Future<int?> _pickYearGridDialog({
    required int? initialYear,
    required bool allowClear,
  }) async {
    final years = _yearOptions();
    final scrollController = ScrollController();
    final selected = (initialYear != null && years.contains(initialYear))
        ? initialYear
        : null;

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select year'),
          content: SizedBox(
            width: double.maxFinite,
            height: 230.h, // ~3 rows visible, scroll for more
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              child: GridView.builder(
                controller: scrollController,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent: 44.h,
                  crossAxisSpacing: 10.w,
                  mainAxisSpacing: 10.h,
                ),
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  final isSelected = selected == year;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12.r),
                    onTap: () => Navigator.pop(context, year),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Text(
                        year.toString(),
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            if (allowClear)
              TextButton(
                onPressed: () => Navigator.pop(context, -1),
                child: const Text('Clear'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    scrollController.dispose();
    return result;
  }

  String? _validateEducationTimeline() {
    int? year(String raw) => int.tryParse(raw.trim());

    final tenthYear = year(_tenthPassingYearController.text);
    if (tenthYear == null)
      return 'Please enter a valid Class 10th passing year';

    if (_afterTenthChoice == 'Class 12th') {
      final twelfthYear = year(_twelfthPassingYearController.text);
      if (twelfthYear == null)
        return 'Please enter a valid Class 12th passing year';
      if (twelfthYear <= tenthYear)
        return 'Class 12th passing year should be after Class 10th';

      if (_afterTwelfthChoice == 'Diploma') {
        final ds = year(_diplomaStartYearController.text);
        final de = year(_diplomaEndYearController.text);
        if (ds == null || de == null)
          return 'Please enter valid Diploma start/end years';
        if (ds < twelfthYear)
          return 'Diploma start year should be after Class 12th passing year';
        if (de < ds) return 'Diploma end year should be after start year';

        if (_pursuedGraduationAfterDiploma) {
          final gs = year(_graduationStartYearController.text);
          final ge = year(_graduationEndYearController.text);
          if (gs == null) return 'Please enter a valid Graduation start year';
          if (gs < de)
            return 'Graduation start year should be after Diploma end year';
          if (!_graduationCurrentlyStudying) {
            if (ge == null) return 'Please enter a valid Graduation end year';
            if (ge < gs)
              return 'Graduation end year should be after start year';
          }
        }
      }

      if (_afterTwelfthChoice == 'Graduation') {
        final gs = year(_graduationStartYearController.text);
        final ge = year(_graduationEndYearController.text);
        if (gs == null) return 'Please enter a valid Graduation start year';
        if (gs < twelfthYear)
          return 'Graduation start year should be after Class 12th passing year';
        if (!_graduationCurrentlyStudying) {
          if (ge == null) return 'Please enter a valid Graduation end year';
          if (ge < gs) return 'Graduation end year should be after start year';
        }
      }
    }

    if (_afterTenthChoice == 'Diploma') {
      final ds = year(_diplomaStartYearController.text);
      final de = year(_diplomaEndYearController.text);
      if (ds == null || de == null)
        return 'Please enter valid Diploma start/end years';
      if (ds < tenthYear)
        return 'Diploma start year should be after Class 10th passing year';
      if (de < ds) return 'Diploma end year should be after start year';

      if (_pursuedGraduationAfterDiploma) {
        final gs = year(_graduationStartYearController.text);
        final ge = year(_graduationEndYearController.text);
        if (gs == null) return 'Please enter a valid Graduation start year';
        if (gs < de)
          return 'Graduation start year should be after Diploma end year';
        if (!_graduationCurrentlyStudying) {
          if (ge == null) return 'Please enter a valid Graduation end year';
          if (ge < gs) return 'Graduation end year should be after start year';
        }
      }
    }

    if (_afterTenthChoice == 'Class 12th' &&
        _afterTwelfthChoice == 'Other certifications') {
      for (final entry in _certifications) {
        if (entry.name.text.trim().isEmpty)
          return 'Please fill certification name (or delete the empty record)';
      }
    }

    return null;
  }

  String _deriveHighestEducation() {
    final showTwelfth = _afterTenthChoice == 'Class 12th';
    final showDiploma =
        _afterTenthChoice == 'Diploma' ||
        (showTwelfth && _afterTwelfthChoice == 'Diploma');
    final showGraduation =
        (showTwelfth && _afterTwelfthChoice == 'Graduation') ||
        (showDiploma && _pursuedGraduationAfterDiploma);
    if (showGraduation) return 'Graduation';
    if (showDiploma) return 'Diploma';
    if (showTwelfth) return '12th';
    return '10th';
  }

  Map<String, dynamic> _buildEducationDetailsPayload() {
    final payload = <String, dynamic>{
      'tenth': {
        'passingYear': _tenthPassingYearController.text.trim(),
        'scoreType': _tenthScoreType,
        'score': _tenthScoreController.text.trim(),
      },
      'afterTenth': _afterTenthChoice,
    };

    if (_afterTenthChoice == 'Class 12th') {
      payload['twelfth'] = {
        'stream': _twelfthStream,
        'streamOther': _twelfthStreamOtherController.text.trim(),
        'passingYear': _twelfthPassingYearController.text.trim(),
        'scoreType': _twelfthScoreType,
        'score': _twelfthScoreController.text.trim(),
      };
      payload['afterTwelfth'] = _afterTwelfthChoice;
    }

    final showDiploma =
        _afterTenthChoice == 'Diploma' ||
        (_afterTenthChoice == 'Class 12th' && _afterTwelfthChoice == 'Diploma');
    if (showDiploma) {
      payload['diploma'] = {
        'branch': _selectedDiplomaMajor ?? '',
        'university': _diplomaUniversityController.text.trim(),
        'startYear': _diplomaStartYearController.text.trim(),
        'endYear': _diplomaEndYearController.text.trim(),
        'scoreType': _diplomaScoreType,
        'score': _diplomaScoreController.text.trim(),
      };
      payload['graduationAfterDiploma'] = _pursuedGraduationAfterDiploma;
    }

    final showGraduation =
        (_afterTenthChoice == 'Class 12th' &&
            _afterTwelfthChoice == 'Graduation') ||
        (showDiploma && _pursuedGraduationAfterDiploma);
    if (showGraduation) {
      payload['graduation'] = {
        'degree': _graduationDegreeController.text.trim(),
        'major': _selectedGraduationMajor ?? '',
        'university': _graduationUniversityController.text.trim(),
        'startYear': _graduationStartYearController.text.trim(),
        'endYear': _graduationEndYearController.text.trim(),
        'scoreType': _graduationScoreType,
        'score': _graduationScoreController.text.trim(),
        'currentlyStudying': _graduationCurrentlyStudying,
      };
    }

    if (_afterTenthChoice == 'Class 12th' &&
        _afterTwelfthChoice == 'Other certifications') {
      payload['certifications'] = _certifications
          .map(
            (c) => {
              'name': c.name.text.trim(),
              'institute': c.institute.text.trim(),
              'year': c.year.text.trim(),
              'score': c.score.text.trim(),
            },
          )
          .where((m) => (m['name'] ?? '').toString().trim().isNotEmpty)
          .toList();
    } else {
      payload['certifications'] = const <Map<String, dynamic>>[];
    }

    return payload;
  }

  List<Widget> _buildRecruiterPages() {
    return [
      _cardStep(
        formKey: _formKeys[0],
        title: 'Company information',
        children: [
          Center(
            child: InkWell(
              onTap: _saving ? null : _pickAndUploadPhoto,
              borderRadius: BorderRadius.circular(60.r),
              child: CircleAvatar(
                radius: 46.r,
                backgroundColor: Colors.grey.shade200,
                backgroundImage:
                    (_photoUrl != null && _photoUrl!.trim().isNotEmpty)
                    ? NetworkImage(_photoUrl!)
                    : null,
                child: (_photoUrl == null || _photoUrl!.trim().isEmpty)
                    ? Icon(
                        Icons.business_outlined,
                        size: 28.sp,
                        color: Colors.grey.shade700,
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(height: 14.h),
          TextFormField(
            controller: _companyNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Company name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          SizedBox(height: 10.h),
          TextFormField(
            controller: _companyWebsiteController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Website (optional)'),
          ),
          SizedBox(height: 10.h),
          TextFormField(
            controller: _companyIndustryController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Industry (optional)'),
          ),
        ],
      ),
      _cardStep(
        formKey: _formKeys[1],
        title: 'Company details',
        children: [
          TextFormField(
            controller: _companySizeController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Company size (e.g., 11-50)',
            ),
          ),
          SizedBox(height: 10.h),
          TextFormField(
            controller: _companyHqController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Headquarters location (City)',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          SizedBox(height: 10.h),
          TextFormField(
            controller: _companyDescriptionController,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Company description'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ],
      ),
      _cardStep(
        formKey: _formKeys[2],
        title: 'Recruiter details',
        children: [
          TextFormField(
            controller: _recruiterNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Your name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          SizedBox(height: 10.h),
          TextFormField(
            controller: _recruiterDesignationController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Designation (optional)',
            ),
          ),
          SizedBox(height: 10.h),
          TextFormField(
            controller: _recruiterContactController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Contact number'),
            validator: _validatePhone,
          ),
        ],
      ),
    ];
  }

  Widget _cardStep({
    required GlobalKey<FormState> formKey,
    required String title,
    required List<Widget> children,
  }) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(children: children),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificationEntry {
  final TextEditingController name = TextEditingController();
  final TextEditingController institute = TextEditingController();
  final TextEditingController year = TextEditingController();
  final TextEditingController score = TextEditingController();

  void dispose() {
    name.dispose();
    institute.dispose();
    year.dispose();
    score.dispose();
  }
}
