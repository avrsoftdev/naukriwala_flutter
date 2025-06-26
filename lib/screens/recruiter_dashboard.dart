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
import 'post_job_screen.dart';
import 'notifications_screen.dart';

class RecruiterDashboard extends StatefulWidget {
  const RecruiterDashboard({super.key});

  @override
  State<RecruiterDashboard> createState() => _RecruiterDashboardState();
}

class _RecruiterDashboardState extends State<RecruiterDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String _selectedFilter = 'All';
  String _searchQuery = '';
  String _experienceFilter = 'All';

  @override
  void initState() {
    super.initState();
    _requestNotificationPermissions();
  }

  void _requestNotificationPermissions() async {
    await _messaging.requestPermission();
  }

  Future<void> _sendNotification(String seekerId, String message) async {
    final tokenSnapshot = await _firestore.collection('Seekers').doc(seekerId).get();
    final token = tokenSnapshot['fcmToken'];

    if (token != null) {
      await FirebaseFirestore.instance.collection('Notifications').add({
        'to': token,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  void _addToCalendar(String title, DateTime date) {
    final event = Event(
      title: title,
      description: 'Interview scheduled via Naukariwala',
      location: 'Online/To be decided',
      startDate: date,
      endDate: date.add(Duration(hours: 1)),
    );
    Add2Calendar.addEvent2Cal(event);
  }

  Future<void> _handleAction(String action, String jobId, String seekerId, Map<String, dynamic> seeker) async {
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
        final url = seeker['cvUrl'];
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
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
      initialDate: DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
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
      sheet.appendRow([a['name'], a['mobile'], a['specialization'], a['experience'], a['status']]);
    }
    final bytes = excel.encode();
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/applicants_export.xlsx';
    final file = File(path);
    await file.writeAsBytes(Uint8List.fromList(bytes!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $path')));
  }

  @override
  Widget build(BuildContext context) {
    // Dummy notifications list for example, replace with actual data
    final List<Map<String, String>> dummyNotifications = [
      {
        'title': 'Application Received',
        'seekerName': 'John Doe',
        'jobTitle': 'Flutter Developer',
      },
    ];

    return DefaultTabController(
      length: 6, // Matches the number of tabs
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
            unselectedLabelColor: Colors.white,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.person)),
              Tab(icon: Icon(Icons.work)),
              Tab(icon: Icon(Icons.work_history_rounded)),
              Tab(icon: Icon(Icons.group_add)),
              Tab(icon: Icon(Icons.post_add)),
              Tab(icon: Icon(Icons.notifications)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ProfileScreen(isRecruiter: true), // Updated to include isRecruiter
            PostedJobsScreen(),
            _buildApplicantsTab(),
            PostJobScreen(),
            // Assuming the fifth tab is for posting jobs, adjust if needed
            Container(), // Placeholder for the fifth tab (e.g., additional stats or settings)
            NotificationsScreen(
              notifications: dummyNotifications, // Updated to include notifications
              isRecruiter: true, // Updated to include isRecruiter
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicantsTab() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Search by name...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                ),
              ),
              SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  final snapshot = await _firestore.collectionGroup('AppliedJobs').get();
                  final applicants = snapshot.docs.map((doc) {
                    final data = doc.data();
                    return {
                      'name': data['name'] ?? '',
                      'mobile': data['mobile'] ?? '',
                      'specialization': data['specialization'] ?? '',
                      'experience': data['experience'] ?? '',
                      'status': data['status'] ?? '',
                    };
                  }).toList();
                  await _exportToExcel(applicants);
                },
                icon: Icon(Icons.download),
                label: Text('Export'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _experienceFilter,
                  decoration: InputDecoration(labelText: 'Experience'),
                  items: ['All', '0-1', '1-3', '3+'].map((e) {
                    return DropdownMenuItem(value: e, child: Text(e));
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _experienceFilter = val!);
                  },
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedFilter,
                  decoration: InputDecoration(labelText: 'Status'),
                  items: ['All', 'Applied', 'Shortlisted', 'Rejected', 'Interview Scheduled'].map((e) {
                    return DropdownMenuItem(value: e, child: Text(e));
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedFilter = val!);
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collectionGroup('AppliedJobs').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toLowerCase();
                  final exp = data['experience'] ?? '';
                  final status = data['status'] ?? '';

                  final matchesSearch = name.contains(_searchQuery);
                  final matchesExp = _experienceFilter == 'All' || exp == _experienceFilter;
                  final matchesStatus = _selectedFilter == 'All' || status == _selectedFilter;

                  return matchesSearch && matchesExp && matchesStatus;
                }).toList();

                if (docs.isEmpty) return Center(child: Text('No applicants found.'));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final seekerId = doc.id;
                    final jobId = doc.reference.parent.parent?.id ?? '';

                    return Card(
                      elevation: 2,
                      margin: EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        title: Text(data['name'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Specialization: ${data['specialization'] ?? ''}'),
                            Text('Experience: ${data['experience'] ?? ''}'),
                            Text('Status: ${data['status'] ?? ''}'),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) => _handleAction(action, jobId, seekerId, data),
                          itemBuilder: (context) => [
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
}