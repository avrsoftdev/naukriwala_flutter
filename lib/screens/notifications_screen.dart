// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  final Set<String> _initiallyUnreadNotifications = {};
  bool _isSelectionMode = false;
  final AuthService _authService = AuthService();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

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
        query = query.where('type', whereIn: ['application', 'message', 'interview_confirmation_response']);
      } else {
        query = query.where('type', whereIn: [
          'application',
          'status_update',
          'message',
          'interview_scheduled', // legacy
          'interview_confirmation_request',
        ]);
      }

      _notificationsStream = query
          .orderBy('timestamp', descending: true)
          .snapshots();

      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Initialized notifications stream for ${widget.isRecruiter ? 'recruiter' : 'seeker'} UID: $uid in $collectionPath', name: 'NotificationsScreen');

      _setupFCMListeners();
      _initializeLocalNotifications();
      _markUnreadAsReadAndTrack();
    } else {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] No authenticated user found', name: 'NotificationsScreen');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _markUnreadAsReadAndTrack() async {
    if (uid == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(uid)
          .collection('Notifications')
          .where('read', isEqualTo: false)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          final notificationId = doc.id;
          _initiallyUnreadNotifications.add(notificationId);
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Marked ${_initiallyUnreadNotifications.length} unread notifications as read and tracked for highlighting for UID $uid', name: 'NotificationsScreen');
      }
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error marking unread notifications as read: $e', name: 'NotificationsScreen', error: e);
    }
  }

  void _initializeLocalNotifications() {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(RemoteMessage(
          data: {'type': 'message', 'notificationId': response.id.toString(), 'chatId': 'sampleChatId', 'jobId': 'sampleJobId', 'seekerId': 'sampleSeekerId', 'from': 'sampleFrom'},
          messageId: response.id.toString(),
        ));
      },
    );
  }

  void _setupFCMListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Foreground message received: ${message.messageId}', name: 'NotificationsScreen FCM');
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Notification opened: ${message.messageId}', name: 'NotificationsScreen FCM');
      _handleNotificationTap(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && mounted) {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] App opened via notification: ${message.messageId}', name: 'NotificationsScreen FCM');
        _handleNotificationTap(message);
      }
    });
  }

  void _showLocalNotification(RemoteMessage message) {
    const androidDetails = AndroidNotificationDetails(
      'notifications_channel',
      'Notifications',
      channelDescription: 'Notifications for new messages and updates',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);
    _flutterLocalNotificationsPlugin.show(
      message.messageId.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? message.data['message'] ?? 'New update',
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
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
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Navigated to ChatScreen from FCM: chatId=$chatId', name: 'NotificationsScreen FCM');
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
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Marked notification $notificationId as read for UID $uid in $collectionPath', name: 'NotificationsScreen');
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error marking notification $notificationId as read: $e', name: 'NotificationsScreen', error: e);
      if (e is FirebaseException && e.code == 'permission-denied') {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Permission denied updating $collectionPath/$uid/Notifications/$notificationId', name: 'NotificationsScreen');
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
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Marked notification $notificationId as unread for UID $uid in $collectionPath', name: 'NotificationsScreen');
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error marking notification $notificationId as unread: $e', name: 'NotificationsScreen', error: e);
      if (e is FirebaseException && e.code == 'permission-denied') {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Permission denied updating $collectionPath/$uid/Notifications/$notificationId', name: 'NotificationsScreen');
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
    
    final confirmed = await _showConfirmationDialog(
      title: 'Delete Notifications',
      message: 'Are you sure you want to delete ${_selectedNotifications.length} notification(s)? This action cannot be undone.',
      context: context,
    );

    if (!confirmed) return;

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
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Deleted selected notifications for UID $uid', name: 'NotificationsScreen');
      setState(() {
        _selectedNotifications.clear();
        _isSelectionMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error deleting selected notifications: $e', name: 'NotificationsScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting notifications'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAllNotifications() async {
    if (uid == null) return;

    final confirmed = await _showConfirmationDialog(
      title: 'Delete All Notifications',
      message: 'Are you sure you want to delete all notifications? This action cannot be undone.',
      context: context,
    );

    if (!confirmed) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(uid)
          .collection('Notifications')
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Deleted all notifications for UID $uid', name: 'NotificationsScreen');
      setState(() {
        _selectedNotifications.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error deleting all notifications: $e', name: 'NotificationsScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting notifications'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
    required BuildContext context,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
    return result ?? false;
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
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Marked selected notifications as read for UID $uid', name: 'NotificationsScreen');
      setState(() {
        _selectedNotifications.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error marking selected notifications as read: $e', name: 'NotificationsScreen', error: e);
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
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error fetching resume URL for job $jobId, seeker $seekerId: $e', name: 'NotificationsScreen', error: e);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Redirecting to login due to null UID', name: 'NotificationsScreen');
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
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Delete Selected',
                      onPressed: _selectedNotifications.isEmpty ? null : _deleteSelectedNotifications,
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'delete_all') {
                          await _deleteAllNotifications();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete_all',
                          child: Text('Delete All'),
                        ),
                      ],
                    ),
                  ]
                : [
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'delete_all') {
                          await _deleteAllNotifications();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete_all',
                          child: Text('Delete All'),
                        ),
                      ],
                    ),
                  ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: _notificationsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Stream error for UID $uid: ${snapshot.error}', name: 'NotificationsScreen');
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
                dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] No notifications found for UID $uid in $collectionPath', name: 'NotificationsScreen');
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
                  final notificationDocId = docs[index].id;
                  final notificationId = data['notificationId'] as String? ?? notificationDocId;
                  final type = data['type'] as String? ?? 'Unknown';
                  final jobTitle = data['jobTitle'] as String? ?? 'Untitled';
                  final isSelected = _selectedNotifications.contains(notificationDocId);
                  final wasInitiallyUnread = _initiallyUnreadNotifications.contains(notificationDocId);
                  final actionStatus = (data['actionStatus'] as String?)?.toLowerCase();
                  final interviewDate = data['interviewDate'] as Timestamp?;

                  return FutureBuilder<String?>(
                    future: _getResumeUrl(jobId, seekerId),
                    builder: (context, resumeSnapshot) {
                      final resumeUrl = resumeSnapshot.data;

                      return AnimatedListItem(
                        child: GestureDetector(
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(notificationDocId);
                            } else {
                              if (type == 'message') {
                                try {
                                  if (jobId == 'Unknown' || seekerId == 'Unknown') {
                                    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Skipping chat navigation: Invalid jobId ($jobId) or seekerId ($seekerId)', name: 'NotificationsScreen');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Invalid chat details. Please try again.'), backgroundColor: Colors.red),
                                      );
                                    }
                                    return;
                                  }
                                  _authService.getChatId(seekerId: seekerId, jobId: jobId).then((chatId) {
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
                                  });
                                } catch (e) {
                                  dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error navigating to ChatScreen for notification $notificationId: $e', name: 'NotificationsScreen', error: e);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error opening chat: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              }
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              _isSelectionMode = true;
                              _toggleSelection(notificationDocId);
                            });
                          },
                          child: Card(
                            elevation: isSelected ? 6 : 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              side: BorderSide(
                                color: isSelected ? Colors.blue.shade500 : Colors.transparent,
                                width: isSelected ? 2 : 0,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isSelected
                                      ? [Colors.blue.shade100, Colors.blue.shade50]
                                      : (wasInitiallyUnread
                                          ? [Colors.amber.shade50, Colors.amber.shade100]
                                          : [Colors.grey.shade100, Colors.grey.shade200]),
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                title: Text(
                                  '$jobTitle: $message',
                                  style: TextStyle(
                                    fontWeight: wasInitiallyUnread ? FontWeight.w600 : FontWeight.normal,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 4.h),
                                    if (timestamp != null)
                                      Text(
                                        _formatTimestamp(timestamp),
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
                                      ),
                                    if (!widget.isRecruiter &&
                                        uid != null &&
                                        (type == 'interview_confirmation_request' || type == 'interview_scheduled'))
                                      Padding(
                                        padding: EdgeInsets.only(top: 10.h),
                                        child: InterviewConfirmationActions(
                                          authService: _authService,
                                          jobId: jobId,
                                          seekerId: uid!,
                                          recruiterId: data['from'] ?? 'Unknown',
                                          notificationId: notificationDocId,
                                          actionStatus: actionStatus ?? 'pending',
                                          interviewDate: interviewDate,
                                        ),
                                      ),
                                    if (resumeUrl != null && widget.isRecruiter)
                                      Padding(
                                        padding: EdgeInsets.only(top: 4.h),
                                        child: InkWell(
                                          onTap: () {
                                            dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Resume URL tapped: $resumeUrl', name: 'NotificationsScreen');
                                          },
                                          child: Text(
                                            'Resume: $resumeUrl',
                                            style: TextStyle(color: Colors.blue.shade600, fontSize: 14.sp),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
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

class InterviewConfirmationActions extends StatefulWidget {
  final AuthService authService;
  final String jobId;
  final String seekerId;
  final String recruiterId;
  final String notificationId;
  final String actionStatus; // pending/accepted/declined
  final Timestamp? interviewDate;

  const InterviewConfirmationActions({
    required this.authService,
    required this.jobId,
    required this.seekerId,
    required this.recruiterId,
    required this.notificationId,
    required this.actionStatus,
    required this.interviewDate,
    super.key,
  });

  @override
  State<InterviewConfirmationActions> createState() => _InterviewConfirmationActionsState();
}

class _InterviewConfirmationActionsState extends State<InterviewConfirmationActions> {
  bool _isLoading = false;

  Future<void> _navigateToChatWithRescheduleMessage() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    
    try {
      final chatId = await widget.authService.getChatId(
        seekerId: widget.seekerId,
        jobId: widget.jobId,
      );
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            recipientId: widget.recruiterId,
            jobId: widget.jobId,
            initialMessage: "Hi, I'm not available for the scheduled interview. Could we please reschedule it at a convenient time?",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening chat: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _labelForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'You confirmed availability';
      case 'declined':
        return 'You are not available';
      case 'pending':
      default:
        return 'Confirm your availability';
    }
  }

  Future<void> _respond(bool isAvailable) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await widget.authService.respondToInterviewConfirmation(
        jobId: widget.jobId,
        seekerId: widget.seekerId,
        notificationId: widget.notificationId,
        isAvailable: isAvailable,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAvailable ? 'Interview confirmed' : 'Marked not available'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to respond: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.actionStatus.toLowerCase();
    final dt = widget.interviewDate?.toDate();
    final dateStr = dt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(dt) : null;

    if (status != 'pending') {
      return Row(
        children: [
          Icon(status == 'accepted' ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 18, color: status == 'accepted' ? Colors.green.shade700 : Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_labelForStatus(status)}${dateStr != null ? ' for $dateStr' : ''}',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_labelForStatus(status)}${dateStr != null ? ' for $dateStr' : ''}',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _navigateToChatWithRescheduleMessage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D47A1),
                  side: BorderSide(color: const Color(0xFF0D47A1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
                child: _isLoading 
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Text('Chat Now'),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _respond(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
                child: _isLoading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Confirm'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
