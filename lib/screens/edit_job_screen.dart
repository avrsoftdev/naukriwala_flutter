import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditJobScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobData;

  const EditJobScreen({
    Key? key,
    required this.jobId,
    required this.jobData,
  }) : super(key: key);

  @override
  State<EditJobScreen> createState() => _EditJobScreenState();
}

class _EditJobScreenState extends State<EditJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> updatedJobData = {};

  @override
  void initState() {
    super.initState();
    // Pre-fill data
    widget.jobData.forEach((key, value) {
      if (value is String) {
        updatedJobData[key] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Job')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField('Job Title', required: true),
              _buildTextField('Company Name', required: true),
              _buildTextField('Location (Remote, On-site, Hybrid)', required: true),
              _buildTextField('Employment Type', required: true),
              _buildTextField('Job Summary', maxLines: 3),
              _buildTextField('Key Responsibilities (comma-separated)', maxLines: 4),
              _buildTextField('Required Qualifications', maxLines: 3),
              _buildTextField('Preferred Qualifications', maxLines: 3),
              _buildTextField('Salary Range'),
              _buildTextField('Benefits & Perks', maxLines: 2),
              _buildTextField('Application Instructions', maxLines: 2),
              _buildTextField('Application Deadline'),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    _updateJobInFirestore(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, {bool required = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: updatedJobData[label] ?? '',
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        maxLines: maxLines,
        validator: required
            ? (value) => value == null || value.trim().isEmpty ? 'Required field' : null
            : null,
        onSaved: (value) => updatedJobData[label] = value ?? '',
      ),
    );
  }

  Future<void> _updateJobInFirestore(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('PostedJobs')
          .doc(uid)
          .collection('Jobs')
          .doc(widget.jobId)
          .update(updatedJobData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job updated successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update job: $e')),
      );
    }
  }
}
