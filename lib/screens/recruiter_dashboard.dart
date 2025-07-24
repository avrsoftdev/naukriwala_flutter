import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:naukariwala/screens/profile_screen.dart';
import 'package:naukariwala/screens/posted_jobs_screen.dart';
import 'package:naukariwala/screens/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as dev;
import 'post_job_screen.dart';
import '../../services/auth_service.dart';

class RecruiterDashboard extends StatefulWidget {
  const RecruiterDashboard({super.key});

  @override
  State<RecruiterDashboard> createState() => _RecruiterDashboardState();
}

class _RecruiterDashboardState extends State<RecruiterDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final String? recruiterId = FirebaseAuth.instance.currentUser?.uid;
  final AuthService _authService = AuthService();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (recruiterId == null) {
      dev.log('No authenticated user found', name: 'RecruiterDashboard');
    } else {
      dev.log('Recruiter ID: $recruiterId', name: 'RecruiterDashboard');
    }
    _requestNotificationPermissions();
    _checkRole();
  }

  void _requestNotificationPermissions() async {
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token != null && recruiterId != null) {
      await _firestore.collection('UsersIndex').doc(recruiterId).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
      dev.log('FCM token updated for $recruiterId: $token', name: 'RecruiterDashboard');
    } else {
      dev.log('Failed to retrieve FCM token for $recruiterId', name: 'RecruiterDashboard');
    }
  }

  Future<void> _checkRole() async {
    try {
      final role = await _authService.getUserRole();
      dev.log('Role for UID ${FirebaseAuth.instance.currentUser!.uid}: $role', name: 'RecruiterDashboard');
      if (role != 'recruiter') {
        dev.log('WARNING: User ${FirebaseAuth.instance.currentUser!.uid} does not have recruiter role', name: 'RecruiterDashboard');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid role. Please ensure your account is set as a recruiter.')),
          );
        }
      }
    } catch (e) {
      dev.log('Error checking role: $e', name: 'RecruiterDashboard', error: e);
    }
  }

  Future<void> _sendNotification(String seekerId, String message, String jobId, String jobTitle) async {
    final notificationId = _firestore.collection('SeekerNotifications').doc(seekerId).collection('Notifications').doc().id;
    try {
      dev.log('Generated notificationId: $notificationId for seeker $seekerId, job $jobId', name: 'RecruiterDashboard');
      final batch = _firestore.batch();
      final notifRef = _firestore
          .collection('SeekerNotifications')
          .doc(seekerId)
          .collection('Notifications')
          .doc(notificationId);

      batch.set(notifRef, {
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
      await batch.commit();
      dev.log('Notification $notificationId sent to $seekerId for job $jobId: $message', name: 'RecruiterDashboard');

      final tokenSnapshot = await _firestore.collection('UsersIndex').doc(seekerId).get();
      final token = tokenSnapshot.data()?['fcmToken'] as String?;
      if (token != null) {
        dev.log('FCM token found for $seekerId: $token', name: 'RecruiterDashboard');
        // Add FCM logic here if implemented
      } else {
        dev.log('No FCM token found for $seekerId, notification stored in Firestore only', name: 'RecruiterDashboard');
      }
    } catch (e) {
      dev.log('Error sending notification to $seekerId for job $jobId: $e', name: 'RecruiterDashboard', error: e);
      if (e is FirebaseException && e.code == 'permission-denied') {
        dev.log('Permission denied writing to SeekerNotifications/$seekerId/Notifications/$notificationId. Check Firestore rules.', name: 'RecruiterDashboard');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission denied sending notification. Verify Firestore rules.')),
          );
        }
      }
      throw e;
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
    dev.log('Added calendar event: $title on ${DateFormat('dd MMM yyyy').format(date)}', name: 'RecruiterDashboard');
  }

  Future<void> _handleAction(String action, String jobId, String seekerId, Map<String, dynamic>? data) async {
    if (data == null || jobId == 'Unknown' || seekerId == 'Unknown') {
      dev.log('Invalid data for action $action: jobId=$jobId, seekerId=$seekerId, data=$data', name: 'RecruiterDashboard');
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
      dev.log('Handling action: $action for seeker $seekerId, job $jobId', name: 'RecruiterDashboard');
      switch (action) {
        case 'shortlist':
          dev.log('Attempting to shortlist seeker $seekerId for job $jobId', name: 'RecruiterDashboard');
          // Verify application exists
          final applicationDoc = await _firestore.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId).get();
          if (!applicationDoc.exists) {
            dev.log('Application not found for job $jobId, seeker $seekerId', name: 'RecruiterDashboard');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Application not found')),
              );
            }
            return;
          }
          // Verify job ownership
          final jobDoc = await _firestore.collection('Recruiters').doc(recruiterId).collection('Jobs').doc(jobId).get();
          if (!jobDoc.exists || jobDoc.data()?['recruiterId'] != recruiterId) {
            dev.log('Job $jobId not found or does not belong to recruiter $recruiterId', name: 'RecruiterDashboard');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cannot shortlist: Job not found or unauthorized')),
              );
            }
            return;
          }
          final batch = _firestore.batch();
          final shortlistRef = _firestore.collection('Shortlisted').doc(jobId).collection('Seekers').doc(seekerId);
          final applicationRef = _firestore.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId);
          batch.set(shortlistRef, {'timestamp': FieldValue.serverTimestamp()});
          batch.update(applicationRef, {'status': 'Shortlisted'});
          await batch.commit();
          await _sendNotification(seekerId, 'You have been shortlisted for the job "$jobTitle"!', jobId, jobTitle);
          dev.log('Successfully shortlisted seeker $seekerId for job $jobId', name: 'RecruiterDashboard');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Applicant shortlisted successfully')),
            );
            setState(() {}); // Refresh UI
          }
          break;

        case 'reject':
          dev.log('Attempting to reject seeker $seekerId for job $jobId', name: 'RecruiterDashboard');
          // Verify application exists
          final applicationDocReject = await _firestore.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId).get();
          if (!applicationDocReject.exists) {
            dev.log('Application not found for job $jobId, seeker $seekerId', name: 'RecruiterDashboard');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Application not found')),
              );
            }
            return;
          }
          // Verify job ownership
          final jobDocReject = await _firestore.collection('Recruiters').doc(recruiterId).collection('Jobs').doc(jobId).get();
          if (!jobDocReject.exists || jobDocReject.data()?['recruiterId'] != recruiterId) {
            dev.log('Job $jobId not found or does not belong to recruiter $recruiterId', name: 'RecruiterDashboard');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cannot reject: Job not found or unauthorized')),
              );
            }
            return;
          }
          await _firestore.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId).update({'status': 'Rejected'});
          await _sendNotification(seekerId, 'Your application for "$jobTitle" has been rejected.', jobId, jobTitle);
          dev.log('Successfully rejected seeker $seekerId for job $jobId', name: 'RecruiterDashboard');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Applicant rejected successfully')),
            );
            setState(() {}); // Refresh UI
          }
          break;

        case 'schedule':
          dev.log('Attempting to schedule interview for seeker $seekerId, job $jobId', name: 'RecruiterDashboard');
          _showDatePicker(jobId, seekerId, seeker, jobTitle);
          break;

        case 'download_cv':
          dev.log('Attempting to download CV for seeker $seekerId, job $jobId', name: 'RecruiterDashboard');
          final url = seeker['cvUrl'] as String? ?? '';
          if (url.isNotEmpty && await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url));
            dev.log('Downloaded CV for seeker $seekerId: $url', name: 'RecruiterDashboard');
          } else {
            dev.log('No CV available for seeker $seekerId', name: 'RecruiterDashboard');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No CV available')));
            }
          }
          break;

        case 'chat':
          dev.log('Attempting to navigate to ChatScreen for seeker $seekerId', name: 'RecruiterDashboard');
          if (!mounted) {
            dev.log('Widget not mounted, cannot navigate to ChatScreen', name: 'RecruiterDashboard');
            return;
          }
          // Verify application exists
          final indexDoc = await _firestore.collection('ApplicationsIndex').doc('${recruiterId}_$seekerId').get();
          if (!indexDoc.exists) {
            dev.log('No application found for seeker $seekerId with recruiter $recruiterId', name: 'RecruiterDashboard');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cannot chat: No application found')),
              );
            }
            return;
          }
          try {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(seekerId: seekerId)),
            );
            dev.log('Successfully navigated to ChatScreen for seeker $seekerId', name: 'RecruiterDashboard');
          } catch (e) {
            dev.log('Error navigating to ChatScreen for seeker $seekerId: $e', name: 'RecruiterDashboard', error: e);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to open chat: $e')),
              );
            }
          }
          break;
      }
    } catch (e) {
      dev.log('Error handling action $action for seeker $seekerId, job $jobId: $e', name: 'RecruiterDashboard', error: e);
      if (e is FirebaseException && e.code == 'permission-denied') {
        dev.log('Permission denied for action $action. Check Firestore rules for /Applications, /Shortlisted, and /SeekerNotifications.', name: 'RecruiterDashboard');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission denied. Verify Firestore rules and job ownership.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Action failed: $e')),
          );
        }
      }
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
        dev.log('Scheduling interview for seeker $seekerId on job $jobId at ${DateFormat('dd MMM yyyy').format(pickedDate)}', name: 'RecruiterDashboard');
        final batch = _firestore.batch();
        batch.update(
          _firestore.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId),
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
        dev.log('Successfully scheduled interview for seeker $seekerId on job $jobId', name: 'RecruiterDashboard');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Interview scheduled successfully')),
          );
          setState(() {}); // Refresh UI
        }
      } catch (e) {
        dev.log('Error scheduling interview for seeker $seekerId, job $jobId: $e', name: 'RecruiterDashboard', error: e);
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
      dev.log('Exported applicants to $path', name: 'RecruiterDashboard');
    } catch (e) {
      dev.log('Error exporting to Excel: $e', name: 'RecruiterDashboard', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error exporting applicants. Check logs.')));
      }
    }
  }

  Widget _buildAppliedSeekersTab() {
    return Padding(
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
                    final applicants = await _authService.fetchAppliedSeekers();
                    if (applicants.isEmpty) {
                      dev.log('No applicants to export for recruiter $recruiterId', name: 'RecruiterDashboard');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No applicants available to export.')),
                        );
                      }
                      return;
                    }
                    await _exportToExcel(applicants);
                  } catch (e) {
                    dev.log('Error exporting applicants for recruiter $recruiterId: $e', name: 'RecruiterDashboard', error: e);
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
              future: _authService.fetchAppliedSeekers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  String errorMessage = 'Error loading applied seekers. Please verify Firestore permissions or contact support.';
                  if (error is AuthException) {
                    errorMessage = error.message;
                  } else if (error is FirebaseException) {
                    errorMessage = 'Firebase error: ${error.code} - ${error.message}';
                    if (error.code == 'permission-denied') {
                      errorMessage +=
                          '\nVerify /Applications/{jobId} exists with recruiterId=$recruiterId and /ApplicationsIndex/${recruiterId}_<seekerId> is present.';
                      dev.log('Permission denied in fetchAppliedSeekers. Check /Applications and /ApplicationsIndex for recruiter $recruiterId', name: 'RecruiterDashboard');
                    } else if (error.code == 'failed-precondition') {
                      errorMessage += '\nCreate index at: https://console.firebase.google.com/v1/r/project/naukriwala-455909/firestore/indexes';
                    }
                  }
                  dev.log('Error loading applied seekers for recruiter $recruiterId: $error', name: 'RecruiterDashboard', error: error, stackTrace: snapshot.stackTrace);
                  return Center(child: Text(errorMessage, textAlign: TextAlign.center));
                }
                final applicants = snapshot.data ?? [];

                if (applicants.isEmpty) {
                  dev.log('No applicants found for recruiter $recruiterId. Verify /Applications/{jobId} and /ApplicationsIndex', name: 'RecruiterDashboard');
                  return const Center(
                    child: Text(
                      'No applied seekers found. Ensure /Applications/{jobId} exists with correct recruiterId and /ApplicationsIndex/{recruiterId_seekerId} is present.',
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
                          itemBuilder: (context) => const [
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
    );
  }

  Widget _buildCallsTab() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search by name or date...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collectionGroup('AppliedJobs')
                  .where('recruiterId', isEqualTo: recruiterId)
                  .where('status', isEqualTo: 'Interview Scheduled')
                  .orderBy('interviewDate', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  dev.log('Error loading calls for recruiter $recruiterId: ${snapshot.error}', name: 'RecruiterDashboard');
                  if (snapshot.error.toString().contains('FAILED_PRECONDITION')) {
                    return const Center(
                      child: Text(
                        'Error loading calls: Index required. Create it here: https://console.firebase.google.com/v1/r/project/naukriwala-455909/firestore/indexes',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return Center(child: Text('Error loading calls: ${snapshot.error}. Contact support.'));
                }
                final calls = snapshot.data?.docs ?? [];
                if (calls.isEmpty) {
                  dev.log('No scheduled calls found for recruiter $recruiterId', name: 'RecruiterDashboard');
                  return const Center(child: Text('No scheduled calls found.'));
                }

                final filteredCalls = calls.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['resume']?['name'] ?? data['name'] ?? '').toLowerCase();
                  final date = data['interviewDate'] as Timestamp?;
                  final dateStr = date != null ? DateFormat('dd MMM yyyy').format(date.toDate()).toLowerCase() : '';
                  return name.contains(_searchQuery) || dateStr.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: filteredCalls.length,
                  itemBuilder: (_, index) {
                    final data = filteredCalls[index].data() as Map<String, dynamic>;
                    final seekerId = data['seekerId'] as String? ?? 'Unknown';
                    final jobId = data['jobId'] as String? ?? 'Unknown';
                    final resume = data['resume'] as Map<String, dynamic>? ?? {};
                    final interviewDate = data['interviewDate'] as Timestamp?;
                    final dateStr = interviewDate != null ? DateFormat('dd MMM yyyy, hh:mm a').format(interviewDate.toDate()) : 'N/A';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        title: Text(resume['name'] ?? data['name'] ?? seekerId),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Job: ${data['jobTitle'] ?? jobId}'),
                            Text('Date: $dateStr'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () {
                            if (interviewDate != null) {
                              _addToCalendar('Interview with ${resume['name'] ?? seekerId}', interviewDate.toDate());
                            }
                          },
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
    );
  }

  Widget _buildNotificationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('RecruiterNotifications')
          .doc(recruiterId)
          .collection('Notifications')
          .where('type', isEqualTo: 'application')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          dev.log('Error loading notifications for recruiter $recruiterId: ${snapshot.error}', name: 'RecruiterDashboard');
          if (snapshot.error.toString().contains('FAILED_PRECONDITION')) {
            return const Center(
              child: Text(
                'Error loading notifications: Index required. Create it here: https://console.firebase.google.com/v1/r/project/naukriwala-455909/firestore/indexes',
                textAlign: TextAlign.center,
              ),
            );
          }
          return Center(child: Text('Error loading notifications: ${snapshot.error}. Verify RecruiterNotifications collection permissions.'));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          dev.log('No notifications found for recruiter $recruiterId in RecruiterNotifications/$recruiterId/Notifications', name: 'RecruiterDashboard');
          return const Center(
            child: Text(
              'No notifications found. Ensure /RecruiterNotifications/{recruiterId}/Notifications contains data or verify applyToJob execution.',
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final message = data['message'] ?? 'N/A';
            final timestamp = data['timestamp'] as Timestamp?;
            final read = data['read'] ?? false;
            final jobId = data['jobId'] as String? ?? 'Unknown';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                title: Text(message),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (timestamp != null) Text(_formatTimestamp(timestamp)),
                    Text('Job ID: $jobId'),
                  ],
                ),
                trailing: read
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.circle, color: Colors.grey),
                onTap: () async {
                  try {
                    await _firestore
                        .collection('RecruiterNotifications')
                        .doc(recruiterId)
                        .collection('Notifications')
                        .doc(docs[index].id)
                        .update({'read': true});
                    dev.log('Marked notification ${docs[index].id} as read for recruiter $recruiterId', name: 'RecruiterDashboard');
                  } catch (e) {
                    dev.log('Error marking notification ${docs[index].id} as read: $e', name: 'RecruiterDashboard');
                    if (e is FirebaseException && e.code == 'permission-denied') {
                      dev.log('Permission denied updating RecruiterNotifications/$recruiterId/Notifications/${docs[index].id}', name: 'RecruiterDashboard');
                    }
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final dt = ts.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (recruiterId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to access the dashboard.')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return const SizedBox.shrink();
    }

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.deepPurple,
          title: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Recruiter Dashboard',
              style: TextStyle(color: Colors.white),
            ),
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.person)),
              Tab(icon: Icon(Icons.work)),
              Tab(icon: Icon(Icons.group_add)),
              Tab(icon: Icon(Icons.call)),
              Tab(icon: Icon(Icons.post_add)),
              Tab(icon: Icon(Icons.notifications)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ProfileScreen(isRecruiter: true),
            PostedJobsScreen(),
            _buildAppliedSeekersTab(),
            _buildCallsTab(),
            PostJobScreen(),
            _buildNotificationsTab(),
          ],
        ),
      ),
    );
  }
}