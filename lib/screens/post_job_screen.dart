import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_middleware.dart';
import 'preview_job_screen.dart';

class PostJobScreen extends StatefulWidget {
  final Map<String, dynamic>? editJobData;

  const PostJobScreen({super.key, this.editJobData});

  @override
  PostJobScreenState createState() => PostJobScreenState();
}

class PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> jobData = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.editJobData != null) {
      jobData.addAll(widget.editJobData!
          .map((key, value) => MapEntry(key, value?.toString() ?? '')));
      _mapEditData();
    } else {
      _loadRecruiterLocation();
    }
  }

  void _mapEditData() {
    jobData['title'] = jobData.remove('Job Title') ?? '';
    jobData['company'] = jobData.remove('Company Name') ?? '';
    jobData['location'] = jobData.remove('Location (Remote, On-site, Hybrid)') ?? '';
    jobData['experience'] = jobData.remove('Experience Required') ?? '';
    jobData['salary'] = jobData.remove('Salary Range') ?? '';
    jobData['jobType'] = jobData.remove('Job Type (Full-time, Part-time)') ?? '';
    jobData['description'] = jobData.remove('Job Description') ?? '';
  }

  Future<void> _loadRecruiterLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('Recruiters').doc(uid).get();
    final location = doc.data()?['location'];
    if (location != null && jobData['location'] == null) {
      setState(() {
        jobData['location'] = location;
      });
    }
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (jobData['title'] == null || jobData['title']!.isEmpty) {
      _showSnack('Job Title is required before posting.');
      return;
    }

    try {
      await AuthMiddleware.requireRole('recruiter');
    } catch (e) {
      _showSnack('Unauthorized: recruiter role required.');
      return;
    }

    final confirmed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewJobScreen(jobData: jobData),
      ),
    );

    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final createdAt = FieldValue.serverTimestamp();

    setState(() => isLoading = true);

    try {
      debugPrint('[DEBUG] jobData to be posted: $jobData');
      final jobsRef = FirebaseFirestore.instance
          .collection('Recruiters')
          .doc(uid)
          .collection('Jobs');

      if (widget.editJobData != null && widget.editJobData!['jobId'] != null) {
        final jobId = widget.editJobData!['jobId'];
        await jobsRef.doc(jobId).update({
          'title': jobData['title'],
          'company': jobData['company'],
          'location': jobData['location'],
          'experience': jobData['experience'],
          'salary': jobData['salary'],
          'jobType': jobData['jobType'],
          'description': jobData['description'],
          'updatedAt': createdAt,
        });
        if (!mounted) return;
        _showSnack('Job updated successfully');
      } else {
        final newDoc = jobsRef.doc();
        final jobDataToSet = {
          'jobId': newDoc.id,
          'recruiterId': uid,
          'status': 'open',
          'createdAt': createdAt,
          'title': jobData['title'],
          'company': jobData['company'],
          'location': jobData['location'],
          'experience': jobData['experience'],
          'salary': jobData['salary'],
          'jobType': jobData['jobType'],
          'description': jobData['description'],
        };
        debugPrint('[DEBUG] Writing to ${newDoc.path} with data: $jobDataToSet');
        await newDoc.set(jobDataToSet);
        // Verify the write
        final docSnap = await newDoc.get();
        if (docSnap.exists) {
          debugPrint('[DEBUG] Write verified: ${docSnap.data()}');
        } else {
          debugPrint('[ERROR] Write failed: Document not found after set');
          throw Exception('Write verification failed');
        }
        if (!mounted) return;
        _showSnack('Job posted successfully');
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ Error submitting job: $e');
      if (!mounted) return;
      _showSnack('Failed to submit job: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.editJobData != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Job' : 'Post a Job'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildTextField('title', labelText: 'Job Title'),
                    _buildTextField('company', labelText: 'Company Name'),
                    _buildTextField('location', labelText: 'Location (Remote, On-site, Hybrid)'),
                    _buildTextField('experience', labelText: 'Experience Required', keyboardType: TextInputType.number),
                    _buildTextField('salary', labelText: 'Salary Range'),
                    _buildTextField('jobType', labelText: 'Job Type (Full-time, Part-time)'),
                    _buildTextField('description', labelText: 'Job Description', maxLines: 4),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submitJob,
                      child: Text(isEditMode ? 'Update Job' : 'Preview & Post'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(String key, {required String labelText, int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: jobData[key],
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: (value) => value == null || value.trim().isEmpty ? 'Please enter $labelText' : null,
        onSaved: (value) {
          if (value != null) jobData[key] = value.trim();
        },
      ),
    );
  }
}