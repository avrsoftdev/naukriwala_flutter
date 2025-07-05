import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  LoginMethod _method = LoginMethod.phone;
  ScreenState _currentState = ScreenState.roleSelection;

  final _phoneController = TextEditingController(text: "+91");
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _verificationId;
  bool _otpSent = false;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _formData = {};

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
    if (role == 'recruiter') {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RecruiterDashboard()),
      );
    } else if (role == 'seeker') {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SeekerDashboard(seekerName: _formData['Name'], photoUrl: null)),
      );
    } else {
      dev.log('No valid role found, staying at role selection', name: 'UnifiedScreen');
      if (mounted) {
        setState(() {
          _currentState = ScreenState.roleSelection;
        });
      }
    }
  }

  void _sendOTP() async {
    final raw = _phoneController.text.trim();
    if (!RegExp(r'^\+91\d{10}$').hasMatch(raw)) {
      _showSnack("Enter valid +91 followed by 10-digit number");
      return;
    }

    setState(() => _isLoading = true);
    dev.log('Sending OTP to $raw', name: 'UnifiedScreen');
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: raw,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (cred) async {
        final user = _authService.getCurrentUser();
        if (user != null) {
          dev.log('Phone verification completed, linking credential', name: 'UnifiedScreen');
          await user.linkWithCredential(cred);
          await _redirectBasedOnRole();
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
      final user = _authService.getCurrentUser();
      if (user != null) {
        await user.linkWithCredential(cred);
        await _redirectBasedOnRole();
      }
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

  Future<void> _submitSignup() async {
    if (!_formKey.currentState!.validate()) {
      _showSnack("Please complete all required fields.");
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

      await _authService.storeSignupData(
        isRecruiter: _selectedRole == 'recruiter',
        data: {
          ..._formData,
          'Mobile Number': _phoneController.text.trim(),
          'Email Id': _emailController.text.trim(),
          'UID': uid,
        },
      );

      _showSnack('Signup successful!');
      setState(() => _formData.clear()); // Clear form data after successful signup
      await _redirectBasedOnRole();
    } catch (e) {
      dev.log('[Signup ERROR] $e', name: 'UnifiedScreen');
      _showSnack('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(String label,
      {bool isPassword = false, TextInputType? keyboardType, TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType ?? TextInputType.text,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        validator: (value) {
          final trimmed = value?.trim() ?? '';
          if (trimmed.isEmpty) return 'This field is required';
          if (label == 'Mobile Number' && !RegExp(r'^\+91\d{10}$').hasMatch(trimmed)) {
            return 'Must be in format: +911234567890';
          }
          if (label == 'Email Id' && !trimmed.contains('@')) return 'Invalid email format';
          return null;
        },
        onSaved: (value) => _formData[label] = value!.trim(),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentState == ScreenState.roleSelection
            ? "Welcome to Naukariwala"
            : _currentState == ScreenState.login
                ? "Login"
                : _selectedRole == 'seeker'
                    ? "Seeker Signup"
                    : "Recruiter Signup"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _currentState == ScreenState.roleSelection
                ? Center( // Center the entire column
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 250, // Increased height to show full logo
                          width: 250,  // Increased width to show full logo
                          decoration: const BoxDecoration(
                            shape: BoxShape.rectangle,
                            image: DecorationImage(
                              image: AssetImage('assets/logo.png'),
                              fit: BoxFit.contain, // Changed to contain to avoid cutting
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'A hiring and seeking platform for the future of work',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Where Talents Meet Opportunity',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Select Your Role for Login and Signup',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.business),
                          label: const Text("I'm a Recruiter"),
                          onPressed: () {
                            setState(() {
                              _selectedRole = 'recruiter';
                              _currentState = ScreenState.login;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.person),
                          label: const Text("I'm a Seeker"),
                          onPressed: () {
                            setState(() {
                              _selectedRole = 'seeker';
                              _currentState = ScreenState.login;
                            });
                          },
                        ),
                      ],
                    ),
                  )
                : _currentState == ScreenState.login
                    ? Column(
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
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text("Phone"),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text("Email"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_method == LoginMethod.phone) ...[
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(labelText: "10-digit Mobile Number"),
                            ),
                            if (_otpSent)
                              TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(labelText: "Enter OTP"),
                              ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _isLoading ? null : (_otpSent ? _verifyOTP : _sendOTP),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(_otpSent ? "Verify OTP" : "Send OTP"),
                            ),
                            if (_otpSent)
                              TextButton(
                                onPressed: _isLoading ? null : _sendOTP,
                                child: const Text("Resend OTP"),
                              ),
                          ] else ...[
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: "Email"),
                            ),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(labelText: "Password"),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _signInWithEmail,
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("Login with Email"),
                            ),
                          ],
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _currentState = _selectedRole == 'seeker'
                                    ? ScreenState.seekerSignup
                                    : ScreenState.recruiterSignup;
                              });
                            },
                            child: Text(
                              "New here? Register",
                              style: TextStyle(fontSize: 20), // Increased text size
                            ),
                          ),
                        ],
                      )
                    : _currentState == ScreenState.seekerSignup || _currentState == ScreenState.recruiterSignup
                        ? Form(
                            key: _formKey,
                            child: ListView(
                              children: [
                                _buildTextField('Mobile Number',
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone),
                                _buildTextField('Email Id',
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress),
                                _buildTextField('Password',
                                    controller: _passwordController, isPassword: true),
                                if (_currentState == ScreenState.recruiterSignup)
                                  _buildTextField('Company Name'),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _submitSignup,
                                  child: const Text('Submit'),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
      ),
    );
  }
}

enum LoginMethod { phone, email }
enum ScreenState { roleSelection, login, seekerSignup, recruiterSignup }