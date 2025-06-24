// lib/screens/otp_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:naukariwala/services/auth_service.dart';
import 'package:naukariwala/screens/recruiter_dashboard.dart';
import 'package:naukariwala/screens/seeker_dashboard.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String verificationId;
  final bool isRecruiter;
  final Map<String, dynamic> signupData;
  final String phoneNumber;

  OTPVerificationScreen({
    required this.verificationId,
    required this.isRecruiter,
    required this.signupData,
    required this.phoneNumber,
    Key? key,
  }) : super(key: key);

  @override
  OTPVerificationScreenState createState() => OTPVerificationScreenState();
}

class OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _resending = false;

  void _verifyOTP() async {
    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;

      await AuthService().storeSignupData(
        isRecruiter: widget.isRecruiter,
        data: widget.signupData,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => widget.isRecruiter
              ? RecruiterDashboard()
              : SeekerDashboard(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP verification failed. Please try again.')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _resendOTP() async {
    setState(() => _resending = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OTP resend failed.')),
          );
        }
      },
      codeSent: (verificationId, resendToken) {
        if (mounted) {
          setState(() => _resending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OTP resent successfully.')),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20.0),
          width: double.infinity,
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Enter the OTP sent to ${widget.phoneNumber}",
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'OTP',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _verifyOTP,
                      child: Text('Verify and Continue'),
                    ),
              TextButton(
                onPressed: _resending ? null : _resendOTP,
                child: Text('Resend OTP'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
