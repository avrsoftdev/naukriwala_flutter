import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
  late final String collectionPath;

  @override
void initState() {
  super.initState();
  collectionPath = widget.isRecruiter ? 'RecruiterNotifications' : 'SeekerNotifications';
  if (uid != null) {
    // Start with the base query
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection(collectionPath)
        .doc(uid)
        .collection('Notifications')
        .where('to', isEqualTo: uid);

    // Apply type filter based on role
    if (widget.isRecruiter) {
      query = query.where('type', isEqualTo: 'application');
    } else {
      query = query.where('type', whereIn: ['application', 'status_update']);
    }

    // Convert to Stream with orderBy
    _notificationsStream = query
        .orderBy('timestamp', descending: true)
        .snapshots();

    dev.log('[2025-08-09 02:15 IST] Initialized notifications stream for ${widget.isRecruiter ? 'recruiter' : 'seeker'} UID: $uid in $collectionPath', name: 'NotificationsScreen');
  } else {
    dev.log('[2025-08-09 02:15 IST] No authenticated user found', name: 'NotificationsScreen');
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
      await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(uid)
          .collection('Notifications')
          .doc(notificationId)
          .update({'read': true});
      dev.log('[2025-08-09 01:15 IST] Marked notification $notificationId as read for UID $uid in $collectionPath', name: 'NotificationsScreen');
    } catch (e) {
      dev.log('[2025-08-09 01:15 IST] Error marking notification $notificationId as read: $e', name: 'NotificationsScreen', error: e);
      if (e is FirebaseException && e.code == 'permission-denied') {
        dev.log('[2025-08-09 01:15 IST] Permission denied updating $collectionPath/$uid/Notifications/$notificationId', name: 'NotificationsScreen');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission denied updating notification'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<Map<String, dynamic>> _getNotificationDetails(String jobId, String seekerId) async {
    try {
      final appDoc = await FirebaseFirestore.instance
          .collection('Applications')
          .doc('${seekerId}_$jobId')
          .get();
      if (appDoc.exists) {
        final data = appDoc.data()!;
        return {
          'jobTitle': data['jobTitle'] ?? 'Unknown',
          'resumeUrl': widget.isRecruiter ? (data['resume']?['cvUrl'] ?? 'N/A') : null
        };
      }
    } catch (e) {
      dev.log('[2025-08-09 01:15 IST] Error fetching details for job $jobId, seeker $seekerId: $e', name: 'NotificationsScreen', error: e);
    }
    return {'jobTitle': 'Unknown', 'resumeUrl': null};
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      dev.log('[2025-08-09 01:15 IST] Redirecting to login due to null UID', name: 'NotificationsScreen');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to view notifications.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return const SizedBox.shrink();
    }

    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
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
                dev.log('[2025-08-09 01:15 IST] Error loading notifications for UID $uid: ${snapshot.error}', name: 'NotificationsScreen', error: snapshot.error);
                String errorMessage = 'Error loading notifications. Please verify Firestore permissions.';
                if (snapshot.error is FirebaseException) {
                  final error = snapshot.error as FirebaseException;
                  errorMessage = 'Firebase error: ${error.code} - ${error.message}';
                  if (error.code == 'permission-denied') {
                    errorMessage += '\nEnsure /$collectionPath/$uid/Notifications exists with to=$uid.';
                  } else if (error.code == 'failed-precondition') {
                    errorMessage += '\nIndex required. Create it at: https://console.firebase.google.com/v1/r/project/naukriwala-455909/firestore/indexes';
                  }
                }
                return Center(
                  child: Card(
                    elevation: 4,
                    color: Colors.red.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Text(
                        errorMessage,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 16.sp),
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
                dev.log('[2025-08-09 01:15 IST] No notifications found for UID $uid in $collectionPath', name: 'NotificationsScreen');
                return Center(
                  child: Text(
                    'No notifications found.',
                    style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final message = data['message'] ?? 'N/A';
                  final timestamp = data['timestamp'] as Timestamp?;
                  final read = data['read'] ?? false;
                  final jobId = data['jobId'] as String? ?? 'Unknown';
                  final seekerId = data['seekerId'] as String? ?? 'Unknown';
                  final notificationId = data['notificationId'] as String? ?? docs[index].id;

                  return FutureBuilder<Map<String, dynamic>>(
                    future: _getNotificationDetails(jobId, seekerId),
                    builder: (context, detailsSnapshot) {
                      final jobTitle = detailsSnapshot.data?['jobTitle'] ?? 'Unknown';
                      final resumeUrl = detailsSnapshot.data?['resumeUrl'];

                      return AnimatedListItem(
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: read
                                    ? [Colors.grey.shade100, Colors.grey.shade200]
                                    : [Colors.blue.shade50, Colors.blue.shade100],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(16.w),
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
                                    'Job: $jobTitle (ID: $jobId)',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  if (resumeUrl != null && widget.isRecruiter)
                                    Text(
                                      'Resume URL: $resumeUrl',
                                      style: TextStyle(color: Colors.blue.shade600),
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
              );
            },
          ),
        );
      },
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