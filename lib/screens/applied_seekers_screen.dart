import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:naukariwala/screens/chat_screen.dart';
import '../../services/auth_service.dart';
import 'dart:developer' as dev;

class AppliedSeekersScreen extends StatefulWidget {
  final AuthService authService;
  const AppliedSeekersScreen({super.key, required this.authService});

  @override
  State<AppliedSeekersScreen> createState() => _AppliedSeekersScreenState();
}

class _AppliedSeekersScreenState extends State<AppliedSeekersScreen> {
  final String? recruiterId = FirebaseAuth.instance.currentUser?.uid;
  String _searchQuery = '';

  Future<void> _sendNotification(String seekerId, String message, String jobId, String jobTitle) async {
    final notificationId = FirebaseFirestore.instance.collection('SeekerNotifications').doc(seekerId).collection('Notifications').doc().id;
    try {
      dev.log('Generated notificationId: $notificationId for seeker $seekerId, job $jobId', name: 'AppliedSeekersScreen');
      final batch = FirebaseFirestore.instance.batch();

      // Seeker notification
      final seekerNotifRef = FirebaseFirestore.instance
          .collection('SeekerNotifications')
          .doc(seekerId)
          .collection('Notifications')
          .doc(notificationId);
      batch.set(seekerNotifRef, {
        'to': seekerId,
        'from': recruiterId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'application',
        'jobId': jobId,
        'jobTitle': jobTitle,
        'notificationId': notificationId,
      });

      // Recruiter notification
      if (recruiterId != null) {
        final recruiterNotifId = FirebaseFirestore.instance.collection('RecruiterNotifications').doc(recruiterId).collection('Notifications').doc().id;
        final recruiterNotifRef = FirebaseFirestore.instance
            .collection('RecruiterNotifications')
            .doc(recruiterId)
            .collection('Notifications')
            .doc(recruiterNotifId);
        batch.set(recruiterNotifRef, {
          'to': recruiterId,
          'from': seekerId,
          'message': 'Action taken: $message',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'application',
          'jobId': jobId,
          'jobTitle': jobTitle,
          'notificationId': recruiterNotifId,
        });
      }

      await batch.commit();
      dev.log('Notifications sent: Seeker $seekerId ($notificationId), Recruiter $recruiterId for job $jobId', name: 'AppliedSeekersScreen');

      final tokenSnapshot = await FirebaseFirestore.instance.collection('UsersIndex').doc(seekerId).get();
      final token = tokenSnapshot.data()?['fcmToken'] as String?;
      if (token != null) {
        dev.log('FCM token found for $seekerId: $token', name: 'AppliedSeekersScreen');
        // Add FCM logic here if implemented
      } else {
        dev.log('No FCM token found for $seekerId, notification stored in Firestore only', name: 'AppliedSeekersScreen');
      }
    } catch (e) {
      dev.log('Error sending notification to $seekerId for job $jobId: $e', name: 'AppliedSeekersScreen', error: e);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (e is FirebaseException && e.code == 'permission-denied') {
            dev.log('Permission denied writing to SeekerNotifications/$seekerId/Notifications/$notificationId or RecruiterNotifications/$recruiterId/Notifications. Check Firestore rules.', name: 'AppliedSeekersScreen');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permission denied sending notification. Verify Firestore rules.')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to send notification: $e')),
            );
          }
        }
      });
      rethrow;
    }
  }

  void _addToCalendar(String title, DateTime date) {
    final event = Event(
      title: title,
      description: 'Interview scheduled via Naukariwala',
      location: 'Online/To be decided',
      startDate: date,
      endDate: date.add(const Duration(hours: 1)),
    );
    Add2Calendar.addEvent2Cal(event);
    dev.log('Added calendar event: $title on ${DateFormat('dd MMM yyyy').format(date)}', name: 'AppliedSeekersScreen');
  }

  Future<void> _handleAction(String action, String jobId, String seekerId, Map<String, dynamic>? data) async {
    if (data == null || jobId == 'Unknown' || seekerId == 'Unknown') {
      dev.log('Invalid data for action $action: jobId=$jobId, seekerId=$seekerId, data=$data', name: 'AppliedSeekersScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid applicant or job data')),
        );
      }
      return;
    }
    final resume = data['resume'] as Map<String, dynamic>? ?? {};
    final seeker = {
      ...data,
      'name': resume['name'] ?? data['name'] ?? seekerId,
      'cvUrl': resume['cvUrl'] ?? data['cvUrl'] ?? '',
    };
    final jobTitle = data['jobTitle'] as String? ?? 'Unknown';

    try {
      dev.log('Handling action: $action for seeker $seekerId, job $jobId', name: 'AppliedSeekersScreen');
      switch (action) {
        case 'shortlist':
          dev.log('Attempting to shortlist seeker $seekerId for job $jobId', name: 'AppliedSeekersScreen');
          final applicationDoc = await FirebaseFirestore.instance.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId).get();
          if (!applicationDoc.exists) {
            dev.log('Application not found for job $jobId, seeker $seekerId', name: 'AppliedSeekersScreen');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Application not found')),
              );
            }
            return;
          }
          final jobDoc = await FirebaseFirestore.instance.collection('Recruiters').doc(recruiterId).collection('Jobs').doc(jobId).get();
          if (!jobDoc.exists || jobDoc.data()?['recruiterId'] != recruiterId) {
            dev.log('Job $jobId not found or does not belong to recruiter $recruiterId', name: 'AppliedSeekersScreen');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cannot shortlist: Job not found or unauthorized')),
              );
            }
            return;
          }
          final batch = FirebaseFirestore.instance.batch();
          final shortlistRef = FirebaseFirestore.instance.collection('Shortlisted').doc(jobId).collection('Seekers').doc(seekerId);
          final applicationRef = FirebaseFirestore.instance.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId);
          batch.set(shortlistRef, {'timestamp': FieldValue.serverTimestamp()});
          batch.update(applicationRef, {'status': 'Shortlisted'});
          await batch.commit();
          await _sendNotification(seekerId, 'You have been shortlisted for the job "$jobTitle"!', jobId, jobTitle);
          dev.log('Successfully shortlisted seeker $seekerId for job $jobId', name: 'AppliedSeekersScreen');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Applicant shortlisted successfully')),
            );
            setState(() {}); // Refresh UI
          }
          break;

        case 'reject':
          dev.log('Attempting to reject seeker $seekerId for job $jobId', name: 'AppliedSeekersScreen');
          final applicationDocReject = await FirebaseFirestore.instance.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId).get();
          if (!applicationDocReject.exists) {
            dev.log('Application not found for job $jobId, seeker $seekerId', name: 'AppliedSeekersScreen');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Application not found')),
              );
            }
            return;
          }
          final jobDocReject = await FirebaseFirestore.instance.collection('Recruiters').doc(recruiterId).collection('Jobs').doc(jobId).get();
          if (!jobDocReject.exists || jobDocReject.data()?['recruiterId'] != recruiterId) {
            dev.log('Job $jobId not found or does not belong to recruiter $recruiterId', name: 'AppliedSeekersScreen');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cannot reject: Job not found or unauthorized')),
              );
            }
            return;
          }
          await FirebaseFirestore.instance.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId).update({'status': 'Rejected'});
          await _sendNotification(seekerId, 'Your application for "$jobTitle" has been rejected.', jobId, jobTitle);
          dev.log('Successfully rejected seeker $seekerId for job $jobId', name: 'AppliedSeekersScreen');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Applicant rejected successfully')),
            );
            setState(() {}); // Refresh UI
          }
          break;

        case 'schedule':
          dev.log('Attempting to schedule interview for seeker $seekerId, job $jobId', name: 'AppliedSeekersScreen');
          _showDatePicker(jobId, seekerId, seeker, jobTitle);
          break;

        case 'download_cv':
          dev.log('Attempting to download CV for seeker $seekerId, job $jobId', name: 'AppliedSeekersScreen');
          final url = seeker['cvUrl'] as String? ?? '';
          if (url.isNotEmpty && await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url));
            dev.log('Downloaded CV for seeker $seekerId: $url', name: 'AppliedSeekersScreen');
          } else {
            dev.log('No CV available for seeker $seekerId', name: 'AppliedSeekersScreen');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No CV available')));
            }
          }
          break;

        case 'chat':
          dev.log('Attempting to navigate to ChatScreen for seeker $seekerId', name: 'AppliedSeekersScreen');
          if (!mounted) {
            dev.log('Widget not mounted, cannot navigate to ChatScreen', name: 'AppliedSeekersScreen');
            return;
          }
          final chatId = [recruiterId!, seekerId].join('_').split('_')..sort();
          final normalizedChatId = '${chatId[0]}_${chatId[1]}';
          try {
            await widget.authService.sendMessage(seekerId, jobId, 'Hello, let’s discuss your application!');
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(chatId: normalizedChatId, recipientId: seekerId, jobId: jobId),
                ),
              );
              dev.log('Successfully navigated to ChatScreen for seeker $seekerId', name: 'AppliedSeekersScreen');
            }
          } catch (e) {
            dev.log('Error navigating to ChatScreen for seeker $seekerId: $e', name: 'AppliedSeekersScreen', error: e);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to open chat: $e')),
              );
            }
          }
          break;
      }
    } catch (e) {
      dev.log('Error handling action $action for seeker $seekerId, job $jobId: $e', name: 'AppliedSeekersScreen', error: e);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (e is FirebaseException && e.code == 'permission-denied') {
            dev.log('Permission denied for action $action. Check Firestore rules for /Applications, /Shortlisted, and /SeekerNotifications.', name: 'AppliedSeekersScreen');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permission denied. Verify job ownership or application data.')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Action failed: $e')),
            );
          }
        }
      });
    }
  }

  void _showDatePicker(String jobId, String seekerId, Map<String, dynamic> seeker, String jobTitle) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null && mounted) {
      try {
        dev.log('Scheduling interview for seeker $seekerId on job $jobId at ${DateFormat('dd MMM yyyy').format(pickedDate)}', name: 'AppliedSeekersScreen');
        final batch = FirebaseFirestore.instance.batch();
        batch.update(
          FirebaseFirestore.instance.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId),
          {
            'status': 'Interview Scheduled',
            'interviewDate': Timestamp.fromDate(pickedDate),
          },
        );
        await batch.commit();
        await _sendNotification(
          seekerId,
          'Interview for "$jobTitle" scheduled on ${DateFormat('dd MMM yyyy').format(pickedDate)}',
          jobId,
          jobTitle,
        );
        _addToCalendar('Interview with ${seeker['name']}', pickedDate);
        dev.log('Successfully scheduled interview for seeker $seekerId on job $jobId', name: 'AppliedSeekersScreen');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Interview scheduled successfully')),
          );
          setState(() {}); // Refresh UI
        }
      } catch (e) {
        dev.log('Error scheduling interview for seeker $seekerId, job $jobId: $e', name: 'AppliedSeekersScreen', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to schedule interview: $e')),
          );
        }
      }
    }
  }

  Future<void> _exportToExcel(List<Map<String, dynamic>> applicants) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Applicants'];
      sheet.appendRow(['Name', 'Mobile', 'Specialization', 'Experience', 'Status', 'Job Title']);
      for (var a in applicants) {
        sheet.appendRow([
          a['name'] ?? '',
          a['mobile'] ?? a['resume']?['mobileNumber'] ?? '',
          a['specialization'] ?? a['resume']?['specialization'] ?? '',
          a['experience'] ?? a['resume']?['experience'] ?? '',
          a['status'] ?? '',
          a['jobTitle'] ?? '',
        ]);
      }
      final bytes = excel.encode();
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/applicants_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(path);
      await file.writeAsBytes(Uint8List.fromList(bytes!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $path')));
      dev.log('Exported applicants to $path', name: 'AppliedSeekersScreen');
    } catch (e) {
      dev.log('Error exporting to Excel: $e', name: 'AppliedSeekersScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error exporting applicants. Check logs.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search applicants...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final applicants = await widget.authService.fetchAppliedSeekers();
                      if (applicants.isEmpty) {
                        dev.log('No applicants to export for recruiter $recruiterId', name: 'AppliedSeekersScreen');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No applicants available to export.')),
                          );
                        }
                        return;
                      }
                      await _exportToExcel(applicants);
                    } catch (e) {
                      dev.log('Error exporting applicants for recruiter $recruiterId: $e', name: 'AppliedSeekersScreen', error: e);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error exporting applicants. Check logs.')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: widget.authService.fetchAppliedSeekers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    String errorMessage = 'Error loading applied seekers. Please verify Firestore permissions or contact support.';
                    if (error is FirebaseException) {
                      errorMessage = 'Firebase error: ${error.code} - ${error.message}';
                      if (error.code == 'permission-denied') {
                        errorMessage +=
                            '\nEnsure /Applications/{jobId} exists with recruiterId=$recruiterId and job exists in /Recruiters/$recruiterId/Jobs/{jobId}.';
                        dev.log('Permission denied in fetchAppliedSeekers. Check /Applications/{jobId} and /Recruiters/$recruiterId/Jobs for recruiter $recruiterId', name: 'AppliedSeekersScreen');
                      }
                    }
                    dev.log('Error loading applied seekers for recruiter $recruiterId: $error', name: 'AppliedSeekersScreen', error: error, stackTrace: snapshot.stackTrace);
                    return Center(child: Text(errorMessage, textAlign: TextAlign.center));
                  }
                  final applicants = snapshot.data ?? [];

                  if (applicants.isEmpty) {
                    dev.log('No applicants found for recruiter $recruiterId. Verify /Applications/{jobId} exists with correct recruiterId.', name: 'AppliedSeekersScreen');
                    return const Center(
                      child: Text(
                        'No applied seekers found. Ensure /Applications/{jobId} exists with correct recruiterId and jobs are posted in /Recruiters/{recruiterId}/Jobs.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final filteredApplicants = applicants.where((applicant) {
                    final name = (applicant['resume']?['name'] ?? applicant['name'] ?? '').toLowerCase();
                    final jobTitle = (applicant['jobTitle'] ?? '').toLowerCase();
                    return name.contains(_searchQuery) || jobTitle.contains(_searchQuery);
                  }).toList();

                  return ListView.builder(
                    itemCount: filteredApplicants.length,
                    itemBuilder: (_, index) {
                      final applicant = filteredApplicants[index];
                      final seekerId = applicant['seekerId'] as String? ?? 'Unknown';
                      final jobId = applicant['jobId'] as String? ?? 'Unknown';
                      final resume = applicant['resume'] as Map<String, dynamic>? ?? {};

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          title: Text(resume['name'] ?? applicant['name'] ?? seekerId),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Job: ${applicant['jobTitle'] ?? jobId}'),
                              Text('Name: ${resume['name'] ?? 'N/A'}'),
                              Text('Email: ${resume['email'] ?? 'N/A'}'),
                              Text('Skills: ${(resume['skills'] as List<dynamic>?)?.join(', ') ?? 'N/A'}'),
                              Text('Specialization: ${resume['specialization'] ?? applicant['specialization'] ?? 'N/A'}'),
                              Text('Experience: ${resume['experience'] ?? applicant['experience'] ?? 'N/A'}'),
                              Text('Status: ${applicant['status'] ?? 'N/A'}'),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) => _handleAction(action, jobId, seekerId, {'resume': resume, ...applicant}),
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'shortlist', child: Text('Shortlist')),
                              PopupMenuItem(value: 'reject', child: Text('Reject')),
                              PopupMenuItem(value: 'schedule', child: Text('Schedule Interview')),
                              PopupMenuItem(value: 'chat', child: Text('Chat')),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}