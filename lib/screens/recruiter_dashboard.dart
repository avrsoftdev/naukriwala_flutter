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
    _checkRoleClaim();
  }

  void _requestNotificationPermissions() async {
    await _messaging.requestPermission();
  }

  Future<void> _checkRoleClaim() async {
    final idTokenResult = await FirebaseAuth.instance.currentUser!.getIdTokenResult();
    dev.log('Token claims for UID ${FirebaseAuth.instance.currentUser!.uid}: ${idTokenResult.claims}', name: 'RecruiterDashboard');
  }

  Future<void> _sendNotification(String seekerId, String message) async {
    try {
      final profile = await _authService.fetchProfileData(isRecruiter: false);
      final token = profile?['fcmToken'] as String? ??
          (await _firestore.collection('UsersIndex').doc(seekerId).get())
              .data()?['fcmToken'] as String?;
      if (token != null) {
        final notificationId = _firestore.collection('SeekerNotifications').doc(seekerId).collection('Notifications').doc().id;
        await _firestore
            .collection('SeekerNotifications')
            .doc(seekerId)
            .collection('Notifications')
            .doc(notificationId)
            .set({
              'to': seekerId,
              'from': recruiterId,
              'message': message,
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
              'type': 'application',
              'notificationId': notificationId,
            });
        dev.log('Notification $notificationId sent to $seekerId with message: $message', name: 'RecruiterDashboard');
      } else {
        dev.log('No FCM token found for $seekerId', name: 'RecruiterDashboard');
      }
    } catch (e) {
      dev.log('Error sending notification to $seekerId: $e', name: 'RecruiterDashboard', error: e);
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
  }

  Future<void> _handleAction(String action, String jobId, String seekerId, Map<String, dynamic>? data) async {
    if (data == null) return;
    final resume = data['resume'] as Map<String, dynamic>? ?? {};
    final seeker = {
      ...data,
      'name': resume['name'] ?? data['name'] ?? seekerId,
      'cvUrl': resume['cvUrl'] ?? data['cvUrl'] ?? '',
    };

    switch (action) {
      case 'shortlist':
        await _firestore.collection('Shortlisted').doc(jobId).collection('Seekers').doc(seekerId).set({});
        await _firestore.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId).update({'status': 'Shortlisted'});
        await _sendNotification(seekerId, 'You have been shortlisted for the job!');
        break;
      case 'reject':
        await _firestore.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId).update({'status': 'Rejected'});
        await _sendNotification(seekerId, 'Your application has been rejected.');
        break;
      case 'schedule':
        _showDatePicker(jobId, seekerId, seeker);
        break;
      case 'download_cv':
        final url = seeker['cvUrl'] as String? ?? '';
        if (url.isNotEmpty && await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No CV available')));
          }
        }
        break;
      case 'chat':
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(seekerId: seekerId)));
        break;
    }
  }

  void _showDatePicker(String jobId, String seekerId, Map<String, dynamic> seeker) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      await _firestore.collection('Applications').doc(jobId).collection('AppliedJobs').doc(seekerId).update({
        'status': 'Interview Scheduled',
        'interviewDate': Timestamp.fromDate(pickedDate),
      });
      await _sendNotification(seekerId, 'Interview scheduled on ${DateFormat('dd MMM yyyy').format(pickedDate)}');
      _addToCalendar('Interview with ${seeker['name']}', pickedDate);
    }
  }

  Future<void> _exportToExcel(List<Map<String, dynamic>> applicants) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Applicants'];
    sheet.appendRow(['Name', 'Mobile', 'Specialization', 'Experience', 'Status']);
    for (var a in applicants) {
      sheet.appendRow([a['name'] ?? '', a['mobile'] ?? '', a['specialization'] ?? a['resume']?['specialization'] ?? '', a['experience'] ?? a['resume']?['experience'] ?? '', a['status'] ?? '']);
    }
    final bytes = excel.encode();
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/applicants_export.xlsx';
    final file = File(path);
    await file.writeAsBytes(Uint8List.fromList(bytes!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $path')));
  }

  Widget _buildAppliedSeekersTab() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final applicants = await _authService.fetchAppliedSeekers();
                    await _exportToExcel(applicants);
                  } catch (e) {
                    dev.log('Error exporting applicants for recruiter $recruiterId: $e', name: 'RecruiterDashboard', error: e);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error exporting applicants. Check logs.')));
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
                  String errorMessage = 'Error loading applied seekers. Please check Firestore permissions or contact support.';
                  if (error is AuthException) {
                    errorMessage = error.message;
                  } else if (error is FirebaseException) {
                    errorMessage = 'Firebase error: ${error.code} - ${error.message}';
                    if (error.code == 'FAILED_PRECONDITION') {
                      errorMessage += '\nCreate index at: https://console.firebase.google.com/v1/r/project/naukriwala-455909/firestore/indexes';
                    }
                  }
                  dev.log('Error loading applied seekers for recruiter $recruiterId: $error', name: 'RecruiterDashboard', error: error, stackTrace: snapshot.stackTrace);
                  return Center(child: Text(errorMessage));
                }
                final applicants = snapshot.data ?? [];

                if (applicants.isEmpty) {
                  return const Center(child: Text('No applied seekers found. Check if applications exist in Firestore or if permissions are set correctly.'));
                }

                return ListView.builder(
                  itemCount: applicants.length,
                  itemBuilder: (_, index) {
                    final applicant = applicants[index];
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
                            Text('Specialization: ${resume['specialization'] ?? applicant['specialization'] ?? ''}'),
                            Text('Experience: ${resume['experience'] ?? applicant['experience'] ?? ''}'),
                            Text('Status: ${applicant['status'] ?? ''}'),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) => _handleAction(action, jobId, seekerId, {'resume': resume, ...applicant}),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'shortlist', child: Text('Shortlist')),
                            PopupMenuItem(value: 'reject', child: Text('Reject')),
                            PopupMenuItem(value: 'schedule', child: Text('Schedule Interview')),
                            PopupMenuItem(value: 'download_cv', child: Text('Download CV')),
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
            decoration: InputDecoration(
              labelText: 'Search by name or date...',
              border: OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
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
                  return Center(child: Text('Error loading calls: ${snapshot.error}'));
                }
                final calls = snapshot.data?.docs ?? [];
                if (calls.isEmpty) {
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
          .collection('SeekerNotifications')
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
            return Center(child: Text('Error loading notifications: Index required. Create it here: https://console.firebase.google.com/v1/r/project/naukriwala-455909/firestore/indexes'));
          }
          return Center(child: Text('Error loading notifications: ${snapshot.error}. Contact support.'));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No notifications found. Check SeekerNotifications collection.'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final message = data['message'] ?? 'N/A';
            final timestamp = data['timestamp'] as Timestamp?;
            final read = data['read'] ?? false;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                title: Text(message),
                subtitle: timestamp != null ? Text(_formatTimestamp(timestamp)) : null,
                trailing: read
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.circle, color: Colors.grey),
                onTap: () async {
                  try {
                    await _firestore
                        .collection('SeekerNotifications')
                        .doc(recruiterId)
                        .collection('Notifications')
                        .doc(docs[index].id)
                        .update({'read': true});
                    dev.log('Marked notification ${docs[index].id} as read for recruiter $recruiterId', name: 'RecruiterDashboard');
                  } catch (e) {
                    dev.log('Error marking notification as read: $e', name: 'RecruiterDashboard');
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