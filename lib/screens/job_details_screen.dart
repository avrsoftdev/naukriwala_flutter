import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as dev; // Added for logging
import 'apply_job_screen.dart'; // Import the apply job screen
import 'edit_job_screen.dart'; // Already imported

class JobDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const JobDetailsScreen({super.key, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  Stream<QuerySnapshot>? _applicantsStream;
  Stream<QuerySnapshot>? _notificationsStream;

  @override
  void initState() {
    super.initState();
    _fetchApplicants(); // Start fetching applicants for recruiters
    _fetchNotifications(); // Start fetching notifications
  }

  Future<void> _fetchApplicants() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != widget.job['recruiterId']?.toString()) return;
    setState(() {
      _applicantsStream = FirebaseFirestore.instance
          .collection('Applications')
          .doc(widget.job['jobId']?.toString())
          .collection('AppliedJobs')
          .snapshots();
    });
  }

  Future<void> _fetchNotifications() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    setState(() {
      _notificationsStream = FirebaseFirestore.instance
          .collection('Notifications')
          .where('to', isEqualTo: currentUser.uid)
          .snapshots();
    });
  }

  void _applyForJob() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to apply')),
        );
      }
      return;
    }
    if (currentUser.uid == widget.job['recruiterId']?.toString()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recruiters cannot apply to their own jobs')),
        );
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyJobScreen(
          jobId: widget.job['jobId']?.toString() ?? '',
          jobTitle: widget.job['title']?.toString() ?? 'Unknown Job',
          recruiterId: widget.job['recruiterId']?.toString() ?? '',
        ),
      ),
    );
  }

  Future<void> deleteJob() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != widget.job['recruiterId']?.toString()) return;

    try {
      await FirebaseFirestore.instance
          .collection('Recruiters')
          .doc(user.uid)
          .collection('Jobs')
          .doc(widget.job['jobId']?.toString())
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job deleted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete job: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    dev.log('Job data in JobDetailsScreen: ${widget.job}', name: 'JobDetailsScreen');

    final jobTitle = widget.job['title']?.toString() ?? 'Job Details';
    final company = widget.job['company']?.toString() ?? 'Unknown Company';
    final location = widget.job['location']?.toString() ?? 'Unknown Location';
    final jobType = widget.job['jobType']?.toString() ?? 'Unknown Type';
    final salary = widget.job['salary']?.toString() ?? 'Not specified';
    final experience = widget.job['experience']?.toString() ?? 'N/A';
    final description = widget.job['description']?.toString() ?? 'No description provided';
    final currentUser = FirebaseAuth.instance.currentUser;
    final isRecruiter = currentUser != null && currentUser.uid == widget.job['recruiterId']?.toString();

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
            const SizedBox(height: 20),
            if (!isRecruiter && currentUser != null)
              ElevatedButton.icon(
                onPressed: _applyForJob,
                icon: const Icon(Icons.send),
                label: const Text('Apply Now'),
              ),
            if (isRecruiter)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditJobScreen(
                            jobId: widget.job['jobId']?.toString() ?? '',
                            jobData: widget.job,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                  ElevatedButton.icon(
                    onPressed: deleteJob,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            if (isRecruiter && _applicantsStream != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Applicants',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: _applicantsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text('No applicants yet.');
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final applicant = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            title: Text(applicant['jobTitle'] ?? 'Unknown Job'),
                            subtitle: Text('Seeker ID: ${applicant['seekerId'] ?? 'Unknown'}'),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            if (_notificationsStream != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: _notificationsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text('No notifications yet.');
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final notification = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            title: Text(notification['message'] ?? 'Unknown Message'),
                            subtitle: Text('Time: ${notification['timestamp']?.toDate().toString() ?? 'N/A'}'),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}