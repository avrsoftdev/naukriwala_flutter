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
            SnackBar(
              content: const Text('Please log in to view notifications.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
            return Center(
              child: Card(
                elevation: 4,
                color: Colors.red.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    errorMessage,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            dev.log('No notifications found for UID $uid in ${widget.isRecruiter ? 'RecruiterNotifications' : 'SeekerNotifications'}/$uid/Notifications', name: 'NotificationsScreen');
            return Center(
              child: Text(
                'No notifications found.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final message = data['message'] ?? 'N/A';
              final timestamp = data['timestamp'] as Timestamp?;
              final read = data['read'] ?? false;
              final jobId = data['jobId'] as String? ?? 'Unknown';
              final notificationId = data['notificationId'] as String? ?? docs[index].id;

              return AnimatedListItem(
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: read
                            ? [Colors.grey.shade100, Colors.grey.shade200]
                            : [Colors.blue.shade50, Colors.blue.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16.0),
                      title: Text(
                        message,
                        style: TextStyle(
                          fontWeight: read ? FontWeight.normal : FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (timestamp != null)
                            Text(
                              _formatTimestamp(timestamp),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          Text(
                            'Job ID: $jobId',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      trailing: read
                          ? const Icon(Icons.check_circle, color: Colors.teal, size: 28)
                          : const Icon(Icons.circle, color: Colors.grey, size: 28),
                      onTap: () async {
                        if (!read) {
                          await _markAsRead(notificationId);
                        }
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Custom Animated List Item Widget
class AnimatedListItem extends StatefulWidget {
  final Widget child;

  const AnimatedListItem({required this.child, super.key});

  @override
  AnimatedListItemState createState() => AnimatedListItemState();
}

class AnimatedListItemState extends State<AnimatedListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _slideAnimation = Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
