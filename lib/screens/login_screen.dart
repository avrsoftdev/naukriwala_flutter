import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:naukariwala/screens/role_selection_screen.dart';
import 'package:naukariwala/screens/recruiter_dashboard.dart';
import 'package:naukariwala/screens/seeker_dashboard.dart';
import 'package:naukariwala/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum LoginMethod { phone, email }

class _LoginScreenState extends State<LoginScreen> {
  LoginMethod _method = LoginMethod.phone;
  final phoneController = TextEditingController();
  final otpController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? _verificationId;
  bool _otpSent = false;
  bool _isLoading = false;

  final auth = FirebaseAuth.instance;
  final authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn();
  }

  void _checkIfLoggedIn() async {
    final user = auth.currentUser;
    if (user != null) _redirectBasedOnRole();
  }

  void _redirectBasedOnRole() async {
    setState(() => _isLoading = true);
    final role = await authService.getUserRole();
    setState(() => _isLoading = false);

    if (role == 'recruiter') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RecruiterDashboard()));
    } else if (role == 'seeker') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SeekerDashboard()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoleSelectionScreen()));
    }
  }

  void _sendOTP() async {
    final raw = phoneController.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(raw)) return _showMessage("Enter valid 10-digit number");

    setState(() => _isLoading = true);
    await auth.verifyPhoneNumber(
      phoneNumber: '+91$raw',
      timeout: Duration(seconds: 60),
      verificationCompleted: (cred) async {
        await auth.signInWithCredential(cred);
        _redirectBasedOnRole();
      },
      verificationFailed: (e) {
        _showMessage("Verification failed: ${e.message}");
        setState(() => _isLoading = false);
      },
      codeSent: (verId, _) {
        setState(() {
          _verificationId = verId;
          _otpSent = true;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (verId) {
        _verificationId = verId;
      },
    );
  }

  void _verifyOTP() async {
    final otp = otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) return _showMessage("Enter valid 6-digit OTP");

    setState(() => _isLoading = true);
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await auth.signInWithCredential(cred);
      _redirectBasedOnRole();
    } catch (e) {
      _showMessage("Invalid OTP. Try again.");
      setState(() => _isLoading = false);
    }
  }

  void _signInWithEmail() async {
    final email = emailController.text.trim();
    final pass = passwordController.text.trim();
    if (email.isEmpty || pass.length < 6) {
      return _showMessage("Enter valid credentials");
    }

    setState(() => _isLoading = true);
    try {
      await auth.signInWithEmailAndPassword(email: email, password: pass);
      _redirectBasedOnRole();
    } catch (e) {
      _showMessage("Login failed: ${e.toString()}");
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login / Signup")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
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
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("Phone")),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("Email")),
              ],
            ),
            const SizedBox(height: 20),
            if (_method == LoginMethod.phone) ...[
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: "10-digit Mobile Number"),
              ),
              if (_otpSent)
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: "Enter OTP"),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : (_otpSent ? _verifyOTP : _sendOTP),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(_otpSent ? "Verify OTP" : "Send OTP"),
              ),
              if (_otpSent)
                TextButton(
                  onPressed: _isLoading ? null : _sendOTP,
                  child: Text("Resend OTP"),
                ),
            ] else ...[
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: "Email"),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: "Password"),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _signInWithEmail,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Login with Email"),
              ),
            ],
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RoleSelectionScreen()),
                );
              },
              child: Text("New here? Register"),
            ),
          ],
        ),
      ),
    );
  }
}