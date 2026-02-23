// ignore_for_file: non_constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import 'dart:developer' as dev;

import '../services/auth_service.dart';
import '../services/play_integrity_service.dart';
import '../providers/message_state_provider.dart';
import 'seeker_details_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String recipientId;
  final String jobId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.recipientId,
    required this.jobId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _playIntegrity = PlayIntegrityService();

  bool _isNewChat = true;
  bool _showPrompt = false;
  bool? _isRecruiter;
  Map<String, dynamic>? _chatDetails;
  Timestamp? _lastSeenTimestamp;
  String? _lastMessageId;
  bool _isSending = false;
  bool _isAppInForeground = true; // Track app state
  bool _isSearchingMessages = false;
  String _messageSearchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid) Permission.notification.request();
    
    // Defer setting active chat to after first frame to avoid build conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messageStateService.setActiveChatId(widget.chatId);
    });
    
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _searchController.dispose();
    
    // Clear active chat safely after widget tree operations complete
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        messageStateService.setActiveChatId(null);
      });
    } catch (e) {
      // If binding is already closed, just set it directly
      messageStateService.setActiveChatId(null);
    }
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isAppInForeground = state == AppLifecycleState.resumed;
    });
  }

  Future<void> _initialize() async {
    await _determineRole();
    await _initializeChat();
    _setupFcmListeners();
  }

  // ────────────────────────────── ROLE & CHAT INIT ──────────────────────────────
  Future<void> _determineRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final indexDoc = await _firestore.collection('UsersIndex').doc(uid).get();
    if (!indexDoc.exists) return;

    final role = indexDoc.get('role') as String?;
    if (role == 'recruiter') {
      final recDoc = await _firestore.collection('Recruiters').doc(uid).get();
      _isRecruiter = recDoc.exists;
    } else if (role == 'seeker') {
      final seekerDoc = await _firestore.collection('Seekers').doc(uid).get();
      _isRecruiter = !seekerDoc.exists;
    }
  }

  Future<void> _initializeChat() async {
    // ignore: constant_identifier_names, unused_local_variable
    final [_, __] = await Future.wait([
      _checkIfNewChat(),
      _loadChatDetails(),
    ], eagerError: true);

    if (mounted && _isNewChat) {
      setState(() => _showPrompt = true);
    }
    await _markAsRead();
    _localNotifications.cancel(widget.chatId.hashCode); // Clear old notif
  }

  Future<void> _checkIfNewChat() async {
    final snap = await _firestore
        .collection('Messages')
        .doc(widget.chatId)
        .collection('Chats')
        .limit(1)
        .get();

    _isNewChat = snap.docs.isEmpty;
  }

  Future<void> _loadChatDetails() async {
    final details = await _fetchRecipientInfo();
    if (mounted) {
      setState(() => _chatDetails = details);
    }
  }

  void _openSeekerDetails() {
    if (_isRecruiter != true) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeekerDetailsScreen(
          seekerId: widget.recipientId,
          jobId: widget.jobId,
        ),
      ),
    );
  }

  // ────────────────────────────── FCM & LOCAL NOTIF ──────────────────────────────
  void _setupFcmListeners() {
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      if (msg.data['chatId'] == widget.chatId) {
        _markAsRead();
        _localNotifications.cancel(widget.chatId.hashCode);
      }
    });

    _messaging.getInitialMessage().then((msg) {
      if (msg?.data['chatId'] == widget.chatId && mounted) {
        _markAsRead();
        _localNotifications.cancel(widget.chatId.hashCode);
      }
    });
  }

  Future<void> _showLocalNotification(String name, String text) async {
    const android = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      importance: Importance.high,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('notification'),
    );
    const iOS = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: iOS);

    await _localNotifications.show(
      widget.chatId.hashCode,
      'New Message from $name',
      text.length > 50 ? '${text.substring(0, 47)}...' : text,
      details,
    );
  }

  // ────────────────────────────── SEND MESSAGE ──────────────────────────────
  Future<void> _sendMessage([String? preset]) async {
    if (_isSending) return;
    _isSending = true;

    final text = preset ?? _messageController.text.trim();
    if (text.isEmpty) {
      _isSending = false;
      return;
    }

    final senderId = _auth.currentUser?.uid;
    if (senderId == null) {
      _showError('Please log in to send messages.');
      _isSending = false;
      return;
    }

    final isRecruiter = _isRecruiter == true;

    try {
      if (!isRecruiter) {
        await _ensureApplicationExists(widget.jobId, widget.recipientId);
      }

      // AuthService.sendMessage() handles both message saving AND FCM notification
      await _authService.sendMessage(widget.recipientId, widget.jobId, text, status: 'sent');
      _messageController.clear();

      if (mounted) {
        setState(() {
          _isNewChat = false;
          _showPrompt = false;
        });
      }

      _showSuccess('Message sent');
    } catch (e) {
      _handleSendError(e, isRecruiter ? 'seeker' : 'recruiter');
    } finally {
      _isSending = false;
    }
  }

  Future<void> _ensureApplicationExists(String jobId, String recruiterId) async {
    final uid = _auth.currentUser!.uid;
    final appId = '${uid}_$jobId';
    final doc = await _firestore.collection('Applications').doc(appId).get();

    if (doc.exists) return;

    final jobDoc = await _firestore
        .collection('Recruiters')
        .doc(recruiterId)
        .collection('Jobs')
        .doc(jobId)
        .get();

    if (!jobDoc.exists) throw Exception('Job not found');

    final job = jobDoc.data()!;
    await _firestore.collection('Applications').doc(appId).set({
      'seekerId': uid,
      'jobId': jobId,
      'recruiterId': recruiterId,
      'status': 'Applied',
      'appliedAt': FieldValue.serverTimestamp(),
      'jobTitle': job['title'] ?? 'Unknown',
      'company': job['company'] ?? 'Unknown',
      'coverLetter': '',
    });
  }

  // ────────────────────────────── NOTIFY RECIPIENT ──────────────────────────────
  // ────────────────────────────── MARK AS READ ──────────────────────────────
  Future<void> _markAsRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final batch = _firestore.batch();
    final snap = await _firestore
        .collection('Messages')
        .doc(widget.chatId)
        .collection('Chats')
        .where('recipientId', isEqualTo: uid)
        .where('status', isNotEqualTo: 'read')
        .get();

    for (final doc in snap.docs) {
      batch.update(doc.reference, {'status': 'read'});
      final ts = doc.get('timestamp') as Timestamp?;
      if (ts != null && (_lastSeenTimestamp == null || ts.compareTo(_lastSeenTimestamp!) > 0)) {
        _lastSeenTimestamp = ts;
      }
    }
    await batch.commit();
    
    // Update the message state service to reset unread count for this chat
    messageStateService.resetUnreadCountForChat(widget.chatId);
    dev.log('Marked messages as read for chat: ${widget.chatId}', name: 'ChatScreen');
  }

  // ────────────────────────────── UI HELPERS ──────────────────────────────
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }
//democomment
  void _handleSendError(Object e, String expectedRole) {
    String msg = 'Failed to send message';
    if (e is FirebaseException && e.code == 'permission-denied') {
      msg = 'Permission denied. Ensure you are a valid $expectedRole.';
    } else if (e.toString().contains('No application found')) {
      msg = 'You must apply to the job first.';
    } else if (e.toString().contains('Failed to create application')) {
      msg = 'Failed to apply. Try again.';
    }
    _showError(msg);
  }

  Widget _buildTick(String status) {
    switch (status) {
      case 'sent':
        return Icon(Icons.check, size: 16.sp, color: Colors.grey);
      case 'received':
        return Icon(Icons.done_all, size: 16.sp, color: Colors.grey);
      case 'read':
        return Icon(Icons.done_all, size: 16.sp, color: Colors.blue);
      default:
        return const SizedBox.shrink();
    }
  }

  // ────────────────────────────── RECIPIENT INFO ──────────────────────────────
  Future<Map<String, String>> _fetchRecipientInfo() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {'recipientName': 'Unknown', 'company': 'Unknown'};
