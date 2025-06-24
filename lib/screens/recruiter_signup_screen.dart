import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'recruiter_dashboard.dart';

class RecruiterSignupScreen extends StatefulWidget {
  @override
  _RecruiterSignupScreenState createState() => _RecruiterSignupScreenState();
}

class _RecruiterSignupScreenState extends State<RecruiterSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _formData = {};
  final _mobileController = TextEditingController(text: "+91");
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  File? _logoFile;
  bool _isLoading = false;

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _logoFile = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _logoFile == null) {
      _showSnack("Please complete all fields and upload a logo.");
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirm Submission'),
        content: Text('Are you sure all details are correct?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Submit')),
        ],
      ),
    );

    if (confirm != true) return;

    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      // Create Firebase user account
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = AuthService().getCurrentUser()?.uid;
      if (uid == null) throw Exception("Could not create account");

      final logoUrl = await AuthService().uploadCompanyLogo(_logoFile!);
      _formData['Mobile Number'] = _mobileController.text.trim();
      _formData['Email Id'] = _emailController.text.trim();
      _formData['Password'] = _passwordController.text.trim();
      _formData['Company Logo'] = logoUrl;

      await AuthService().storeSignupData(isRecruiter: true, data: _formData);

      // Save for indexed access
      await FirebaseFirestore.instance.collection('UsersIndex').doc(uid).set({
        'email': _formData['Email Id'],
        'mobile': _formData['Mobile Number'],
      });

      _showSnack('Profile created successfully');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RecruiterDashboard()),
      );
    } catch (e) {
      _showSnack('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(String label,
      {bool multiline = false, bool isPassword = false, TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: label == 'Mobile Number'
            ? TextInputType.phone
            : label == 'Email Id'
                ? TextInputType.emailAddress
                : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        maxLines: multiline ? 3 : 1,
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'This field is required';
          if (label == 'Mobile Number' && !RegExp(r'^\+91\d{10}$').hasMatch(value.trim())) {
            return 'Use +91 and 10 digits';
          }
          if (label == 'Email Id' && !value.contains('@')) return 'Invalid email format';
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
      appBar: AppBar(title: Text('Recruiter Signup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildTextField('Name'),
                    _buildTextField('Company Name'),
                    _buildTextField('Mobile Number', controller: _mobileController),
                    _buildTextField('Email Id', controller: _emailController),
                    _buildTextField('Password', isPassword: true, controller: _passwordController),
                    _buildTextField('Company Profile', multiline: true),
                    _buildTextField('Designation'),
                    const SizedBox(height: 10),
                    _logoFile != null
                        ? Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              image: DecorationImage(
                                image: FileImage(_logoFile!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : Text('No logo selected'),
                    TextButton.icon(
                      icon: Icon(Icons.upload),
                      label: Text('Upload Company Logo'),
                      onPressed: _pickLogo,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submit,
                      child: Text('Submit'),
                    )
                  ],
                ),
              ),
      ),
    );
  }
}