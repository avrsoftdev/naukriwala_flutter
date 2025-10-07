import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:naukariwala/screens/recruiter_dashboard.dart';
import 'package:naukariwala/screens/seeker_dashboard.dart';
import '../services/auth_service.dart';
import 'dart:developer' as dev;

class UnifiedScreen extends StatefulWidget {
  const UnifiedScreen({super.key});

  @override
  UnifiedScreenState createState() => UnifiedScreenState();
}

class UnifiedScreenState extends State<UnifiedScreen> {
  String? _selectedRole;
  ScreenState _currentState = ScreenState.roleSelection;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(text: "+91");
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyNameController = TextEditingController();
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  
  final AuthService _authService = AuthService();

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
    } on FirebaseAuthException catch (e) {
      dev.log('Email sign-in error: $e', name: 'UnifiedScreen');
      if (e.code == 'invalid-credential') {
        _showSnack("You are not registered, kindly register first or check emailId and Password");
      } else {
        _showSnack("Login failed: ${e.message}");
      }
      setState(() => _isLoading = false);
    } catch (e) {
      dev.log('Unexpected error during sign-in: $e', name: 'UnifiedScreen');
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

  Future<bool> showPolicyDialog() async {
    bool accepted = false;
    bool isChecked = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              title: Text(
                'Privacy Policy & Terms and Conditions',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Privacy Policy for Naukariwala App',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Effective Date: October 3, 2025\n\n'
                      'Naukariwala ("we," "us," or "our") respects your privacy and is committed to protecting your personal information. This Privacy Policy explains how we collect, use, disclose, and safeguard your data when you use our mobile app (the "App"). By downloading, installing, or using the App, you consent to the practices described herein. If you do not agree, please do not use the App.\n\n'
                      '1. **Information We Collect** We collect information to provide and improve our services. This includes:\n'
                      '- **Personal Information**: Name, email address, phone number, resume/CV details (e.g., education, work experience, skills), location (if enabled), and job preferences provided during registration or job applications.\n'
                      '- **Device and Usage Data**: IP address, device type, operating system, app interactions (e.g., searches, applications viewed), and crash reports.\n'
                      '- **Location Data**: Approximate location for job recommendations (e.g., jobs near you), only with your explicit permission via device settings.\n'
                      '- **Third-Party Data**: Information from integrated services like social logins (e.g., Google or LinkedIn) or job boards.\n'
                      'We do not collect sensitive data such as race, religion, or health information unless voluntarily provided in your resume.\n\n'
                      '2. **How We Use Your Information** Your data helps us:\n'
                      '- Create and manage your account.\n'
                      '- Match you with relevant job opportunities using AI algorithms.\n'
                      '- Process job applications and communicate with employers on your behalf (with consent).\n'
                      '- Send personalized notifications, newsletters, or promotional content (you can opt out anytime).\n'
                      '- Analyze usage trends to improve the App\'s features and performance.\n'
                      '- Comply with legal obligations, prevent fraud, and enforce our Terms and Conditions.\n\n'
                      '3. **How We Share Your Information** We do not sell your personal data. We may share it with:\n'
                      '- **Service Providers**: Trusted third parties for hosting, analytics (e.g., Google Analytics), or payment processing, bound by confidentiality.\n'
                      '- **Employers**: Resume and application details when you apply to a job, as needed for recruitment.\n'
                      '- **Legal Authorities**: If required by law, subpoena, or to protect our rights/safety.\n'
                      '- **Business Transfers**: In case of merger, acquisition, or sale of assets.\n'
                      'For international users, data may be transferred to servers in India or the US, compliant with local laws.\n\n'
                      '4. **Your Rights and Choices** Depending on your location (e.g., under GDPR for EU users or CCPA for California residents):\n'
                      '- Access, update, or delete your data via App settings or by emailing privacy@naukariwala.com.\n'
                      '- Opt out of marketing emails or data sharing.\n'
                      '- Withdraw consent for location tracking anytime through device permissions.\n'
                      '- Request data portability or restriction of processing.\n'
                      'We retain your data only as long as necessary (e.g., 2 years post-last activity) or as required by law.\n\n'
                      '5. **Children\'s Privacy** The App is not intended for users under 18. We do not knowingly collect data from children.\n\n'
                      '6. **Security** We use industry-standard measures like encryption and secure servers to protect your data. However, no system is 100% secure, so we cannot guarantee absolute protection.\n\n'
                      '7. **Changes to This Policy** We may update this policy periodically. Changes will be posted in the App with the new effective date. Continued use constitutes acceptance.\n\n'
                      '8. **Contact Us** For questions, contact our Data Protection Officer at privacy@naukariwala.com.\n\n'
                      'Your trust is our priority – thank you for choosing Naukariwala!',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Terms and Conditions for Naukariwala App',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Effective Date: October 3, 2025\n\n'
                      'These Terms and Conditions ("Terms") form a binding agreement between you ("User," "you," or "your") and Naukariwala Pvt. Ltd. ("we," "us," or "our"), a company incorporated under the laws of India, regarding your use of the Naukariwala mobile app (the "App"). By downloading, accessing, or using the App, you agree to these Terms. If you do not agree, do not use the App.\n\n'
                      '1. **Eligibility** You must be at least 18 years old and legally capable of entering contracts to use the App. By using it, you represent that you meet these requirements.\n\n'
                      '2. **App Description and License** The App is a job search platform allowing Users to create profiles, search/upload resumes, apply for jobs, and connect with employers. We grant you a limited, non-exclusive, non-transferable, revocable license to use the App for personal, non-commercial purposes on your mobile device. You may not:\n'
                      '- Copy, modify, distribute, or reverse-engineer the App.\n'
                      '- Use it for illegal activities, spam, or harassment.\n'
                      '- Remove any copyrights or trademarks.\n\n'
                      '3. **User Accounts and Content**\n'
                      '- **Registration**: Provide accurate information during signup. You are responsible for maintaining confidentiality of your login credentials.\n'
                      '- **User Content**: Resumes, profiles, and messages you post ("User Content") must be truthful, non-infringing, and compliant with laws. You retain ownership but grant us a worldwide, royalty-free license to use, display, and share it for App purposes (e.g., job matching).\n'
                      '- **Our Content**: All App materials (e.g., job listings, algorithms) are our property or licensed to us. You may not use them without permission.\n'
                      'We do not endorse or verify job listings or User Content and disclaim liability for inaccuracies or disputes.\n\n'
                      '4. **Job Applications and Employer Interactions**\n'
                      '- Applying to jobs via the App authorizes us to share your User Content with employers.\n'
                      '- We are not an employment agency; we facilitate connections but do not guarantee hires.\n'
                      '- Employers may contact you directly; any agreements are between you and them.\n\n'
                      '5. **Prohibited Conduct** You agree not to:\n'
                      '- Post false, misleading, or harmful content.\n'
                      '- Violate privacy rights or intellectual property.\n'
                      '- Use bots, scripts, or automated tools to access the App.\n'
                      '- Interfere with other Users\' experiences.\n'
                      'Violations may result in account suspension or termination.\n\n'
                      '6. **Payments and Subscriptions** Certain features (e.g., premium job alerts) may require payment. All fees are non-refundable unless specified. We use third-party processors; you agree to their terms.\n\n'
                      '7. **Disclaimers and Limitations of Liability** The App is provided "as is" without warranties. We disclaim liability for:\n'
                      '- Job outcomes, employer actions, or User interactions.\n'
                      '- Data loss, viruses, or interruptions.\n'
                      'Our liability is limited to the fees you paid us in the last 12 months. No consequential damages.\n\n'
                      '8. **Termination** We may terminate or suspend your access anytime for violations. Upon termination, your license ends, and you must delete the App.\n\n'
                      '9. **Governing Law and Dispute Resolution** These Terms are governed by Indian law. Disputes shall be resolved exclusively in Mumbai courts. For informal resolution, contact support@naukariwala.com.\n\n'
                      '10. **Changes to Terms** We may update these Terms; continued use constitutes acceptance. Check the App for the latest version.\n\n'
                      '11. **Contact Us** Questions? Email legal@naukariwala.com.',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        Checkbox(
                          value: isChecked,
                          onChanged: (value) {
                            setDialogState(() {
                              isChecked = value ?? false;
                            });
                          },
                          activeColor: Colors.teal,
                        ),
                        Expanded(
                          child: Text(
                            'I agree to the Privacy Policy and Terms and Conditions',
                            style: TextStyle(fontSize: 14.sp),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                AnimatedScaleButton(
                  onPressed: () {
                    if (isChecked) {
                      accepted = true;
                      Navigator.of(context).pop();
                    } else {
                      _showSnack('Please agree to the Privacy Policy and Terms and Conditions.');
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade700, Colors.teal.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'Accept',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    return accepted;
  }

  Future<void> _submitSignup() async {
    if (!_formKey.currentState!.validate()) {
      _showSnack("Please complete all required fields.");
      return;
    }

    // Show policy dialog before proceeding with signup
    bool accepted = await showPolicyDialog();
    if (!accepted) {
      dev.log('User did not accept policies, signup aborted', name: 'UnifiedScreen');
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
      final user = userCredential.user;

      final uid = user?.uid;
      if (uid == null) throw Exception("Failed to register user.");

      final signupData = {
        ..._formData,
        'Mobile Number': _phoneController.text.trim(),
        'Email Id': _emailController.text.trim(),
        'UID': uid,
        'role': _selectedRole,
      };
      if (_currentState == ScreenState.recruiterSignup) {
        signupData['companyName'] = _formData['Company Name']?.toString().trim() ?? '';
      }

      await _authService.storeSignupData(
        isRecruiter: _currentState == ScreenState.recruiterSignup,
        data: signupData,
      );

      _showSnack('Signup successful!');
      setState(() {
        _formData.clear();
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
        keyboardType: label == 'Email Id'
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
        validator: (value) {
          final trimmed = value?.trim() ?? '';
          if (trimmed.isEmpty) return 'This field is required';
          if (label == 'Email Id' && !trimmed.contains('@')) return 'Invalid email format';
          if (label == 'Password' && trimmed.length < 6) return 'Password must be at least 6 characters';
          return null;
        },
        onSaved: (value) => _formData[label] = value!.trim(),
        style: TextStyle(fontSize: 16.sp),
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
                                'Powered by AVR SofDev Pvt. Ltd.',
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
                              SizedBox(height: 20.h),
                            ],
                          ),
                        ),
                      )
                    : _currentState == ScreenState.login
                        ? SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                SizedBox(height: 20.h),
                              ],
                            ),
                          )
                        : _currentState == ScreenState.seekerSignup || _currentState == ScreenState.recruiterSignup
                            ? SingleChildScrollView(
                                child: Container(
                                  constraints: BoxConstraints(maxHeight: 500.h),
                                  child: Form(
                                    key: _formKey,
                                    child: ListView(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.only(bottom: 20.h),
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
    _emailController.dispose();
    _passwordController.dispose();
    _companyNameController.dispose();
    super.dispose();
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

enum LoginMethod { email }
enum ScreenState { roleSelection, login, seekerSignup, recruiterSignup }