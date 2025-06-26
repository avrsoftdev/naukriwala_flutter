import 'dart:io';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../services/auth_service.dart'; // Assuming AuthService is in a services directory

class ApplyJobScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final String recruiterId;

  const ApplyJobScreen({
    required this.jobId,
    required this.jobTitle,
    required this.recruiterId,
    super.key,
  });

  @override
  ApplyJobScreenState createState() => ApplyJobScreenState(); // Made public
}

class ApplyJobScreenState extends State<ApplyJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _formData = {};
  File? _resumeFile;
  bool _isSubmitting = false;
  final user = FirebaseAuth.instance.currentUser;
  final AuthService _authService = AuthService(); // Instance of AuthService

  @override
  void initState() {
    super.initState();
    FirebaseStorage.instance.useStorageEmulator('10.0.2.2', 9199); // Ensure this matches
  }

  Future<void> _pickResume() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _resumeFile = File(result.files.single.path!);
      });
    }
  }

  Future<String?> _uploadResume(String seekerName) async {
    if (_resumeFile == null) return null;
    try {
      final filename = '${seekerName}_${DateTime.now().millisecondsSinceEpoch}_${path.basename(_resumeFile!.path)}';
      final ref = FirebaseStorage.instance.ref('resumes/$filename');
      await ref.putFile(_resumeFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      dev.log('Upload failed: $e', name: 'ApplyJobScreen');
      rethrow; // Let _submitApplication() handle it too
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSubmitting = true);

    try {
      final resumeUrl = await _uploadResume(_formData['Full Name']!);
      final appData = {
        'jobId': widget.jobId,
        'jobTitle': widget.jobTitle,
        'recruiterId': widget.recruiterId,
        'seekerId': user!.uid,
        ..._formData,
        'resumeUrl': resumeUrl ?? '',
        'appliedAt': Timestamp.now(),
      };

      // Use AuthService to apply and send notification
      await _authService.applyToJob(widget.jobId, appData, _resumeFile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application submitted successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showPreviewDialog() async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Preview Application'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._formData.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${entry.key}: ${entry.value}'),
                    )),
                const SizedBox(height: 10),
                Text(
                    'Resume: ${_resumeFile != null ? path.basename(_resumeFile!.path) : "Not uploaded"}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Edit'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Confirm & Submit'),
              onPressed: () {
                Navigator.pop(context);
                _submitApplication();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(String label, {bool required = true, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (value) => value == null || value.isEmpty ? 'Required field' : null
            : null,
        onSaved: (value) => _formData[label] = value!.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Apply for ${widget.jobTitle}')),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField('Full Name'),
                    _buildTextField('Email'),
                    _buildTextField('Mobile Number'),
                    _buildTextField('Educational Qualifications', maxLines: 2),
                    _buildTextField('Work Experience', maxLines: 2),
                    _buildTextField('Skills', maxLines: 2),
                    _buildTextField('References (Optional)', required: false),
                    _buildTextField(
                        'Government ID Proof (Aadhaar/PAN)', required: false),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: Text(_resumeFile != null
                              ? 'Resume Selected'
                              : 'Upload Resume'),
                          onPressed: _pickResume,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.visibility),
                      label: const Text('Preview & Submit'),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          _showPreviewDialog();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}