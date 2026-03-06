// ignore_for_file: deprecated_member_use

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:naukariwala/screens/recruiter_dashboard.dart';
import 'package:naukariwala/screens/seeker_dashboard.dart';
import '../services/auth_service.dart';
import 'dart:developer' as dev;
import 'dart:async';

class UnifiedScreen extends StatefulWidget {
  const UnifiedScreen({super.key});

  @override
  UnifiedScreenState createState() => UnifiedScreenState();
}

class UnifiedScreenState extends State<UnifiedScreen> {
  static const Color _primaryBlue = Color(0xFF0C4A7D);
  static const Color _accentTeal = Color(0xFF00A6A6);
  static const Color _deepNavy = Color(0xFF0B1E39);

  String? _selectedRole;
  ScreenState _currentState = ScreenState.roleSelection;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyNameController = TextEditingController();
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _tempFormData = {};

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn();

    _phoneController.addListener(() {
      final text = _phoneController.text;
      final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
      final limited = digitsOnly.length > 10 ? digitsOnly.substring(0, 10) : digitsOnly;

      if (limited != text) {
        _phoneController.value = TextEditingValue(
          text: limited,
          selection: TextSelection.collapsed(offset: limited.length),
        );
      }
    });
  }

  void _checkIfLoggedIn() async {
    dev.log('Checking if user is signed in', name: 'UnifiedScreen');
    if (await _authService.isSignedIn()) {
      dev.log('User is signed in, redirecting based on role', name: 'UnifiedScreen');
      await _redirectBasedOnRole();
    } else {
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
            seekerName: profile?['name']?.toString() ?? 'Seeker',
            photoUrl: profile?['photoUrl']?.toString(),
          ),
        ),
      );
    } else {
      setState(() => _currentState = ScreenState.roleSelection);
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
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      await _redirectBasedOnRole();
    } on FirebaseAuthException catch (e) {
      dev.log('Email sign-in error: $e', name: 'UnifiedScreen');
      if (e.code == 'invalid-credential') {
        _showSnack("Invalid email or password");
      } else {
        _showSnack(e.message ?? "Login failed");
      }
    } catch (e) {
      _showSnack("Something went wrong");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack("Please enter a valid email");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack("Password reset link sent!");
    } catch (e) {
      _showSnack("Failed to send reset email");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              title: Text(
                'Privacy Policy & Terms and Conditions',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.46,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacy Policy for Naukariwala App',
                            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: Colors.black87),
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
                            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'Terms and Conditions for Naukariwala App',
                            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: Colors.black87),
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
                            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Checkbox(
                        value: isChecked,
                        onChanged: (value) {
                          setDialogState(() => isChecked = value ?? false);
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700)),
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
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp),
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

    bool accepted = await showPolicyDialog();
    if (!accepted) return;

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('User creation failed');

      await user.sendEmailVerification();

      _showSnack('Verification email sent! Please check your inbox (and spam/junk folder).');

      _tempFormData.clear();
      _tempFormData.addAll({
        'Name': _nameController.text.trim(),
        'Mobile Number': '+91${_phoneController.text.trim()}',
        'Email Id': email,
        if (_currentState == ScreenState.recruiterSignup) 'companyName': _companyNameController.text.trim(),
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            role: _selectedRole!,
            tempFormData: _tempFormData,
            authService: _authService,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Signup failed');
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(fontSize: 14.sp)),
        backgroundColor: msg.toLowerCase().contains('error') || msg.toLowerCase().contains('fail') ? Colors.red : Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }

  Widget _buildTextField(
    String label, {
    bool isPassword = false,
    TextInputType? keyboardType,
    TextEditingController? controller,
  }) {
    final isPhone = label.toLowerCase().contains('mobile') || label.toLowerCase().contains('phone');
    final lowerLabel = label.toLowerCase();
    final IconData icon = lowerLabel.contains('email')
        ? Icons.alternate_email_rounded
        : lowerLabel.contains('password')
            ? Icons.lock_outline_rounded
            : lowerLabel.contains('mobile') || lowerLabel.contains('phone')
                ? Icons.call_outlined
                : lowerLabel.contains('company')
                    ? Icons.business_center_outlined
                    : Icons.person_outline_rounded;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: isPhone ? TextInputType.phone : (keyboardType ?? TextInputType.text),
        inputFormatters: isPhone
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ]
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _primaryBlue.withOpacity(0.85), size: 22.sp),
          prefixText: isPhone ? '+91 ' : null,
          prefixStyle: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 14.sp),
          labelStyle: TextStyle(color: Colors.blueGrey.shade700, fontSize: 14.sp, fontWeight: FontWeight.w500),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(color: Colors.blueGrey.shade100, width: 1.2.w),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(color: _accentTeal, width: 2.w),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.95),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          if (isPhone && v.replaceAll(RegExp(r'\D'), '').length != 10) {
            return 'Enter valid 10-digit number';
          }
          if (label == 'Email Id' && !v.contains('@')) return 'Invalid email';
          if (label == 'Password' && v.length < 6) return 'Min 6 characters';
          return null;
        },
        onSaved: (v) {
          if (isPhone) {
            final digits = v!.replaceAll(RegExp(r'\D'), '');
            _tempFormData['Mobile Number'] = '+91$digits';
          } else {
            _tempFormData[label] = v!.trim();
          }
        },
        style: TextStyle(fontSize: 16.sp),
      ),
    );
  }

  Widget _buildAuthBackground({
    required String imagePath,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x880B1E39),
                  Color(0xAA0C4A7D),
                  Color(0xEE0B1E39),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 18.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10.h),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 24.h),
                child,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard({required Widget child}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 22.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        color: Colors.white.withOpacity(0.92),
        border: Border.all(color: Colors.white.withOpacity(0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 24.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) {
        return Scaffold(
          extendBodyBehindAppBar: _currentState == ScreenState.login ||
              _currentState == ScreenState.seekerSignup ||
              _currentState == ScreenState.recruiterSignup,
          appBar: AppBar(
            leading: _currentState != ScreenState.roleSelection
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
            backgroundColor: _currentState == ScreenState.roleSelection ? null : Colors.transparent,
            flexibleSpace: _currentState == ScreenState.roleSelection
                ? Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryBlue, _deepNavy],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  )
                : null,
            elevation: _currentState == ScreenState.roleSelection ? 4 : 0,
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.teal)))
              : _currentState == ScreenState.roleSelection
                  ? _buildRoleSelection()
                  : _currentState == ScreenState.login
                      ? _buildLogin()
                      : _buildSignupForm(),
        );
      },
    );
  }

  Widget _buildRoleSelection() {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 40.h),
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
                    color: Colors.black.withOpacity(0.2),
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
              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
            ),
            SizedBox(height: 8.h),
            Text(
              'Powered by AVR SofDev Pvt. Ltd.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.blue.shade600),
            ),
            SizedBox(height: 32.h),
            Text(
              'Select Your Role',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            SizedBox(height: 24.h),
            AnimatedScaleButton(
              onPressed: () {
                setState(() {
                  _selectedRole = 'recruiter';
                  _currentState = ScreenState.login;
                });
              },
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 32.w),
                padding: EdgeInsets.symmetric(vertical: 16.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.teal.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4.r, offset: Offset(0, 2.h)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.business, color: Colors.white, size: 24.sp),
                    SizedBox(width: 12.w),
                    Text(
                      "I'm a Recruiter",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp),
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
                margin: EdgeInsets.symmetric(horizontal: 32.w),
                padding: EdgeInsets.symmetric(vertical: 16.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.teal.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4.r, offset: Offset(0, 2.h)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person, color: Colors.white, size: 24.sp),
                    SizedBox(width: 12.w),
                    Text(
                      "I'm a Seeker",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return _buildAuthBackground(
      imagePath: 'assets/loginpage.jpg',
      title: 'Welcome Back',
      subtitle: 'Sign in to continue your journey with Naukariwala.',
      child: _buildAuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Login',
              style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w800, color: _deepNavy),
            ),
            SizedBox(height: 4.h),
            Text(
              'Use your registered email and password.',
              style: TextStyle(fontSize: 13.sp, color: Colors.blueGrey.shade700),
            ),
            SizedBox(height: 12.h),
            _buildTextField('Email Id', controller: _emailController),
            SizedBox(height: 10.h),
            _buildTextField('Password', isPassword: true, controller: _passwordController),
            SizedBox(height: 4.h),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _resetPassword,
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.w700, fontSize: 13.sp),
                ),
              ),
            ),
            SizedBox(height: 14.h),
            AnimatedScaleButton(
              onPressed: _isLoading ? () {} : _signInWithEmail,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 15.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primaryBlue, _accentTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(color: _primaryBlue.withOpacity(0.35), blurRadius: 10.r, offset: Offset(0, 4.h)),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Login with Email',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('New here?', style: TextStyle(fontSize: 14.sp, color: Colors.blueGrey.shade700)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentState = _selectedRole == 'seeker' ? ScreenState.seekerSignup : ScreenState.recruiterSignup;
                    });
                  },
                  child: Text(
                    'Register',
                    style: TextStyle(fontSize: 14.sp, color: _primaryBlue, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupForm() {
    return _buildAuthBackground(
      imagePath: 'assets/signup_page.jpg',
      title: 'Create Account',
      subtitle: 'Build your profile and unlock better opportunities.',
      child: _buildAuthCard(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField('Name', controller: _nameController),
              _buildTextField('Mobile Number', controller: _phoneController),
              _buildTextField('Email Id', controller: _emailController),
              _buildTextField('Password', isPassword: true, controller: _passwordController),
              if (_currentState == ScreenState.recruiterSignup)
                _buildTextField('Company Name', controller: _companyNameController),
              SizedBox(height: 18.h),
              AnimatedScaleButton(
                onPressed: _isLoading ? () {} : _submitSignup,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 15.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_primaryBlue, _accentTeal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [
                      BoxShadow(color: _primaryBlue.withOpacity(0.35), blurRadius: 10.r, offset: Offset(0, 4.h)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Create Account',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account?', style: TextStyle(fontSize: 14.sp, color: Colors.blueGrey.shade700)),
                  TextButton(
                    onPressed: () {
                      setState(() => _currentState = ScreenState.login);
                    },
                    child: Text(
                      'Login',
                      style: TextStyle(fontSize: 14.sp, color: _primaryBlue, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

// ────────────────────────────────────────────────
//  EMAIL VERIFICATION SCREEN
// ────────────────────────────────────────────────

class EmailVerificationScreen extends StatefulWidget {
  final String role;
  final Map<String, dynamic> tempFormData;
  final AuthService authService;

  const EmailVerificationScreen({
    super.key,
    required this.role,
    required this.tempFormData,
    required this.authService,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _timer;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        timer.cancel();
        return;
      }

      await user.reload();

      if (user.emailVerified) {
        timer.cancel();
        setState(() => _checking = false);

        try {
          final data = {
            ...widget.tempFormData,
            'UID': user.uid,
            'role': widget.role,
          };

          await widget.authService.storeSignupData(
            isRecruiter: widget.role == 'recruiter',
            data: data,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Email verified! Welcome!")),
            );

            if (widget.role == 'recruiter') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RecruiterDashboard()));
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => SeekerDashboard(
                    seekerName: widget.tempFormData['Name'] ?? 'User',
                    photoUrl: null,
                  ),
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Profile save failed: $e")),
            );
          }
        }
      }
    });
  }

  Future<void> _resend() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Verification email resent")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Resend failed: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.tempFormData['Email Id'] ?? 'your email';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Your Email"),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: _checking
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 32),
                    Text("Verification email sent to:", style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(email, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    const Text(
                      "Please open your email and click the verification link.\n\n(Also check spam/junk folder)",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    OutlinedButton.icon(
                      onPressed: _resend,
                      icon: const Icon(Icons.email),
                      label: const Text("Resend Email"),
                    ),
                  ],
                )
              : const Text("Verified! Redirecting...", style: TextStyle(fontSize: 18)),
        ),
      ),
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

enum ScreenState { roleSelection, login, seekerSignup, recruiterSignup }
