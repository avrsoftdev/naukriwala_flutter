import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:naukariwala/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final bool isRecruiter;

  const ProfileScreen({super.key, required this.isRecruiter});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Controllers for Recruiter fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _companyProfileController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();

  // Controllers for Seeker fields
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();
  final TextEditingController _currentCompanyController = TextEditingController();
  final TextEditingController _currentCtcController = TextEditingController();
  final TextEditingController _expectedCtcController = TextEditingController();

  File? _imageFile;
  String? _imageUrl;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => errorMessage = 'No user logged in');
      return;
    }

    try {
      setState(() => isLoading = true);
      final doc = await _firestore
          .collection(widget.isRecruiter ? 'Recruiters' : 'Seekers')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _mobileController.text = data['mobileNumber'] ?? '';
        _emailController.text = user.email ?? '';
        _imageUrl = data[widget.isRecruiter ? 'companyLogo' : 'photoUrl'];
        if (widget.isRecruiter) {
          _companyNameController.text = data['companyName'] ?? '';
          _companyProfileController.text = data['companyProfile'] ?? '';
          _designationController.text = data['designation'] ?? '';
        } else {
          _experienceController.text = data['experience'] ?? '';
          _educationController.text = data['education'] ?? '';
          _specializationController.text = data['specialization'] ?? '';
          _currentCompanyController.text = data['currentCompany'] ?? '';
          _currentCtcController.text = data['currentCtc'] ?? '';
          _expectedCtcController.text = data['expectedCtc'] ?? '';
        }
      } else if (mounted) {
        setState(() => errorMessage = 'Profile not found');
      }
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = 'Error loading profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _imageUrl;
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final ref = _storage
          .ref()
          .child(widget.isRecruiter ? 'company_logos' : 'seeker_photos')
          .child(user.uid)
          .child(widget.isRecruiter ? 'logo.png' : 'photo.png');
      await ref.putFile(_imageFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = 'Error uploading image: $e');
      }
      return null;
    }
  }

  Future<void> _updateProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => errorMessage = 'No user logged in');
      return;
    }

    try {
      setState(() => isLoading = true);
      final imageUrl = await _uploadImage();
      final profileData = {
        'name': _nameController.text.trim(),
        'mobileNumber': _mobileController.text.trim(),
        'email': _emailController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (imageUrl != null) (widget.isRecruiter ? 'companyLogo' : 'photoUrl'): imageUrl,
        if (widget.isRecruiter) ...{
          'companyName': _companyNameController.text.trim(),
          'companyProfile': _companyProfileController.text.trim(),
          'designation': _designationController.text.trim(),
        } else ...{
          'experience': _experienceController.text.trim(),
          'education': _educationController.text.trim(),
          'specialization': _specializationController.text.trim(),
          'currentCompany': _currentCompanyController.text.trim(),
          'currentCtc': _currentCtcController.text.trim(),
          'expectedCtc': _expectedCtcController.text.trim(),
        },
      };

      await _firestore
          .collection(widget.isRecruiter ? 'Recruiters' : 'Seekers')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        setState(() => errorMessage = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = 'Error updating profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  Widget _buildTextField(String label, {bool isPassword = false, bool multiline = false, TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        maxLines: multiline ? 4 : 1,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _companyProfileController.dispose();
    _designationController.dispose();
    _experienceController.dispose();
    _educationController.dispose();
    _specializationController.dispose();
    _currentCompanyController.dispose();
    _currentCtcController.dispose();
    _expectedCtcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isRecruiter ? 'Recruiter Profile' : 'Seeker Profile'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Display and Upload
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundImage: _imageFile != null
                                  ? FileImage(_imageFile!)
                                  : _imageUrl != null
                                      ? NetworkImage(_imageUrl!)
                                      : null,
                              child: _imageFile == null && _imageUrl == null
                                  ? const Icon(Icons.person, size: 60)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt),
                                onPressed: _pickImage,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.isRecruiter ? 'Company Logo' : 'Profile Photo',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // Common Fields
                      _buildTextField('Name', controller: _nameController),
                      _buildTextField('Mobile Number', controller: _mobileController),
                      _buildTextField('Email Id', controller: _emailController),
                      // Recruiter-Specific Fields
                      if (widget.isRecruiter) ...[
                        _buildTextField('Company Name', controller: _companyNameController),
                        _buildTextField('Company Profile', multiline: true, controller: _companyProfileController),
                        _buildTextField('Designation', controller: _designationController),
                      ]
                      // Seeker-Specific Fields
                      else ...[
                        _buildTextField('Experience', controller: _experienceController),
                        _buildTextField('Education', controller: _educationController),
                        _buildTextField('Specialization', controller: _specializationController),
                        _buildTextField('Current Company', controller: _currentCompanyController),
                        _buildTextField('Current CTC', controller: _currentCtcController),
                        _buildTextField('Expected CTC', controller: _expectedCtcController),
                      ],
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: _updateProfile,
                          child: const Text('Update Profile'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: _logout,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Logout', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}