import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as dev; // Added for logging

class EditJobScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobData;

  const EditJobScreen({
    super.key, // Converted to super parameter
    required this.jobId,
    required this.jobData,
  });

  @override
  State<EditJobScreen> createState() => _EditJobScreenState();
}

class _EditJobScreenState extends State<EditJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> updatedJobData = {};

  @override
  void initState() {
    super.initState();
    // Pre-fill data and validate recruiterId
    final recruiterId = widget.jobData['recruiterId']?.toString();
    if (recruiterId == null) {
      dev.log('Missing recruiterId in jobData', name: 'EditJobScreen');
      return; // Prevent further initialization if recruiterId is missing
    }
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId != recruiterId) {
      dev.log('Unauthorized access attempt by $currentUserId for jobId ${widget.jobId}',
          name: 'EditJobScreen');
    }
    widget.jobData.forEach((key, value) {
      if (value is String) {
        updatedJobData[key] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final recruiterId = widget.jobData['recruiterId']?.toString();
    if (currentUserId == null || recruiterId == null || currentUserId != recruiterId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Job')),
        body: const Center(
          child: Text('You are not authorized to edit this job.'),
        ),
      );
    }

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
          .collection('Recruiters')
          .doc(uid)
          .collection('Jobs')
          .doc(widget.jobId)
          .update(updatedJobData);

      if (!mounted) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job updated successfully!')),
        );
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      dev.log('Failed to update job: $e', name: 'EditJobScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update job: $e')),
        );
      }
    }
  }
}