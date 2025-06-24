import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'package:naukariwala/screens/seeker_dashboard.dart';

class SeekerSignupScreen extends StatefulWidget {
  @override
  _SeekerSignupScreenState createState() => _SeekerSignupScreenState();
}

class _SeekerSignupScreenState extends State<SeekerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _formData = {};

  final _mobileController = TextEditingController(text: "+91");
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _showSnack("Please complete all required fields.");
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user?.uid;
      if (uid == null) throw Exception("Failed to register user.");

      await AuthService().storeSignupData(
        isRecruiter: false,
        data: {
          'Mobile Number': _mobileController.text.trim(),
          'Email Id': _emailController.text.trim(),
          'UID': uid,
        },
      );

      _showSnack('Signup successful!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SeekerDashboard(
            seekerName: _formData['Name'],
            photoUrl: null,
          ),
        ),
      );
    } catch (e) {
      _showSnack('Error: ${e.toString()}');
      debugPrint('[SeekerSignupScreen ERROR] $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(String label,
      {TextEditingController? controller,
      bool isPassword = false,
      TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType ?? TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          final trimmed = value?.trim() ?? '';
          if (trimmed.isEmpty) return 'This field is required';
          if (label == 'Mobile Number' &&
              !RegExp(r'^\+91\d{10}$').hasMatch(trimmed)) {
            return 'Must be in format: +911234567890';
          }
          if (label == 'Email Id' && !trimmed.contains('@')) {
            return 'Invalid email format';
          }
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
      appBar: AppBar(title: Text('Seeker Signup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildTextField('Mobile Number',
                        controller: _mobileController,
                        keyboardType: TextInputType.phone),
                    _buildTextField('Email Id',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress),
                    _buildTextField('Password',
                        controller: _passwordController, isPassword: true),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submit,
                      child: Text('Submit'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}