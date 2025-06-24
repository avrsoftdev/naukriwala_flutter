import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  File? _photoFile;
  bool _isLoading = false;
  DateTime? _selectedDOB;
  String? _selectedGender;

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _photoFile = File(picked.path));
  }

  Future<void> _pickDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDOB = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _photoFile == null || _selectedDOB == null || _selectedGender == null) {
      _showSnack("Please complete all fields including photo, DOB and gender.");
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
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user?.uid;
      if (uid == null) throw Exception("Failed to register user.");

      final photoUrl = await AuthService().uploadSeekerPhoto(_photoFile!);

      _formData['Photo URL'] = photoUrl;
      _formData['Date of Birth'] = _selectedDOB!.toIso8601String();
      _formData['Gender'] = _selectedGender!;

      await AuthService().storeSignupData(isRecruiter: false, data: _formData);
      print("[SeekerSignupScreen] Data saved to Firestore.");

      _showSnack('Profile created successfully');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SeekerDashboard(
            seekerName: _formData['Name'],
            photoUrl: photoUrl,
          ),
        ),
      );
    } catch (e) {
      _showSnack('Error: ${e.toString()}');
      print("[SeekerSignupScreen ERROR] $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(String label,
      {TextEditingController? controller, bool isPassword = false, bool multiline = false}) {
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

  Widget _buildDOBField() {
    return InkWell(
      onTap: _pickDOB,
      child: InputDecorator(
        decoration: InputDecoration(labelText: 'Date of Birth', border: OutlineInputBorder()),
        child: Text(
          _selectedDOB != null
              ? '${_selectedDOB!.day}-${_selectedDOB!.month}-${_selectedDOB!.year}'
              : 'Select Date',
          style: TextStyle(color: _selectedDOB != null ? Colors.black : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildGenderField() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      decoration: InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
      items: ['Male', 'Female', 'Other'].map((gender) {
        return DropdownMenuItem(value: gender, child: Text(gender));
      }).toList(),
      onChanged: (val) => setState(() => _selectedGender = val),
      validator: (value) => value == null ? 'Please select gender' : null,
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
                    _buildTextField('Name'),
                    _buildTextField('Mobile Number', controller: _mobileController),
                    _buildTextField('Email Id', controller: _emailController),
                    _buildTextField('Password', isPassword: true, controller: _passwordController),
                    _buildTextField('Experience'),
                    _buildTextField('Education'),
                    _buildTextField('Specialization'),
                    _buildTextField('Current Company'),
                    _buildTextField('Current CTC'),
                    _buildTextField('Expected CTC'),
                    SizedBox(height: 10),
                    _buildDOBField(),
                    SizedBox(height: 10),
                    _buildGenderField(),
                    SizedBox(height: 10),
                    _photoFile != null
                        ? Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              image: DecorationImage(
                                image: FileImage(_photoFile!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : Text('No profile photo selected'),
                    TextButton.icon(
                      icon: Icon(Icons.upload),
                      label: Text('Upload Profile Photo'),
                      onPressed: _pickPhoto,
                    ),
                    SizedBox(height: 20),
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