//commentssss3232
    String name = 'Unknown';
    String company = 'Unknown';
    for (int i = 0; i < 3; i++) {
      try {
        if (_isRecruiter == true) {
          final app = await _firestore
              .collection('Applications')
              .doc('${widget.recipientId}_${widget.jobId}')
              .get(const GetOptions(source: Source.server));
          if (app.exists) {
            final resume = app.get('resume') as Map?;
            name = resume?['name'] ?? name;
            company = app.get('company') ?? company;
          }
          final user = await _firestore.collection('UsersIndex').doc(widget.recipientId).get();
          if (user.exists) {
            final data = user.data()!;
            name = data['name'] ?? data['fullName'] ?? name;
          }
        } else {
          final app = await _firestore
              .collection('Applications')
              .doc('${uid}_${widget.jobId}')
              .get(const GetOptions(source: Source.server));
          if (app.exists) company = app.get('company') ?? company;

          final rec = await _firestore.collection('UsersIndex').doc(widget.recipientId).get();
          if (rec.exists) {
            final data = rec.data()!;
            name = data['name'] ?? data['companyName'] ?? 'Recruiter';
          }
        }
        break;
      } catch (e) {
        if (i == 2) rethrow;
        await Future.delayed(Duration(seconds: 1 << i));
      }
    }

    return {'recipientName': name, 'company': company};
  }

  // ────────────────────────────── MESSAGE OPTIONS (EDIT/DELETE) ──────────────────────────────
  void _showMessageOptions(BuildContext context, String messageId, String currentMessage) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Message Options',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.teal),
              title: Text('Copy Message', style: TextStyle(fontSize: 16.sp)),
              onTap: () {
                Navigator.pop(context);
                _copyMessage(currentMessage);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: Text('Edit Message', style: TextStyle(fontSize: 16.sp)),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(messageId, currentMessage);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Message', style: TextStyle(fontSize: 16.sp, color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(messageId);
              },
            ),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(fontSize: 16.sp, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyMessage(String message) async {
    final text = message.trim();
    if (text.isEmpty) {
      _showError('Nothing to copy');
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: text));
      _showSuccess('Message copied');
    } catch (e) {
      _showError('Failed to copy message: $e');
      dev.log('Error copying message: $e', name: 'ChatScreen');
    }
  }

  void _showEditDialog(String messageId, String currentMessage) {
    final editController = TextEditingController(text: currentMessage);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit Message', style: TextStyle(fontSize: 18.sp)),
        content: TextField(
          controller: editController,
          maxLines: null,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
            hintText: 'Enter your message',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
          ),
          ElevatedButton(
            onPressed: () {
              final newMessage = editController.text.trim();
              Navigator.pop(dialogContext);
              _editMessage(messageId, newMessage);
            },
            child: Text('Save', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  Future<void> _editMessage(String messageId, String newMessage) async {
    if (newMessage.isEmpty) {
      _showError('Message cannot be empty');
      return;
    }

    try {
      await _firestore
          .collection('Messages')
          .doc(widget.chatId)
          .collection('Chats')
          .doc(messageId)
          .update({
        'message': newMessage,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
      _showSuccess('Message edited');
    } catch (e) {
      _showError('Failed to edit message: $e');
      dev.log('Error editing message: $e', name: 'ChatScreen');
    }
  }

  void _showDeleteConfirmation(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Message?', style: TextStyle(fontSize: 18.sp)),
        content: Text(
          'This action cannot be undone.',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(messageId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(fontSize: 14.sp, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _firestore
          .collection('Messages')
          .doc(widget.chatId)
          .collection('Chats')
          .doc(messageId)
          .delete();
      _showSuccess('Message deleted');
    } catch (e) {
      _showError('Failed to delete message: $e');
      dev.log('Error deleting message: $e', name: 'ChatScreen');
    }
  }

  // ────────────────────────────── BUILD UI ──────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: _isSearchingMessages
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(fontSize: 15.sp, color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'Search messages...',
                    hintStyle: TextStyle(color: Colors.white70, fontSize: 14.sp),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() => _messageSearchQuery = value.trim().toLowerCase());
                  },
                )
              : FutureBuilder(
                  future: Future.value(_chatDetails),
                  builder: (_, snap) {
                    final title = _isRecruiter == true
                        ? (_chatDetails != null ? _chatDetails!['recipientName'] : null) ?? widget.recipientId
                        : _chatDetails?['company'] ?? widget.recipientId;

                    final titleText = Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: _isRecruiter == true ? TextDecoration.underline : TextDecoration.none,
                      ),
                      overflow: TextOverflow.ellipsis,
                    );

                    if (_isRecruiter == true) {
                      return GestureDetector(
                        onTap: _openSeekerDetails,
                        child: titleText,
                      );
                    }

                    return titleText;
                  },
                ),
          actions: [
            IconButton(
              icon: Icon(_isSearchingMessages ? Icons.close : Icons.search, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isSearchingMessages = !_isSearchingMessages;
                  if (!_isSearchingMessages) {
                    _searchController.clear();
                    _messageSearchQuery = '';
                  }
                });
              },
            ),
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('Messages')
                        .doc(widget.chatId)
                        .collection('Chats')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text('Failed to load messages'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;
                      final visibleDocs = _messageSearchQuery.isEmpty
                          ? docs
                          : docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final messageText = (data['message'] ?? '').toString().toLowerCase();
                              return messageText.contains(_messageSearchQuery);
                            }).toList();

                      final latest = docs.isNotEmpty ? docs.first : null;
                      if (latest != null && latest.id != _lastMessageId) {
                        _lastMessageId = latest.id;
                        final data = latest.data() as Map<String, dynamic>;
                        if (data['senderId'] != _auth.currentUser?.uid) {
                          final name = _isRecruiter == true
                              ? (_chatDetails?['recipientName'] ?? 'User')
                              : (_chatDetails?['company'] ?? 'Recruiter');

                          // ONLY SHOW LOCAL NOTIF IF APP IS NOT IN FOREGROUND
                          if (!_isAppInForeground) {
                            _showLocalNotification(name, data['message'] ?? '');
                          }

                          _markAsRead();
                        }
                      }

                      if (visibleDocs.isEmpty) {
                        return Center(
                          child: Text(
                            _messageSearchQuery.isEmpty ? 'No messages yet' : 'No messages found',
                            style: TextStyle(fontSize: 15.sp, color: Colors.grey[700]),
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        itemCount: visibleDocs.length,
                        itemBuilder: (_, i) {
                          final data = visibleDocs[i].data() as Map<String, dynamic>;
                          final messageId = visibleDocs[i].id;
                          final isMe = data['senderId'] == _auth.currentUser?.uid;
                          final status = data['status'] ?? 'sent';
                          final isEdited = data['isEdited'] ?? false;

                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 5.h, horizontal: 10.w),
                            child: Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: GestureDetector(
                                onLongPress: () {
                                  if (isMe) {
                                    _showMessageOptions(context, messageId, data['message'] ?? '');
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.all(10.w),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.teal.shade100 : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['message'] ?? '',
                                        style: TextStyle(fontSize: 16.sp),
                                      ),
                                      if (isEdited)
                                        Padding(
                                          padding: EdgeInsets.only(top: 4.h),
                                          child: Text(
                                            '(edited)',
                                            style: TextStyle(
                                              fontSize: 10.sp,
                                              color: Colors.grey[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      SizedBox(height: 5.h),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            data['timestamp'] != null
                                                ? DateFormat('MMM d, h:mm a')
                                                    .format((data['timestamp'] as Timestamp).toDate())
                                                : '—',
                                            style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                                          ),
                                          if (isMe) ...[
                                            SizedBox(width: 4.w),
                                            _buildTick(status),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  if (_showPrompt && _isNewChat)
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(16.w),
                        color: Colors.white.withAlpha(245),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Start chat with default message?',
                              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _sendMessage(
                                      'Hello, let’s discuss about application for "${_chatDetails?['company'] ?? widget.jobId}"!'),
                                  child: Text('Yes', style: TextStyle(fontSize: 14.sp)),
                                ),
                                SizedBox(width: 10.w),
                                TextButton(
                                  onPressed: () => setState(() => _showPrompt = false),
                                  child: Text('No', style: TextStyle(fontSize: 14.sp)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.w),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(color: Colors.teal, width: 2.w),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.teal,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4.r, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Icon(Icons.send, color: Colors.white, size: 24.r),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
