import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:naukariwala/screens/recruiter_dashboard.dart';
import 'package:naukariwala/screens/seeker_dashboard.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../services/auth_service.dart';
import 'dart:developer' as dev;

class UnifiedScreen extends StatefulWidget {
  const UnifiedScreen({super.key});

  @override
  UnifiedScreenState createState() => UnifiedScreenState();
}

class UnifiedScreenState extends State<UnifiedScreen> {
  String? _selectedRole;
  LoginMethod _method = LoginMethod.phone;
  ScreenState _currentState = ScreenState.roleSelection;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(text: "+91");
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyNameController = TextEditingController();
  String? _verificationId;
  bool _otpSent = false;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  List<String> _selectedSkills = [];

  final AuthService _authService = AuthService();
  final List<String> educationOptions = [
    'High School',
    'Associate Degree',
    'Bachelor’s Degree',
    'Master’s Degree',
    'Doctorate/PhD',
    'Diploma',
    'Other',
  ];
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
    _checkIfLoggedIn();
  }

  void _checkIfLoggedIn() async {
    dev.log('Checking if user is signed in', name: 'UnifiedScreen');
    if (await _authService.isSignedIn()) {
      dev.log('User is signed in, redirecting based on role', name: 'UnifiedScreen');
      await _redirectBasedOnRole();
    } else {
      dev.log('No user signed in, staying at role selection', name: 'UnifiedScreen');
      setState(() {
        _currentState = ScreenState.roleSelection;
      });
    }
  }

  Future<void> _redirectBasedOnRole() async {
    setState(() => _isLoading = true);
    final role = await _authService.getUserRole();
    setState(() => _isLoading = false);

    dev.log('Redirecting with role: $role', name: 'UnifiedScreen');
    if (!mounted) return;
    if (role == 'recruiter') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RecruiterDashboard()),
      );
    } else if (role == 'seeker') {
      final profile = await _authService.fetchProfileData(isRecruiter: false);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SeekerDashboard(
            seekerName: profile?['name']?.toString() ?? _formData['Name'] ?? 'Seeker',
            photoUrl: profile?['photoUrl']?.toString(),
          ),
        ),
      );
    } else {
      dev.log('No valid role found, staying at role selection', name: 'UnifiedScreen');
      setState(() {
        _currentState = ScreenState.roleSelection;
      });
    }
  }

  void _sendOTP() async {
    final raw = _phoneController.text.trim();
    if (!RegExp(r'^\+91[0-9]{10}$').hasMatch(raw)) {
      _showSnack("Enter valid +91 followed by 10-digit number");
      return;
    }

    setState(() => _isLoading = true);
    dev.log('Sending OTP to $raw', name: 'UnifiedScreen');
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: raw,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (cred) async {
        dev.log('Phone verification completed, signing in', name: 'UnifiedScreen');
        try {
          await FirebaseAuth.instance.signInWithCredential(cred);
          await _redirectBasedOnRole();
        } catch (e) {
          dev.log('Error signing in with credential: $e', name: 'UnifiedScreen');
          _showSnack("Sign-in failed: ${e.toString()}");
          setState(() => _isLoading = false);
        }
      },
      verificationFailed: (e) {
        dev.log('Phone verification failed: ${e.message}', name: 'UnifiedScreen');
        _showSnack("Verification failed: ${e.message}");
        setState(() => _isLoading = false);
      },
      codeSent: (verId, _) {
        dev.log('OTP sent, verificationId: $verId', name: 'UnifiedScreen');
        setState(() {
          _verificationId = verId;
          _otpSent = true;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (verId) {
        dev.log('OTP auto retrieval timeout, verificationId: $verId', name: 'UnifiedScreen');
        _verificationId = verId;
      },
    );
  }

  void _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showSnack("Enter valid 6-digit OTP");
      return;
    }

    setState(() => _isLoading = true);
    try {
      dev.log('Verifying OTP: $otp', name: 'UnifiedScreen');
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      await _redirectBasedOnRole();
    } catch (e) {
      dev.log('OTP verification error: $e', name: 'UnifiedScreen');
      _showSnack("Invalid OTP. Try again.");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    if (email.isEmpty || pass.length < 6) {
      _showSnack("Enter valid credentials");
      return;
    }

    setState(() => _isLoading = true);
    try {
      dev.log('Signing in with email: $email', name: 'UnifiedScreen');
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      await _redirectBasedOnRole();
    } catch (e) {
      dev.log('Email sign-in error: $e', name: 'UnifiedScreen');
      _showSnack("Login failed: ${e.toString()}");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack("Please enter a valid email address");
      return;
    }

    setState(() => _isLoading = true);
    try {
      dev.log('Sending password reset email to: $email', name: 'UnifiedScreen');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack("Password reset email sent! Check your inbox.");
    } catch (e) {
      dev.log('Password reset error: $e', name: 'UnifiedScreen');
      _showSnack("Failed to send reset email: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitSignup() async {
    if (!_formKey.currentState!.validate()) {
      _showSnack("Please complete all required fields.");
      return;
    }

    if (_selectedRole == 'seeker' && _selectedSkills.isEmpty) {
      _showSnack("Please select at least one skill.");
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      dev.log('Submitting signup for role: $_selectedRole', name: 'UnifiedScreen');
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user?.uid;
      if (uid == null) throw Exception("Failed to register user.");

      final signupData = {
        ..._formData,
        'Mobile Number': _phoneController.text.trim(),
        'Email Id': _emailController.text.trim(),
        'UID': uid,
      };
      if (_currentState == ScreenState.recruiterSignup) {
        signupData['companyName'] = _formData['Company Name']?.toString().trim() ?? '';
      } else if (_currentState == ScreenState.seekerSignup) {
        signupData['education'] = _formData['Education']?.toString().trim() ?? '';
        signupData['specialization'] = _formData['specialization']?.toString().trim() ?? '';
        signupData['skills'] = _selectedSkills;
      }

      await _authService.storeSignupData(
        isRecruiter: _currentState == ScreenState.recruiterSignup,
        data: signupData,
      );

      _showSnack('Signup successful!');
      setState(() {
        _formData.clear();
        _selectedSkills.clear();
      });
      await _redirectBasedOnRole();
    } catch (e) {
      dev.log('[Signup ERROR] $e', name: 'UnifiedScreen');
      _showSnack('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(fontSize: 14.sp),
        ),
        backgroundColor: msg.contains('Error') || msg.contains('failed') ? Colors.red : Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }

  Widget _buildTextField(String label,
      {bool isPassword = false, TextInputType? keyboardType, TextEditingController? controller}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: label == 'Mobile Number (+91xxxxxxxxxx)' || label == 'Enter OTP'
            ? TextInputType.phone
            : label == 'Email Id'
                ? TextInputType.emailAddress
                : keyboardType ?? TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Colors.teal, width: 2.w),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
        inputFormatters: label == 'Mobile Number (+91xxxxxxxxxx)'
            ? [_PhoneNumberFormatter()]
            : label == 'Enter OTP'
                ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)]
                : null,
        validator: (value) {
          final trimmed = value?.trim() ?? '';
          if (trimmed.isEmpty) return 'This field is required';
          if (label == 'Mobile Number (+91xxxxxxxxxx)' && !RegExp(r'^\+91[0-9]{10}$').hasMatch(trimmed)) {
            return 'Please enter a valid mobile number in the format +911234567890';
          }
          if (label == 'Email Id' && !trimmed.contains('@')) return 'Invalid email format';
          if (label == 'Password' && trimmed.length < 6) return 'Password must be at least 6 characters';
          return null;
        },
        onSaved: (value) => _formData[label] = value!.trim(),
        style: TextStyle(fontSize: 16.sp),
      ),
    );
  }

  Widget _buildEducationDropdown() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Education',
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Colors.teal, width: 2.w),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        value: _formData['Education'] ?? educationOptions.first,
        items: educationOptions.map((edu) {
          return DropdownMenuItem(
            value: edu,
            child: Text(edu, style: TextStyle(color: Colors.black87, fontSize: 14.sp)),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _formData['Education'] = value!;
          });
        },
        validator: (value) => value == null ? 'Please select an education level' : null,
        onSaved: (value) => _formData['Education'] = value!,
      ),
    );
  }

  Widget _buildSpecializationDropdown() {
    return Padding(
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
            borderSide: BorderSide(color: Colors.teal, width: 2.w),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        value: _formData['specialization'] ?? specializationOptions.last,
        items: specializationOptions.map((spec) {
          return DropdownMenuItem(
            value: spec,
            child: Text(spec, style: TextStyle(color: Colors.black87, fontSize: 14.sp)),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _formData['specialization'] = value!;
            _selectedSkills = [];
          });
        },
        validator: (value) => value == null ? 'Please select a specialization' : null,
        onSaved: (value) => _formData['specialization'] = value!,
      ),
    );
  }

  Widget _buildSkillsMultiSelect() {
    final specialization = _formData['specialization'] ?? specializationOptions.last;
    final availableSkills = skillsBySpecialization[specialization] ?? [];
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skills',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
          ),
          SizedBox(height: 8.h),
          AnimatedScaleButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => MultiSelectDialog(
                  items: availableSkills.map((skill) => MultiSelectItem(skill, skill)).toList(),
                  initialValue: _selectedSkills,
                  title: Text('Select Skills', style: TextStyle(color: Colors.black87, fontSize: 16.sp)),
                  selectedColor: Colors.teal,
                ),
              ).then((selected) {
                if (selected != null) {
                  setState(() {
                    _selectedSkills = selected.cast<String>();
                  });
                }
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12.r),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4.r,
                    offset: Offset(0, 2.h),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedSkills.isEmpty ? 'Select Skills' : 'Selected ${_selectedSkills.length} skill(s)',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.teal, size: 24.sp),
                ],
              ),
            ),
          ),
          if (_selectedSkills.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(
                'Selected: ${_selectedSkills.join(', ')}',
                style: TextStyle(color: Colors.black87, fontSize: 14.sp),
              ),
            ),
          if (_formKey.currentState?.validate() == false && _selectedSkills.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(
                'Please select at least one skill',
                style: TextStyle(color: Colors.red, fontSize: 12.sp),
              ),
            ),
        ],
      ),
    );
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
            leading: _currentState == ScreenState.login || _currentState == ScreenState.seekerSignup || _currentState == ScreenState.recruiterSignup
                ? IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
                    onPressed: () {
                      setState(() {
                        if (_currentState == ScreenState.login) {
                          _currentState = ScreenState.roleSelection;
                        } else {
                          _currentState = ScreenState.login;
                        }
                      });
                    },
                  )
                : null,
            title: Text(
              _currentState == ScreenState.roleSelection
                  ? "Welcome to Naukariwala"
                  : _currentState == ScreenState.login
                      ? "Login"
                      : _selectedRole == 'seeker'
                          ? "Seeker Signup"
                          : "Recruiter Signup",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20.sp),
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
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all(20.w),
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                      strokeWidth: 4.w,
                    ),
                  )
                : _currentState == ScreenState.roleSelection
                    ? SingleChildScrollView(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: 200.h,
                                width: 200.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: const DecorationImage(
                                    image: AssetImage('assets/logo.png'),
                                    fit: BoxFit.contain,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 8.r,
                                      offset: Offset(0, 4.h),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 20.h),
                              Text(
                                'Where Talent Meets Opportunity',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Powered by AVR Softwares Pvt. Ltd.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                              SizedBox(height: 32.h),
                              Text(
                                'Select Your Role',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 20.h),
                              AnimatedScaleButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedRole = 'recruiter';
                                    _currentState = ScreenState.login;
                                  });
                                },
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.business, color: Colors.white, size: 24.sp),
                                      SizedBox(width: 8.w),
                                      Text(
                                        "I'm a Recruiter",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.h),
                              AnimatedScaleButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedRole = 'seeker';
                                    _currentState = ScreenState.login;
                                  });
                                },
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person, color: Colors.white, size: 24.sp),
                                      SizedBox(width: 8.w),
                                      Text(
                                        "I'm a Seeker",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 20.h), // Added to ensure bottom padding
                            ],
                          ),
                        ),
                      )
                    : _currentState == ScreenState.login
                        ? SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ToggleButtons(
                                  isSelected: [_method == LoginMethod.phone, _method == LoginMethod.email],
                                  onPressed: (i) {
                                    setState(() {
                                      _method = i == 0 ? LoginMethod.phone : LoginMethod.email;
                                      _otpSent = false;
                                      _isLoading = false;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12.r),
                                  selectedColor: Colors.teal,
                                  fillColor: Colors.teal.shade100,
                                  color: Colors.grey.shade600,
                                  constraints: BoxConstraints(minHeight: 40.h, minWidth: 120.w),
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                                      child: Text("Phone", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                                      child: Text("Email", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp)),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 20.h),
                                if (_method == LoginMethod.phone) ...[
                                  _buildTextField(
                                    'Mobile Number (+91xxxxxxxxxx)',
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                  ),
                                  if (_otpSent)
                                    _buildTextField(
                                      'Enter OTP',
                                      controller: _otpController,
                                      keyboardType: TextInputType.number,
                                    ),
                                  SizedBox(height: 16.h),
                                  AnimatedScaleButton(
                                    onPressed: () {
                                      if (_isLoading) return;
                                      if (_otpSent) {
                                        _verifyOTP();
                                      } else {
                                        _sendOTP();
                                      }
                                    },
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
                                      child: _isLoading
                                          ? CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              strokeWidth: 4.w,
                                            )
                                          : Text(
                                              _otpSent ? 'Verify OTP' : 'Send OTP',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16.sp,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                    ),
                                  ),
                                  if (_otpSent)
                                    TextButton(
                                      onPressed: _isLoading ? null : _sendOTP,
                                      child: Text(
                                        'Resend OTP',
                                        style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.w600, fontSize: 14.sp),
                                      ),
                                    ),
                                ] else ...[
                                  _buildTextField(
                                    'Email',
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  _buildTextField(
                                    'Password',
                                    controller: _passwordController,
                                    isPassword: true,
                                  ),
                                  SizedBox(height: 8.h),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _isLoading ? null : _resetPassword,
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.w600, fontSize: 14.sp),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  AnimatedScaleButton(
                                    onPressed: () {
                                      if (_isLoading) return;
                                      _signInWithEmail();
                                    },
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
                                      child: _isLoading
                                          ? CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              strokeWidth: 4.w,
                                            )
                                          : Text(
                                              'Login with Email',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16.sp,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                    ),
                                  ),
                                ],
                                SizedBox(height: 24.h),
                                AnimatedScaleButton(
                                  onPressed: () {
                                    setState(() {
                                      _currentState = _selectedRole == 'seeker'
                                          ? ScreenState.seekerSignup
                                          : ScreenState.recruiterSignup;
                                    });
                                  },
                                  child: Text(
                                    'New here? Register',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      color: Colors.teal.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20.h), // Added to ensure bottom padding
                              ],
                            ),
                          )
                        : _currentState == ScreenState.seekerSignup || _currentState == ScreenState.recruiterSignup
                            ? SingleChildScrollView(
                                child: Form(
                                  key: _formKey,
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 20.h),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildTextField(
                                          'Name',
                                          controller: _nameController,
                                        ),
                                        _buildTextField(
                                          'Mobile Number (+91xxxxxxxxxx)',
                                          controller: _phoneController,
                                          keyboardType: TextInputType.phone,
                                        ),
                                        _buildTextField(
                                          'Email Id',
                                          controller: _emailController,
                                          keyboardType: TextInputType.emailAddress,
                                        ),
                                        _buildTextField(
                                          'Password',
                                          controller: _passwordController,
                                          isPassword: true,
                                        ),
                                        if (_currentState == ScreenState.recruiterSignup)
                                          _buildTextField(
                                            'Company Name',
                                            controller: _companyNameController,
                                          ),
                                        if (_currentState == ScreenState.seekerSignup) ...[
                                          _buildEducationDropdown(),
                                          _buildSpecializationDropdown(),
                                          _buildSkillsMultiSelect(),
                                        ],
                                        SizedBox(height: 20.h),
                                        AnimatedScaleButton(
                                          onPressed: () {
                                            if (_isLoading) return;
                                            _submitSignup();
                                          },
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
                                              'Submit',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
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
                              )
                            : SizedBox.shrink(),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }
}

// Custom TextInputFormatter to preserve +91 prefix
class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text;

    // If the input is empty, reset to "+91"
    if (newText.isEmpty) {
      return const TextEditingValue(
        text: '+91',
        selection: TextSelection.collapsed(offset: 3),
      );
    }

    // Ensure the input starts with "+91"
    if (!newText.startsWith('+91')) {
      newText = '+91${newText.replaceAll(RegExp(r'^\+91|[^0-9]'), '')}';
    }

    // Limit to +91 followed by up to 10 digits
    String digits = newText.replaceAll('+91', '');
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
      newText = '+91$digits';
    }

    // Update cursor position
    int cursorOffset = newValue.selection.baseOffset;
    if (cursorOffset < 3) {
      cursorOffset = 3; // Keep cursor after +91
    } else if (cursorOffset > newText.length) {
      cursorOffset = newText.length;
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorOffset),
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

enum LoginMethod { phone, email }
enum ScreenState { roleSelection, login, seekerSignup, recruiterSignup }