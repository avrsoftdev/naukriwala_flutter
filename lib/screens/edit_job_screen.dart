// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as dev;
import 'package:flutter_screenutil/flutter_screenutil.dart';

class EditJobScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobData;

  const EditJobScreen({
    super.key,
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
      return ScreenUtilInit(
        designSize: const Size(360, 690), // Base design size for responsiveness
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Edit Job',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              elevation: 4,
            ),
            body: Center(
              child: Card(
                elevation: 4,
                color: Colors.red.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Text(
                    'You are not authorized to edit this job.',
                    style: TextStyle(fontSize: 16.sp, color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return ScreenUtilInit(
      designSize: const Size(360, 690), // Base design size for responsiveness
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Edit Job',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            elevation: 4,
          ),
          body: Padding(
            padding: EdgeInsets.all(16.w),
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
                  SizedBox(height: 20.h),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(
                      'Save Changes',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        _updateJobInFirestore(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 20.w),
                      minimumSize: Size(double.infinity, 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, {bool required = false, int maxLines = 1}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: TextFormField(
        initialValue: updatedJobData[label] ?? '',
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
        maxLines: maxLines,
        style: TextStyle(fontSize: 14.sp),
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