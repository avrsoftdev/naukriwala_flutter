// ignore_for_file: use_build_context_synchronously, unused_import

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_service.dart';
import './chat_screen.dart';

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
  final Set<String> _selectedNotifications = {};
  bool _isSelectionMode = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    collectionPath = widget.isRecruiter ? 'RecruiterNotifications' : 'SeekerNotifications';
    if (uid != null) {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(uid)
          .collection('Notifications')
          .where('to', isEqualTo: uid);

      if (widget.isRecruiter) {
        query = query.where('type', whereIn: ['application', 'message']);
      } else {
        query = query.where('type', whereIn: ['application', 'status_update', 'message']);
      }

      _notificationsStream = query
          .orderBy('timestamp', descending: true)
          .snapshots();

      dev.log('[2025-10-10 12:57 IST] Initialized notifications stream for ${widget.isRecruiter ? 'recruiter' : 'seeker'} UID: $uid in $collectionPath', name: 'NotificationsScreen');

      // Handle FCM notification taps
      _setupFCMListeners();
    } else {
      dev.log('[2025-10-10 12:57 IST] No authenticated user found', name: 'NotificationsScreen');
    }
  }

  void _setupFCMListeners() {
    // Handle notification taps from background/terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      dev.log('[2025-10-10 12:57 IST] Notification opened: ${message.messageId}', name: 'NotificationsScreen FCM');
      final data = message.data;
      final type = data['type'] as String? ?? 'unknown';
      final notificationId = data['notificationId'] as String?;
      final jobId = data['jobId'] as String?;
      final seekerId = data['seekerId'] as String?;
      final chatId = data['chatId'] as String?;

      if (notificationId != null) {
        _markAsRead(notificationId);
      }

      if (type == 'message' && chatId != null && jobId != null && seekerId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              recipientId: widget.isRecruiter ? seekerId : data['from'] ?? 'Unknown',
              jobId: jobId,
            ),
          ),
        );
        dev.log('[2025-10-10 12:57 IST] Navigated to ChatScreen from FCM: chatId=$chatId', name: 'NotificationsScreen FCM');
      }
    });

    // Handle initial message (app opened via notification)
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && mounted) {
        dev.log('[2025-10-10 12:57 IST] App opened via notification: ${message.messageId}', name: 'NotificationsScreen FCM');
        final data = message.data;
        final type = data['type'] as String? ?? 'unknown';
        final notificationId = data['notificationId'] as String?;
        final jobId = data['jobId'] as String?;
        final seekerId = data['seekerId'] as String?;
        final chatId = data['chatId'] as String?;

        if (notificationId != null) {
          _markAsRead(notificationId);
        }

        if (type == 'message' && chatId != null && jobId != null && seekerId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                recipientId: widget.isRecruiter ? seekerId : data['from'] ?? 'Unknown',
                jobId: jobId,
              ),
            ),
          );
          dev.log('[2025-10-10 12:57 IST] Navigated to ChatScreen from initial message: chatId=$chatId', name: 'NotificationsScreen FCM');
        }
      }
    });
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
      dev.log('[2025-10-10 12:57 IST] Marked notification $notificationId as read for UID $uid in $collectionPath', name: 'NotificationsScreen');
    } catch (e) {
      dev.log('[2025-10-10 12:57 IST] Error marking notification $notificationId as read: $e', name: 'NotificationsScreen', error: e);
      if (e is FirebaseException && e.code == 'permission-denied') {
        dev.log('[2025-10-10 12:57 IST] Permission denied updating $collectionPath/$uid/Notifications/$notificationId', name: 'NotificationsScreen');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission denied: Cannot update notification. Check user role.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _markAsUnread(String notificationId) async {
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(uid)
          .collection('Notifications')
          .doc(notificationId)
          .update({'read': false});
      dev.log('[2025-10-10 12:57 IST] Marked notification $notificationId as unread for UID $uid in $collectionPath', name: 'NotificationsScreen');
    } catch (e) {
      dev.log('[2025-10-10 12:57 IST] Error marking notification $notificationId as unread: $e', name: 'NotificationsScreen', error: e);
      if (e is FirebaseException && e.code == 'permission-denied') {
        dev.log('[2025-10-10 12:57 IST] Permission denied updating $collectionPath/$uid/Notifications/$notificationId', name: 'NotificationsScreen');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission denied: Cannot update notification. Check user role.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteSelectedNotifications() async {
    if (uid == null || _selectedNotifications.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var notificationId in _selectedNotifications) {
        final docRef = FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(uid)
            .collection('Notifications')
            .doc(notificationId);
        batch.delete(docRef);
      }
      await batch.commit();
      dev.log('[2025-10-10 12:57 IST] Deleted selected notifications for UID $uid', name: 'NotificationsScreen');
      setState(() {
        _selectedNotifications.clear();
        _isSelectionMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected notifications deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      dev.log('[2025-10-10 12:57 IST] Error deleting selected notifications: $e', name: 'NotificationsScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting notifications'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markSelectedAsRead() async {
    if (uid == null || _selectedNotifications.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var notificationId in _selectedNotifications) {
        final docRef = FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(uid)
            .collection('Notifications')
            .doc(notificationId);
        batch.update(docRef, {'read': true});
      }
      await batch.commit();
      dev.log('[2025-10-10 12:57 IST] Marked selected notifications as read for UID $uid', name: 'NotificationsScreen');
      setState(() {
        _selectedNotifications.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      dev.log('[2025-10-10 12:57 IST] Error marking selected notifications as read: $e', name: 'NotificationsScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating notifications'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markSelectedAsUnread() async {
    if (uid == null || _selectedNotifications.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var notificationId in _selectedNotifications) {
        final docRef = FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(uid)
            .collection('Notifications')
            .doc(notificationId);
        batch.update(docRef, {'read': false});
      }
      await batch.commit();
      dev.log('[2025-10-10 12:57 IST] Marked selected notifications as unread for UID $uid', name: 'NotificationsScreen');
      setState(() {
        _selectedNotifications.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      dev.log('[2025-10-10 12:57 IST] Error marking selected notifications as unread: $e', name: 'NotificationsScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating notifications'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleSelection(String notificationId) {
    setState(() {
      if (_selectedNotifications.contains(notificationId)) {
        _selectedNotifications.remove(notificationId);
      } else {
        _selectedNotifications.add(notificationId);
      }
      _isSelectionMode = _selectedNotifications.isNotEmpty;
    });
  }

  Future<String?> _getResumeUrl(String jobId, String seekerId) async {
    try {
      final appDoc = await FirebaseFirestore.instance
          .collection('Applications')
          .doc('${seekerId}_$jobId')
          .get();
      if (appDoc.exists && widget.isRecruiter) {
        final data = appDoc.data()!;
        return data['resume']?['cvUrl'] ?? 'N/A';
      }
    } catch (e) {
      dev.log('[2025-10-10 12:57 IST] Error fetching resume URL for job $jobId, seeker $seekerId: $e', name: 'NotificationsScreen', error: e);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      dev.log('[2025-10-10 12:57 IST] Redirecting to login due to null UID', name: 'NotificationsScreen');
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
            title: Text(
              _isSelectionMode ? '${_selectedNotifications.length} Selected' : 'Notifications',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            elevation: 4,
            actions: _isSelectionMode
                ? [
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'mark_read') {
                          await _markSelectedAsRead();
                        } else if (value == 'mark_unread') {
                          await _markSelectedAsUnread();
                        } else if (value == 'delete') {
                          await _deleteSelectedNotifications();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'mark_read',
                          child: Text('Mark as Read'),
                        ),
                        const PopupMenuItem(
                          value: 'mark_unread',
                          child: Text('Mark as Unread'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ]
                : [],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: _notificationsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                dev.log('[2025-10-10 12:57 IST] Stream error for UID $uid: ${snapshot.error}', name: 'NotificationsScreen');
                String errorMessage = 'Error loading notifications. Please verify Firestore permissions or contact support.';
                if (snapshot.error is FirebaseException) {
                  final error = snapshot.error as FirebaseException;
                  errorMessage = 'Firebase error: ${error.code} - ${error.message}';
                  if (error.code == 'permission-denied') {
                    errorMessage += '\nEnsure $collectionPath/$uid/Notifications exists with to=$uid.';
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
                dev.log('[2025-10-10 12:57 IST] No notifications found for UID $uid in $collectionPath', name: 'NotificationsScreen');
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
                  final type = data['type'] as String? ?? 'Unknown';
                  final jobTitle = data['jobTitle'] as String? ?? 'Untitled';

                  return FutureBuilder<String?>(
                    future: _getResumeUrl(jobId, seekerId),
                    builder: (context, resumeSnapshot) {
                      final resumeUrl = resumeSnapshot.data;

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
                            child: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'mark_read') {
                                  await _markAsRead(notificationId);
                                } else if (value == 'mark_unread') {
                                  await _markAsUnread(notificationId);
                                }
                              },
                              itemBuilder: (context) => [
                                if (!read)
                                  const PopupMenuItem(
                                    value: 'mark_read',
                                    child: Text('Mark as Read'),
                                  ),
                                if (read)
                                  const PopupMenuItem(
                                    value: 'mark_unread',
                                    child: Text('Mark as Unread'),
                                  ),
                              ],
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                                leading: Checkbox(
                                  value: _selectedNotifications.contains(notificationId),
                                  onChanged: (value) {
                                    _toggleSelection(notificationId);
                                  },
                                ),
                                title: Text(
                                  '$jobTitle: $message',
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
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
                                      ),
                                    if (resumeUrl != null && widget.isRecruiter)
                                      InkWell(
                                        onTap: () {
                                          // Implement resume URL opening logic if needed
                                          dev.log('[2025-10-10 12:57 IST] Resume URL tapped: $resumeUrl', name: 'NotificationsScreen');
                                        },
                                        child: Text(
                                          'Resume URL: $resumeUrl',
                                          style: TextStyle(color: Colors.blue.shade600, fontSize: 14.sp),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: read
                                    ? const Icon(Icons.check_circle, color: Colors.teal, size: 28)
                                    : const Icon(Icons.circle, color: Colors.grey, size: 28),
                                onTap: () async {
                                  if (!_isSelectionMode) {
                                    if (!read) {
                                      await _markAsRead(notificationId);
                                    }
                                    if (type == 'message') {
                                      try {
                                        if (jobId == 'Unknown' || seekerId == 'Unknown') {
                                          dev.log('[2025-10-10 12:57 IST] Skipping chat navigation: Invalid jobId ($jobId) or seekerId ($seekerId)', name: 'NotificationsScreen');
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Invalid chat details. Please try again.'), backgroundColor: Colors.red),
                                            );
                                          }
                                          return;
                                        }
                                        final chatId = await _authService.getChatId(seekerId: seekerId, jobId: jobId);
                                        if (mounted) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ChatScreen(
                                                chatId: chatId,
                                                recipientId: widget.isRecruiter ? seekerId : data['from'] ?? 'Unknown',
                                                jobId: jobId,
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        dev.log('[2025-10-10 12:57 IST] Error navigating to ChatScreen for notification $notificationId: $e', name: 'NotificationsScreen', error: e);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error opening chat: $e'), backgroundColor: Colors.red),
                                          );
                                        }
                                      }
                                    }
                                  } else {
                                    _toggleSelection(notificationId);
                                  }
                                },
                                onLongPress: () {
                                  setState(() {
                                    _isSelectionMode = true;
                                    _toggleSelection(notificationId);
                                  });
                                },
                              ),
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
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _slideAnimation = Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(_controller);
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