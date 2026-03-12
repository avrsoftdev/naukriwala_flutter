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

  Map<String, dynamic>? _profileData;

  // Controllers for editable fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyProfileController =
      TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _currentCtcController = TextEditingController();
  final TextEditingController _expectedCtcController = TextEditingController();
  final TextEditingController _linkedinUrlController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  // Non-editable fields
  String? _mobileNumber;
  String? _email;
  String? _profilePhotoUrl;

  // Dropdown and multi-select fields for seekers
  String? _selectedSpecialization;
  String? _selectedEducation;
  String? _selectedCity;
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

  final List<String> cityOptions = [
    'Mumbai',
    'Delhi',
    'Bangalore',
    'Hyderabad',
    'Ahmedabad',
    'Chennai',
    'Kolkata',
    'Surat',
    'Pune',
    'Jaipur',
    'Lucknow',
    'Kanpur',
    'Nagpur',
    'Indore',
    'Thane',
    'Bhopal',
    'Visakhapatnam',
    'Pimpri-Chinchwad',
    'Patna',
    'Vadodara',
    'Ghaziabad',
    'Ludhiana',
    'Agra',
    'Nashik',
    'Faridabad',
    'Meerut',
    'Rajkot',
    'Kalyan-Dombivali',
    'Vasai-Virar',
    'Varanasi',
    'Srinagar',
    'Aurangabad',
    'Dhanbad',
    'Amritsar',
    'Navi Mumbai',
    'Allahabad',
    'Ranchi',
    'Howrah',
    'Coimbatore',
    'Jabalpur',
    'Gwalior',
    'Vijayawada',
    'Jodhpur',
    'Madurai',
    'Raipur',
    'Kota',
    'Guwahati',
    'Chandigarh',
    'Solapur',
    'Hubballi-Dharwad',
    'Bareilly',
    'Moradabad',
    'Mysore',
    'Gurgaon',
    'Aligarh',
    'Jalandhar',
    'Tiruchirappalli',
    'Bhubaneswar',
    'Salem',
    'Warangal',
    'Guntur',
    'Bhiwandi',
    'Saharanpur',
    'Gorakhpur',
    'Bikaner',
    'Amravati',
    'Noida',
    'Jamshedpur',
    'Bhilai',
    'Cuttack',
    'Firozabad',
    'Kochi',
    'Nellore',
    'Bhavnagar',
    'Dehradun',
    'Durgapur',
    'Asansol',
    'Rourkela',
    'Nanded',
    'Kolhapur',
    'Ajmer',
    'Akola',
    'Gulbarga',
    'Jamnagar',
    'Ujjain',
    'Loni',
    'Siliguri',
    'Jhansi',
    'Ulhasnagar',
    'Jammu',
    'Sangli-Miraj & Kupwad',
    'Mangalore',
    'Erode',
    'Belgaum',
    'Ambattur',
    'Tirunelveli',
    'Malegaon',
    'Gaya',
    'Tiruppur',
    'Davanagere',
    'Kozhikode',
    'Akbarpur',
    'Kurnool',
    'Rajpur Sonarpur',
    'Bokaro',
    'South Dumdum',
    'Bellary',
    'Patiala',
    'Gopalpur',
    'Agartala',
    'Bhagalpur',
    'Muzaffarnagar',
    'Bhatpara',
    'Panihati',
    'Latur',
    'Dhule',
    'Tirupati',
    'Rohtak',
    'Korba',
    'Bhilwara',
    'Berhampur',
    'Muzaffarpur',
    'Ahmednagar',
    'Mathura',
    'Kollam',
    'Avadi',
    'Kadapa',
    'Kamarhati',
    'Sambalpur',
    'Bilaspur',
    'Shahjahanpur',
    'Satara',
    'Bijapur',
    'Rampur',
    'Shore',
    'Nagarcoil',
    'Alwar',
    'Bardhaman',
    'Kulti',
    'Kakinada',
    'Nizamabad',
    'Parbhani',
    'Tumkur',
    'Khammam',
    'Ozhukarai',
    'Bihar Sharif',
    'Panipat',
    'Darbhanga',
    'Bally',
    'Aizawl',
    'Dewas',
    'Ichalkaranji',
    'Karnal',
    'Bathinda',
    'Jalna',
    'Eluru',
    'Kirari Suleman Nagar',
    'Barasat',
    'Purnia',
    'Satna',
    'Mau',
    'Sonipat',
    'Farrukhabad',
    'Sagar',
    'Rourkela',
    'Durg',
    'Imphal',
    'Ratlam',
    'Hapur',
    'Arrah',
    'Karimnagar',
    'Anantapur',
    'Etawah',
    'Ambarnath',
    'North Dumdum',
    'Bharatpur',
    'Begusarai',
    'New Delhi',
    'Gandhidham',
    'Baranagar',
    'Tiruvottiyur',
    'Pondicherry',
    'Sikar',
    'Thoothukudi',
    'Rewa',
    'Mirzapur',
    'Raichur',
    'Pali',
    'Ramagundam',
    'Silchar',
    'Haridwar',
    'Vijayanagaram',
    'Tenali',
    'Nagercoil',
    'Sri Ganganagar',
    'Karawal Nagar',
    'Mango',
    'Thanjavur',
    'Bulandshahr',
    'Uluberia',
    'Katni',
    'Sambhal',
    'Singrauli',
    'Nadiad',
    'Secunderabad',
    'Naihati',
    'Yamunanagar',
    'Bidhan Nagar',
    'Pallavaram',
    'Bidar',
    'Munger',
    'Panchkula',
    'Burhanpur',
    'Raurkela Industrial Township',
    'Kharagpur',
    'Dindigul',
    'Gandhinagar',
    'Hospet',
    'Nangloi Jat',
    'Malda',
    'Ongole',
    'Deoghar',
    'Chapra',
    'Haldia',
    'Khandwa',
    'Nandyal',
    'Morena',
    'Amroha',
    'Anand',
    'Bhind',
    'Bhalswa Jahangir Pur',
    'Madhyamgram',
    'Bhiwani',
    'Berhampore',
    'Ambala',
    'Morbi',
    'Fatehpur',
    'Raebareli',
    'Khora',
    'Chittoor',
    'Bhusawal',
    'Orai',
    'Bahraich',
    'Phusro',
    'Vellore',
    'Mehsana',
    'Raiganj',
    'Sirsa',
    'Danapur',
    'Serampore',
    'Sultan Pur Majra',
    'Guna',
    'Jaunpur',
    'Panvel',
    'Shivpuri',
    'Surendranagar Dudhrej',
    'Unnao',
    'Chinsurah',
    'Alappuzha',
    'Kottayam',
    'Machilipatnam',
    'Shimla',
    'Adoni',
    'Udupi',
    'Katihar',
    'Proddatur',
    'Mahbubnagar',
    'Saharsa',
    'Dibrugarh',
    'Jorhat',
    'Hazaribagh',
    'Hindupur',
    'Nagaon',
    'Sasaram',
    'Hajipur',
    'Giridih',
    'Bhimavaram',
    'Kumbakonam',
    'Rajahmundry',
    'Kottayam',
    'Visakhapatnam',
    'Other',
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
            _profileData = Map<String, dynamic>.from(data);
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
            _linkedinUrlController.text =
                data['linkedinUrl']?.toString().trim() ?? '';
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
            final city = data['city']?.toString().trim();
            _selectedCity = city != null && cityOptions.contains(city) ? city : null;
            _cityController.text = _selectedCity ?? '';
            _isProfileUpdated =
                data['name'] != null &&
                data['name'].toString().trim().isNotEmpty &&
                data['city'] != null &&
                data['city'].toString().trim().isNotEmpty &&
                (widget.isRecruiter
                    ? data['companyName'] != null
                    : data['education'] != null);
          });
        } else {
          setState(() {
            errorMessage = 'Profile not found';
            _profileData = null;
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
        setState(() {
          errorMessage = 'Error loading profile: $e';
          _profileData = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _displayValue(dynamic v) {
    if (v == null) return 'N/A';
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? 'N/A' : t;
    }
    if (v is num || v is bool) return v.toString();
    if (v is Timestamp) return v.toDate().toIso8601String();
    return v.toString();
  }

  Widget _buildOnboardingDetailsCard() {
    final data = _profileData;
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    Widget row(String label, dynamic value) {
      final text = _displayValue(value);
      if (text == 'N/A') return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140.w,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.blueGrey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12.sp, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    Widget chips(String label, List<dynamic>? values) {
      final list = values
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [];
      if (list.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.blueGrey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: list
                  .map(
                    (t) => Chip(
                      label: Text(t, style: TextStyle(fontSize: 11.sp)),
                      backgroundColor: Colors.teal.shade50,
                      side: BorderSide(color: Colors.teal.shade100),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );
    }

    final educationDetails = data['educationDetails'];
    final previousExps = data['previousExperiences'];

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 14.h),
      padding: EdgeInsets.all(14.w),
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.only(top: 10.h),
          title: Text(
            'Onboarding Details',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            'Everything filled during profile setup',
            style: TextStyle(fontSize: 11.sp, color: Colors.blueGrey.shade500),
          ),
          children: [
            _buildSectionHeader(widget.isRecruiter ? 'Recruiter' : 'Seeker'),
            row('Current Status', data['currentStatus']),
            row('Job Title', data['jobTitle']),
            row('Industry', data['industry']),
            row('Current Company', data['currentCompany']),
            row('Employment Type', data['employmentType']),
            row('Total Experience (years)', data['totalExperienceYears']),
            row('Current Job Start', data['currentJobStartDate']),
            row('Current Job End', data['currentJobEndDate']),
            row('Previous Companies', data['previousCompanies']),
            row('Achievements', data['achievements']),
            row('Projects', data['projects']),
            row('Internships', data['internships']),
            row('Soft Skills', data['softSkills']),
            row('Preferred Role', data['preferredJobRole']),
            row('Preferred Industries', data['preferredIndustries']),
            row('Preferred Employment Type', data['preferredEmploymentType']),
            row('Preferred Work Mode', data['preferredWorkMode']),
            row('Preferred Location', data['preferredLocation']),
            row('Expected Salary Min', data['expectedSalaryMin']),
            row('Expected Salary Max', data['expectedSalaryMax']),
            row('Notice Period', data['noticePeriod']),
            row('GitHub URL', data['githubUrl']),
            row('Portfolio URL', data['portfolioUrl']),
            row('Resume URL', data['resumeUrl']),
            if (widget.isRecruiter) ...[
              row('Company Website', data['companyWebsite']),
              row('Company Industry', data['companyIndustry']),
              row('Company Size', data['companySize']),
            ],
            chips('Skills', (data['skills'] as List?)?.cast<dynamic>()),
            if (educationDetails is Map) ...[
              SizedBox(height: 6.h),
              _buildSectionHeader('Education Details'),
              row(
                '10th - Passing Year',
                (educationDetails['tenth'] as Map?)?['passingYear'],
              ),
              row('10th - Score', (educationDetails['tenth'] as Map?)?['score']),
              row(
                '10th - Score Type',
                (educationDetails['tenth'] as Map?)?['scoreType'],
              ),
              row('After 10th', educationDetails['afterTenth']),
              row(
                '12th - Stream',
                (educationDetails['twelfth'] as Map?)?['stream'],
              ),
              row(
                '12th - Stream Other',
                (educationDetails['twelfth'] as Map?)?['streamOther'],
              ),
              row(
                '12th - Passing Year',
                (educationDetails['twelfth'] as Map?)?['passingYear'],
              ),
              row(
                '12th - Score',
                (educationDetails['twelfth'] as Map?)?['score'],
              ),
              row(
                '12th - Score Type',
                (educationDetails['twelfth'] as Map?)?['scoreType'],
              ),
              row('After 12th', educationDetails['afterTwelfth']),
              row(
                'Diploma - Branch',
                (educationDetails['diploma'] as Map?)?['branch'],
              ),
              row(
                'Diploma - University',
                (educationDetails['diploma'] as Map?)?['university'],
              ),
              row(
                'Diploma - Start Year',
                (educationDetails['diploma'] as Map?)?['startYear'],
              ),
              row(
                'Diploma - End Year',
                (educationDetails['diploma'] as Map?)?['endYear'],
              ),
              row(
                'Diploma - Score',
                (educationDetails['diploma'] as Map?)?['score'],
              ),
              row(
                'Diploma - Score Type',
                (educationDetails['diploma'] as Map?)?['scoreType'],
              ),
              row(
                'Graduation After Diploma',
                educationDetails['graduationAfterDiploma'],
              ),
              row(
                'Graduation - Degree',
                (educationDetails['graduation'] as Map?)?['degree'],
              ),
              row(
                'Graduation - Major',
                (educationDetails['graduation'] as Map?)?['major'],
              ),
              row(
                'Graduation - University',
                (educationDetails['graduation'] as Map?)?['university'],
              ),
              row(
                'Graduation - Start Year',
                (educationDetails['graduation'] as Map?)?['startYear'],
              ),
              row(
                'Graduation - End Year',
                (educationDetails['graduation'] as Map?)?['endYear'],
              ),
              row(
                'Graduation - Score',
                (educationDetails['graduation'] as Map?)?['score'],
              ),
              row(
                'Graduation - Score Type',
                (educationDetails['graduation'] as Map?)?['scoreType'],
              ),
              row(
                'Graduation - Currently Studying',
                (educationDetails['graduation'] as Map?)?['currentlyStudying'],
              ),
            ],
            if (previousExps is List && previousExps.isNotEmpty) ...[
              SizedBox(height: 6.h),
              _buildSectionHeader('Previous Experiences'),
              ...previousExps.take(10).whereType<Map>().map((e) {
                final company = e['companyName'] ?? e['company'] ?? '';
                final title = e['jobTitle'] ?? e['role'] ?? '';
                final from = e['startDate'] ?? e['from'] ?? '';
                final to = e['endDate'] ?? e['to'] ?? '';
                final line =
                    '${_displayValue(company)} • ${_displayValue(title)} • ${_displayValue(from)} - ${_displayValue(to)}';
                return Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Text(
                    line,
                    style: TextStyle(fontSize: 12.sp, color: Colors.black87),
                  ),
                );
              }),
              if (previousExps.length > 10)
                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Text(
                    'Showing first 10 experiences',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.blueGrey.shade500,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
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
      'city': _selectedCity ?? '',
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
      'linkedinUrl': _linkedinUrlController.text.trim(),
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

    // Validate LinkedIn URL if provided
    if (profileData['linkedinUrl'] != null &&
        profileData['linkedinUrl'].toString().trim().isNotEmpty) {
      final linkedinValidationError = _validateLinkedInUrl(
        profileData['linkedinUrl'],
      );
      if (linkedinValidationError != null) {
        setDialogState(() => errorMessage = linkedinValidationError);
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
          _linkedinUrlController.text = profileData['linkedinUrl'] ?? '';
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
        // Don't pop here - let the dialog close itself from the save button
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
          'city': _selectedCity,
          'skills': List<String>.from(_selectedSkills),
          'linkedinUrl': _linkedinUrlController.text,
        },
        experienceOptions: experienceOptions,
        specializationOptions: specializationOptions,
        educationOptions: educationOptions,
        cityOptions: cityOptions,
        skillsBySpecialization: skillsBySpecialization,
        isProfileUpdated: _isProfileUpdated,
        mobileNumber: _mobileNumber,
        onUpdate: _updateProfile,
      ),
    );
  }

  double _calculateProfileCompletion() {
    if (widget.isRecruiter) {
      // For recruiters, calculate based on their fields
      int filled = 0;
      int total = 4; // name, companyName, companyProfile, designation
      if (_nameController.text.trim().isNotEmpty) filled++;
      if (_companyNameController.text.trim().isNotEmpty) filled++;
      if (_companyProfileController.text.trim().isNotEmpty) filled++;
      if (_designationController.text.trim().isNotEmpty) filled++;
      return (filled / total) * 100;
    } else {
      // For seekers
      int filled = 0;
      int total = 8; // name, city, specialization, education, experience, skills, currentCtc, expectedCtc
      if (_nameController.text.trim().isNotEmpty) filled++;
      if (_selectedCity != null && _selectedCity!.trim().isNotEmpty) filled++;
      if (_selectedSpecialization != null && _selectedSpecialization!.trim().isNotEmpty) filled++;
      if (_selectedEducation != null && _selectedEducation!.trim().isNotEmpty) filled++;
      if (_experienceController.text.trim().isNotEmpty) filled++;
      if (_selectedSkills.isNotEmpty) filled++;
      if (_currentCtcController.text.trim().isNotEmpty && _currentCtcController.text.trim() != '0') filled++;
      if (_expectedCtcController.text.trim().isNotEmpty && _expectedCtcController.text.trim() != '0') filled++;
      return (filled / total) * 100;
    }
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
      case 'linkedin url':
        return Icons.link_outlined;
      case 'city':
        return Icons.location_city_outlined;
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

  /// Validate LinkedIn URL
  String? _validateLinkedInUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // LinkedIn URL is optional
    }
    final trimmed = value.trim();
    // Check if it's a valid LinkedIn URL pattern (allows query parameters and fragments)
    final linkedinRegex = RegExp(
      r'^(https?://)?(www\.)?linkedin\.com/(in|pub|company)/[a-zA-Z0-9_-]+/?',
      caseSensitive: false,
    );
    if (!linkedinRegex.hasMatch(trimmed)) {
      return 'Please enter a valid LinkedIn profile URL';
    }
    return null;
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

  Widget _buildCityAutocompleteField() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return cityOptions.where((String option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            setState(() {
              _selectedCity = selection;
              _cityController.text = selection;
              errorMessage = null;
            });
          },
          fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
            // Initialize the autocomplete controller with our current value
            if (textEditingController.text != _cityController.text) {
              textEditingController.text = _cityController.text;
            }
            // Add listener to update our state when text changes
            textEditingController.addListener(() {
              if (_selectedCity != textEditingController.text) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _selectedCity = textEditingController.text;
                      _cityController.text = textEditingController.text;
                      errorMessage = null;
                    });
                  }
                });
              }
            });
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: _fieldDecoration(
                'City',
                icon: _iconForLabel('City'),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'City is required'
                  : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            );
          },
          optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 300.w, maxHeight: 200.h),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        title: Text(
                          option,
                          style: TextStyle(fontSize: 14.sp),
                        ),
                        onTap: () {
                          onSelected(option);
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
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
                                  if (resumeData['linkedinUrl'] != null &&
                                      resumeData['linkedinUrl']
                                          .toString()
                                          .isNotEmpty)
                                    Text(
                                      'LinkedIn: ${resumeData['linkedinUrl']}',
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
              ],
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
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      shape: BoxShape.circle,
                                      image: _profilePhotoUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                _profilePhotoUrl!,
                                              ),
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
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.teal.shade600),
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
                        if (!widget.isRecruiter) ...[
                          SizedBox(height: 14.h),
                          Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueGrey.withValues(alpha: 0.08),
                                  blurRadius: 12.r,
                                  offset: Offset(0, 4.h),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 60.w,
                                      height: 60.w,
                                      child: CircularProgressIndicator(
                                        value: _calculateProfileCompletion() / 100,
                                        strokeWidth: 6.w,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _calculateProfileCompletion() >= 80
                                              ? Colors.green.shade500
                                              : _calculateProfileCompletion() >= 50
                                                  ? Colors.orange.shade500
                                                  : Colors.red.shade500,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${_calculateProfileCompletion().toInt()}%',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 16.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Profile Completion',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        _calculateProfileCompletion() >= 80
                                            ? 'Great! Your profile is almost complete.'
                                            : _calculateProfileCompletion() >= 50
                                                ? 'Good progress! Keep filling in your details.'
                                                : 'Complete your profile to get better job matches.',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                                  if (_isProfileUpdated)
                                    _buildNonEditableField(
                                      'City',
                                      _selectedCity,
                                    )
                                  else
                                    _buildCityAutocompleteField(),
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
                                    if (_isProfileUpdated &&
                                        _linkedinUrlController.text.isNotEmpty)
                                      _buildNonEditableField(
                                        'LinkedIn URL',
                                        _linkedinUrlController.text,
                                      )
                                    else if (!_isProfileUpdated)
                                      _buildTextField(
                                        'LinkedIn URL',
                                        controller: _linkedinUrlController,
                                        validator: _validateLinkedInUrl,
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
                                    if (_isProfileUpdated &&
                                        _linkedinUrlController.text.isNotEmpty)
                                      _buildNonEditableField(
                                        'LinkedIn URL',
                                        _linkedinUrlController.text,
                                      )
                                    else if (!_isProfileUpdated)
                                      _buildTextField(
                                        'LinkedIn URL',
                                        controller: _linkedinUrlController,
                                        validator: _validateLinkedInUrl,
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
                        _buildOnboardingDetailsCard(),
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
  final List<String> cityOptions;
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
    required this.cityOptions,
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _companyNameController;
  late final TextEditingController _companyProfileController;
  late final TextEditingController _designationController;
  late final TextEditingController _experienceController;
  late final TextEditingController _currentCtcController;
  late final TextEditingController _expectedCtcController;
  late final TextEditingController _linkedinUrlController;
  late final TextEditingController _cityController;
  String? _specialization;
  String? _education;
  String? _selectedCity;
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
    _linkedinUrlController = TextEditingController(
      text: widget.initialData['linkedinUrl'],
    );
    _cityController = TextEditingController(
      text: widget.initialData['city'],
    );
    _specialization = widget.initialData['specialization'];
    _education = widget.initialData['education'];
    _selectedCity = widget.initialData['city'];
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
    _linkedinUrlController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  /// Validate LinkedIn URL
  String? _validateLinkedInUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // LinkedIn URL is optional
    }
    final trimmed = value.trim();
    // Check if it's a valid LinkedIn URL pattern (allows query parameters and fragments)
    final linkedinRegex = RegExp(
      r'^(https?://)?(www\.)?linkedin\.com/(in|pub|company)/[a-zA-Z0-9_-]+/?',
      caseSensitive: false,
    );
    if (!linkedinRegex.hasMatch(trimmed)) {
      return 'Please enter a valid LinkedIn profile URL';
    }
    return null;
  }

  Widget _buildTextField(
    String label, {
    bool multiline = false,
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) {
    final isUrl =
        label.toLowerCase().contains('url') ||
        label.toLowerCase().contains('link');
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: TextFormField(
          controller: controller,
          maxLines: multiline ? 4 : 1,
          maxLength: multiline ? 500 : (isUrl ? 255 : 100),
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
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2.w),
              borderRadius: BorderRadius.circular(12.r),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2.w),
              borderRadius: BorderRadius.circular(12.r),
            ),
            errorStyle: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 11.sp,
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
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (value) {
            if (mounted) setState(() => _errorMessage = null);
          },
        ),
      ),
    );
  }

  Widget _buildCityAutocompleteField() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return widget.cityOptions.where((String option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            setState(() {
              _selectedCity = selection;
              _cityController.text = selection;
              _errorMessage = null;
            });
          },
          fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
            // Initialize the autocomplete controller with our current value
            if (textEditingController.text != _cityController.text) {
              textEditingController.text = _cityController.text;
            }
            // Add listener to update our state when text changes
            textEditingController.addListener(() {
              if (_selectedCity != textEditingController.text) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _selectedCity = textEditingController.text;
                      _cityController.text = textEditingController.text;
                      _errorMessage = null;
                    });
                  }
                });
              }
            });
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'City',
                labelStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal, width: 2.w),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2.w),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2.w),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                errorStyle: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.sp,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 10.h,
                ),
                prefixIcon: Icon(
                  Icons.location_city_outlined,
                  color: Colors.teal.shade600,
                  size: 18.sp,
                ),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'City is required'
                  : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            );
          },
          optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 300.w, maxHeight: 200.h),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        title: Text(
                          option,
                          style: TextStyle(fontSize: 14.sp),
                        ),
                        onTap: () {
                          onSelected(option);
                        },
                      );
                    },
                  ),
                ),
              ),
            );
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
          child: Form(
            key: _formKey,
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
                _buildCityAutocompleteField(),
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
                  _buildTextField(
                    'LinkedIn URL',
                    controller: _linkedinUrlController,
                    validator: _validateLinkedInUrl,
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
                        items: widget.experienceOptions.map((
                          String experience,
                        ) {
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
                  _buildTextField(
                    'LinkedIn URL',
                    controller: _linkedinUrlController,
                    validator: _validateLinkedInUrl,
                  ),
                ], // end of seeker/recruiter fields (else block)
              ], // end of children list
            ),
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
              : () async {
                  // run field validators first
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }

                  final mobileNumber = widget.mobileNumber?.trim() ?? '';
                  if (mobileNumber.isEmpty) {
                    setState(() {
                      _errorMessage =
                          'Mobile number is required to update profile.';
                    });
                    return;
                  }

                  // no need for separate LinkedIn validation; field validator covers it

                  final profileData = widget.isRecruiter
                      ? {
                          'name': _nameController.text.trim(),
                          'mobileNumber': mobileNumber,
                          'city': _selectedCity ?? '',
                          'companyName': _companyNameController.text.trim(),
                          'companyProfile': _companyProfileController.text
                              .trim(),
                          'designation': _designationController.text.trim(),
                          'linkedinUrl': _linkedinUrlController.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        }
                      : {
                          'name': _nameController.text.trim(),
                          'mobileNumber': mobileNumber,
                          'city': _selectedCity ?? '',
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
                          'linkedinUrl': _linkedinUrlController.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        };

                  // Capture context before asynchronous gap
                  // ignore: use_build_context_synchronously
                  final dialogContext = context;
                  // Call the update and wait for it to complete
                  await widget.onUpdate(profileData, setState);

                  // After successful update, close the dialog if still mounted
                  if (!mounted) return;
                  if (_errorMessage == null) {
                    // ignore: use_build_context_synchronously
                    Navigator.of(dialogContext).pop();
                  }
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
