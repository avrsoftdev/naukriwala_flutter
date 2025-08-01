import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'dart:developer' as dev;

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? recruiterId = FirebaseAuth.instance.currentUser?.uid;
  String _searchQuery = '';

  void _addToCalendar(String title, DateTime date) {
    final event = Event(
      title: title,
      description: 'Interview scheduled via Naukariwala',
      location: 'Online/To be decided',
      startDate: date,
      endDate: date.add(const Duration(hours: 1)),
    );
    Add2Calendar.addEvent2Cal(event);
    dev.log('Added calendar event: $title on ${DateFormat('dd MMM yyyy').format(date)}', name: 'CallsScreen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
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
                    dev.log('Error loading calls for recruiter $recruiterId: ${snapshot.error}', name: 'CallsScreen');
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
                    dev.log('No scheduled calls found for recruiter $recruiterId', name: 'CallsScreen');
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
      ),
    );
  }
}