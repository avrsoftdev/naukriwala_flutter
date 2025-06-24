import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class JobDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> job;

  const JobDetailsScreen({Key? key, required this.job}) : super(key: key);

  Future<void> applyForJob(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to apply')),
      );
      return;
    }

    final seekerId = user.uid;
    final jobId = job['jobId']?.toString() ?? '';
    final recruiterId = job['recruiterId']?.toString() ?? '';

    if (jobId.isEmpty || recruiterId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid job details')),
      );
      return;
    }

    try {
      final applicationsRef = FirebaseFirestore.instance
          .collection('Applications')
          .doc(seekerId)
          .collection('AppliedJobs')
          .doc(jobId);

      final alreadyApplied = await applicationsRef.get();
      if (alreadyApplied.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already applied for this job')),
        );
        return;
      }

      await applicationsRef.set({
        'jobId': jobId,
        'seekerId': seekerId,
        'recruiterId': recruiterId,
        'appliedAt': FieldValue.serverTimestamp(),
        'jobTitle': job['Job Title']?.toString() ?? 'Unknown',
        'company': job['Company Name']?.toString() ?? 'Unknown',
        'location': job['Location (Remote, On-site, Hybrid)']?.toString() ?? 'Unknown',
        'status': 'Pending',
      });

      final notifRef = FirebaseFirestore.instance
          .collection('RecruiterNotifications')
          .doc(recruiterId)
          .collection('Notifications')
          .doc();

      await notifRef.set({
        'seekerId': seekerId,
        'jobId': jobId,
        'jobTitle': job['Job Title']?.toString() ?? 'Unknown',
        'message': 'A seeker applied to your job: ${job['Job Title']?.toString() ?? 'Unknown'}',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Applied successfully')),
      );
    } catch (e) {
      debugPrint('❌ Error applying: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to apply')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug log
    print('Job data in JobDetailsScreen: $job');

    final jobTitle = job['Job Title']?.toString() ?? 'Job Details';
    final company = job['Company Name']?.toString() ?? 'Unknown Company';
    final location = job['Location (Remote, On-site, Hybrid)']?.toString() ?? 'Unknown Location';
    final jobType = job['Job Type (Full-time, Part-time)']?.toString() ?? 'Unknown Type';
    final salary = job['Salary Range']?.toString() ?? 'Not specified';
    final experience = job['Experience Required']?.toString() ?? 'N/A';
    final description = job['Job Description']?.toString() ?? 'No description provided';

    return Scaffold(
      appBar: AppBar(title: Text(jobTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              jobTitle,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('$company • $location • $jobType'),
            const SizedBox(height: 10),
            Text('Salary: $salary'),
            Text('Experience Required: $experience'),
            const SizedBox(height: 20),
            const Text(
              'Job Description',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(description),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => applyForJob(context),
              icon: const Icon(Icons.send),
              label: const Text('Apply Now'),
            ),
          ],
        ),
      ),
    );
  }
}