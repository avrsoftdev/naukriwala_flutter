import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;

class NotificationsScreen extends StatefulWidget {
  final List<Map<String, String>>? notifications;
  final bool isRecruiter;

  const NotificationsScreen({this.notifications, this.isRecruiter = false, super.key});

  @override
  NotificationsScreenState createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  late final Stream<QuerySnapshot> _notificationsStream;
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    if (uid != null) {
      final collection = widget.isRecruiter ? 'RecruiterNotifications' : 'SeekerNotifications';
      _notificationsStream = FirebaseFirestore.instance
          .collection(collection)
          .doc(uid)
          .collection('Notifications')
          .where('type', isEqualTo: 'application')
          .orderBy('timestamp', descending: true)
          .snapshots();
      dev.log('Initialized notifications stream for ${widget.isRecruiter ? 'recruiter' : 'seeker'} UID: $uid in $collection', name: 'NotificationsScreen');
    } else {
      dev.log('No authenticated user found', name: 'NotificationsScreen');
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final dt = ts.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  Future<void> _markAsRead(String notificationId) async {
    if (uid == null) return;
    try {
      final collection = widget.isRecruiter ? 'RecruiterNotifications' : 'SeekerNotifications';
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(uid)
          .collection('Notifications')
          .doc(notificationId)
          .update({'read': true});
      dev.log('Marked notification $notificationId as read for UID $uid in $collection', name: 'NotificationsScreen');
    } catch (e) {
      dev.log('Error marking notification $notificationId as read: $e', name: 'NotificationsScreen', error: e);
      if (e is FirebaseException && e.code == 'permission-denied') {
        dev.log('Permission denied updating ${widget.isRecruiter ? 'RecruiterNotifications' : 'SeekerNotifications'}/$uid/Notifications/$notificationId', name: 'NotificationsScreen');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      dev.log('Redirecting to login due to null UID', name: 'NotificationsScreen');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to view notifications.')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            dev.log('Error loading notifications for UID $uid: ${snapshot.error}', name: 'NotificationsScreen', error: snapshot.error);
            String errorMessage = 'Error loading notifications: ${snapshot.error}';
            if (snapshot.error.toString().contains('FAILED_PRECONDITION')) {
              errorMessage = 'Error loading notifications: Index required. Create it here: https://console.firebase.google.com/v1/r/project/naukriwala-455909/firestore/indexes';
            } else if (snapshot.error.toString().contains('PERMISSION_DENIED')) {
              errorMessage = 'Permission denied: Verify role claim and Firestore rules for ${widget.isRecruiter ? 'RecruiterNotifications' : 'SeekerNotifications'}/$uid/Notifications';
            }
            return Center(child: Text(errorMessage, textAlign: TextAlign.center));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            dev.log('No notifications found for UID $uid in ${widget.isRecruiter ? 'RecruiterNotifications' : 'SeekerNotifications'}/$uid/Notifications', name: 'NotificationsScreen');
            return Center(
              child: Text(
                'No notifications found. Ensure ${widget.isRecruiter ? 'RecruiterNotifications' : 'SeekerNotifications'}/$uid/Notifications contains data or verify applyToJob execution.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final message = data['message'] ?? 'N/A';
              final timestamp = data['timestamp'] as Timestamp?;
              final read = data['read'] ?? false;
              final jobId = data['jobId'] as String? ?? 'Unknown';
              final notificationId = data['notificationId'] as String? ?? docs[index].id;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
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
                    if (!read) {
                      await _markAsRead(notificationId);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}