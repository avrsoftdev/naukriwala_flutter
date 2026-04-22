import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/services/auth_service.dart';

class TestEmailVerification extends StatefulWidget {
  const TestEmailVerification({Key? key}) : super(key: key);

  @override
  State<TestEmailVerification> createState() => _TestEmailVerificationState();
}

class _TestEmailVerificationState extends State<TestEmailVerification> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String _result = '';

  Future<void> _testCustomEmail() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _authService.sendCustomVerificationEmail(user.email!);
        setState(() {
          _result = 'Custom branded email sent successfully!';
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Email Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testCustomEmail,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Send Custom Verification Email'),
            ),
            const SizedBox(height: 20),
            Text(_result),
          ],
        ),
      ),
    );
  }
}
