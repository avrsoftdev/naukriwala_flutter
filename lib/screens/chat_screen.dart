// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:developer' as dev;
import 'package:firebase_app_check/firebase_app_check.dart';
// ignore: unnecessary_import
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String recipientId;
  final String jobId;

  const ChatScreen({super.key, required this.chatId, required this.recipientId, required this.jobId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isNewChat = true;
  Map<String, dynamic>? _chatDetails;
  late Future<void> _initializationFuture = Future.value();
  bool _showInitialMessagePrompt = false;
  bool? _isRecruiter;
  Timestamp? _lastSeenMessageTimestamp;
  String? _lastMessageId;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      Permission.notification.request();
    }
    _determineRole().then((_) {
      setState(() {
        _initializationFuture = _initializeChat();
      });
      _setupFCMListeners();
    }).catchError((e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error determining role: $e', name: 'ChatScreen');
      setState(() {
        _isRecruiter = false;
        _initializationFuture = _initializeChat();
      });
    });
  }

  void _setupFCMListeners() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Notification opened: ${message.messageId}', name: 'ChatScreen FCM');
      if (message.data['chatId'] == widget.chatId) {
        _markMessagesAsRead();
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && message.data['chatId'] == widget.chatId && mounted) {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] App opened via notification: ${message.messageId}', name: 'ChatScreen FCM');
        _markMessagesAsRead();
      }
    });
  }

  Future<void> _determineRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] No authenticated user', name: 'ChatScreen');
      setState(() {
        _isRecruiter = false;
      });
      return;
    }
    try {
      final userDoc = await _firestore.collection('UsersIndex').doc(uid).get();
      if (!userDoc.exists) {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] No user data in UsersIndex/$uid', name: 'ChatScreen');
        setState(() {
          _isRecruiter = false;
        });
        return;
      }
      final userRole = userDoc.data()?['role'] as String?;
      if (userRole == 'recruiter') {
        final recruiterDoc = await _firestore.collection('Recruiters').doc(uid).get();
        if (!recruiterDoc.exists) {
          dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] User $uid marked as recruiter in UsersIndex but missing in Recruiters/$uid', name: 'ChatScreen');
          setState(() {
            _isRecruiter = false;
          });
          return;
        }
        setState(() {
          _isRecruiter = true;
        });
      } else if (userRole == 'seeker') {
        final seekerDoc = await _firestore.collection('Seekers').doc(uid).get();
        if (!seekerDoc.exists) {
          dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] User $uid marked as seeker in UsersIndex but missing in Seekers/$uid', name: 'ChatScreen');
          setState(() {
            _isRecruiter = false;
          });
          return;
        }
        setState(() {
          _isRecruiter = false;
        });
      } else {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Invalid role for user $uid: $userRole', name: 'ChatScreen');
        setState(() {
          _isRecruiter = false;
        });
      }
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Determined role for $uid: _isRecruiter=$_isRecruiter', name: 'ChatScreen');
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Firestore error in _determineRole: $e', name: 'ChatScreen');
      setState(() {
        _isRecruiter = false;
      });
    }
  }

  Future<void> _initializeChat() async {
    try {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Initializing chat ${widget.chatId} with recipientId: ${widget.recipientId}, jobId: ${widget.jobId}', name: 'ChatScreen');
      await Future.wait([
        _checkChatStatus(),
        _fetchChatDetails(),
      ], eagerError: true);
      if (mounted && isNewChat) {
        setState(() {
          _showInitialMessagePrompt = true;
        });
      }
      await _markMessagesAsRead();
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error initializing chat ${widget.chatId}: $e', name: 'ChatScreen');
    }
  }

  Future<void> _checkChatStatus() async {
    try {
      final messagesSnapshot = await _firestore
          .collection('Messages')
          .doc(widget.chatId)
          .collection('Chats')
          .limit(1)
          .get();
      if (mounted) {
        setState(() {
          isNewChat = messagesSnapshot.docs.isEmpty;
          dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Chat ${widget.chatId} is ${isNewChat ? 'new' : 'existing'}', name: 'ChatScreen');
        });
      }
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error checking chat status for ${widget.chatId}: $e', name: 'ChatScreen');
    }
  }

  Future<void> _fetchChatDetails() async {
    try {
      final details = await _getChatDetails();
      if (mounted) {
        setState(() {
          _chatDetails = details;
          dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Fetched chat details for ${widget.chatId}: $details', name: 'ChatScreen');
        });
      }
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error fetching chat details for ${widget.chatId}: $e', name: 'ChatScreen');
    }
  }

  Stream<QuerySnapshot> _getMessagesStream() {
    return _firestore
        .collection('Messages')
        .doc(widget.chatId)
        .collection('Chats')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>> _getChatDetails() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] No authenticated user for chat ${widget.chatId}', name: 'ChatScreen');
      return {'recipientName': 'Unknown', 'company': 'Unknown'};
    }
    String recipientName = 'Unknown';
    String company = 'Unknown';
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);
    while (retryCount < maxRetries) {
      try {
        final options = const GetOptions(source: Source.server);
        if (_isRecruiter == true) {
          final appDoc = await _firestore.collection('Applications').doc('${widget.recipientId}_${widget.jobId}').get(options);
          if (appDoc.exists) {
            final resume = appDoc.data()?['resume'] as Map<String, dynamic>? ?? {};
            recipientName = resume['name'] ?? recipientName;
            company = appDoc.data()?['company'] ?? company;
            dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Application data for ${widget.recipientId}_${widget.jobId}: ${appDoc.data()}', name: 'ChatScreen');
          }
          final seekerDoc = await _firestore.collection('UsersIndex').doc(widget.recipientId).get(options);
          if (seekerDoc.exists) {
            final data = seekerDoc.data()!;
            recipientName = data['name'] ?? data['fullName'] ?? recipientName;
            dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Seeker data from UsersIndex: $data', name: 'ChatScreen');
          }
        } else {
          final appDoc = await _firestore.collection('Applications').doc('${uid}_${widget.jobId}').get(options);
          if (appDoc.exists) {
            company = appDoc.data()?['company'] ?? 'Unknown';
            dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Fallback company from Applications: $company', name: 'ChatScreen');
          }
          final recruiterDoc = await _firestore.collection('UsersIndex').doc(widget.recipientId).get(options);
          if (recruiterDoc.exists) {
            final data = recruiterDoc.data()!;
            recipientName = data['name'] ?? data['companyName'] ?? 'Recruiter';
            dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Recruiter data from UsersIndex: $data', name: 'ChatScreen');
          }
        }
        break;
      } catch (e) {
        retryCount++;
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error fetching chat details for ${widget.chatId} (Attempt $retryCount): $e', name: 'ChatScreen', error: e);
        if (retryCount == maxRetries) {
          dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Max retries reached, using fallback values', name: 'ChatScreen');
          return {'recipientName': 'Unknown', 'company': 'Unknown'};
        }
        await Future.delayed(retryDelay * retryCount);
      }
    }
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Final recipient details for ${widget.recipientId}: name=$recipientName, company=$company', name: 'ChatScreen');
    return {
      'recipientName': recipientName,
      'company': company,
    };
  }

  Future<void> _validateAndCreateApplication(String jobId, String recruiterId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('No authenticated user');
    }
    final applicationId = '${uid}_$jobId';
    final options = const GetOptions(source: Source.server);
    final appDoc = await _firestore.collection('Applications').doc(applicationId).get(options);
    if (!appDoc.exists) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] No application found for $applicationId, attempting to create', name: 'ChatScreen');
      try {
        final jobDoc = await _firestore.collection('Recruiters').doc(recruiterId).collection('Jobs').doc(jobId).get(options);
        if (!jobDoc.exists) {
          throw Exception('Job $jobId does not exist for recruiter $recruiterId');
        }
        final jobData = jobDoc.data()!;
        final applicationData = {
          'seekerId': uid,
          'jobId': jobId,
          'recruiterId': recruiterId,
          'status': 'Applied',
          'appliedAt': FieldValue.serverTimestamp(),
          'jobTitle': jobData['title'] ?? 'Unknown',
          'company': jobData['company'] ?? 'Unknown',
          'coverLetter': '',
        };
        await _firestore.collection('Applications').doc(applicationId).set(applicationData);
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Created application $applicationId', name: 'ChatScreen');
      } catch (e) {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error creating application $applicationId: $e', name: 'ChatScreen');
        throw Exception('Failed to create application for job $jobId: $e');
      }
    } else {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Application $applicationId exists', name: 'ChatScreen');
    }
  }

  Future<void> _showOutsideNotification(String senderName, String message) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
    );
    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const notificationDetails = NotificationDetails(android: androidDetails, iOS: iOSDetails);
    await _flutterLocalNotificationsPlugin.show(
      widget.chatId.hashCode,
      'New Message from $senderName',
      message.length > 50 ? '${message.substring(0, 47)}...' : message,
      notificationDetails,
    ).catchError((e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error showing notification: $e', name: 'ChatScreen', error: e);
    });
  }

  Future<void> _sendNotification(String recipientCollection, String recipientId, String senderId, String messageText, String jobId) async {
    int retryCount = 0;
    const maxRetries = 2;
    const retryDelay = Duration(seconds: 2);
    while (retryCount < maxRetries) {
      try {
        String senderName = 'Unknown';
        String? jobTitle;
        final senderDoc = await _firestore.collection('UsersIndex').doc(senderId).get(const GetOptions(source: Source.server));
        if (senderDoc.exists) {
          final senderData = senderDoc.data()!;
          senderName = senderData['name'] ?? senderData['fullName'] ?? senderData['companyName'] ?? 'User';
        }
        final appDoc = await _firestore.collection('Applications').doc('${_isRecruiter == true ? recipientId : senderId}_$jobId').get(const GetOptions(source: Source.server));
        if (appDoc.exists) {
          jobTitle = appDoc.data()?['jobTitle'];
        }
        final recipientDoc = await _firestore.collection('UsersIndex').doc(recipientId).get(const GetOptions(source: Source.server));
        if (!recipientDoc.exists) throw Exception('Recipient $recipientId not found in UsersIndex');
        final recipientRole = recipientDoc.data()?['role'] as String?;
        if (recipientCollection == 'SeekerNotifications' && recipientRole != 'seeker') throw Exception('Recipient $recipientId is not a valid seeker');
        if (recipientCollection == 'RecruiterNotifications' && recipientRole != 'recruiter') throw Exception('Recipient $recipientId is not a valid recruiter');
        if (!appDoc.exists) throw Exception('No application found for ${_isRecruiter == true ? recipientId : senderId}_$jobId');
        final message = jobTitle == null || jobTitle == 'Unknown' ? 'New message from $senderName' : 'New message from $senderName for $jobTitle';
        final notificationId = '${senderId}_${jobId}_${DateTime.now().millisecondsSinceEpoch}';
        final notificationData = {
          'notificationId': notificationId,
          'to': recipientId,
          'from': senderId,
          'message': message,
          'type': 'message',
          'jobId': jobId,
          'seekerId': _isRecruiter == true ? recipientId : senderId,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'chatId': widget.chatId,
          'jobTitle': jobTitle ?? 'Unknown',
        };
        await _firestore
            .collection(recipientCollection)
            .doc(recipientId)
            .collection('Notifications')
            .doc(notificationId)
            .set(notificationData);
        final recipientFcmToken = await _getFcmToken(recipientId);
        if (recipientFcmToken != null) {
          await _callSendNotificationFunction(recipientFcmToken, message, notificationId, widget.chatId, jobId, _isRecruiter == true ? recipientId : senderId, senderId, jobTitle ?? 'Unknown');
        }
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Sent notification to $recipientCollection/$recipientId, attempt ${retryCount + 1}', name: 'ChatScreen');
        return;
      } catch (e) {
        retryCount++;
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error sending notification to $recipientCollection/$recipientId (Attempt $retryCount): $e', name: 'ChatScreen', error: e);
        if (retryCount == maxRetries) {
          dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Max retries reached for notification to $recipientCollection/$recipientId', name: 'ChatScreen');
        }
        await Future.delayed(retryDelay * retryCount);
      }
    }
  }

  Future<String?> _getFcmToken(String userId) async {
    try {
      final userDoc = await _firestore.collection('UsersIndex').doc(userId).get(const GetOptions(source: Source.server));
      if (userDoc.exists) {
        final fcmToken = userDoc.data()?['fcmToken'] as String?;
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Fetched FCM token for $userId: $fcmToken', name: 'ChatScreen');
        return fcmToken;
      }
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] No user data found for $userId in UsersIndex', name: 'ChatScreen');
      return null;
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error fetching FCM token for $userId: $e', name: 'ChatScreen', error: e);
      return null;
    }
  }

  Future<void> _callSendNotificationFunction(String recipientFcmToken, String message, String notificationId, String chatId, String jobId, String seekerId, String fromId, String jobTitle) async {
    try {
      final appCheckToken = await FirebaseAppCheck.instance.getToken(); // Fetch token if required by function
      final integrityToken = await _getPlayIntegrityToken();

      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('sendNotification');
      final response = await callable.call({
        'token': recipientFcmToken,
        'title': 'New Message',
        'body': message,
        'data': {
          'notificationId': notificationId,
          'chatId': chatId,
          'jobId': jobId,
          'seekerId': seekerId,
          'from': fromId,
          'type': 'message',
          'recipientId': widget.recipientId,
          'jobTitle': jobTitle,
          'message': message,
        },
        'recipientId': widget.recipientId,
        'recipientRole': _isRecruiter == true ? 'seeker' : 'recruiter',
        'integrityToken': integrityToken,
        'appCheckToken': appCheckToken ?? '', // Safe access with fallback
      });
      if (response.data['success'] == true) {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Cloud Function sendNotification called successfully for $recipientFcmToken', name: 'ChatScreen');
      } else {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Cloud Function sendNotification failed: ${response.data}', name: 'ChatScreen');
      }
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error calling sendNotification Cloud Function: $e', name: 'ChatScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send notification: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _getPlayIntegrityToken() async {
    try {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Using placeholder Play Integrity token for development', name: 'ChatScreen');
      return 'dev-integrity-token'; // Replace with real implementation using play_integrity_flutter
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error getting Play Integrity token: $e', name: 'ChatScreen');
      return null;
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Empty message not sent in chat ${widget.chatId}', name: 'ChatScreen');
      return;
    }
    final recipientCollection = _isRecruiter == true ? 'SeekerNotifications' : 'RecruiterNotifications';
    final senderId = _auth.currentUser?.uid;
    if (senderId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No authenticated user. Please log in.'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    try {
      if (recipientCollection == 'RecruiterNotifications') {
        await _validateAndCreateApplication(widget.jobId, widget.recipientId);
      }
      await _authService.sendMessage(widget.recipientId, widget.jobId, message, status: 'sent');
      _messageController.clear();
      if (mounted) {
        setState(() {
          isNewChat = false;
          _showInitialMessagePrompt = false;
        });
      }
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Sent message in chat ${widget.chatId} for job ${widget.jobId}: $message', name: 'ChatScreen');
      _sendNotification(recipientCollection, widget.recipientId, senderId, message, widget.jobId).catchError((e) {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Notification failed but message sent: $e', name: 'ChatScreen', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message sent, but notification delivery failed.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error sending message in chat ${widget.chatId}: $e', name: 'ChatScreen', error: e);
      String errorMessage = 'Failed to send message';
      if (e is FirebaseException && e.code == 'permission-denied') {
        errorMessage = 'Permission denied. Ensure your account is properly set up as a ${_isRecruiter == true ? 'recruiter' : 'seeker'} and the recipient is a valid ${recipientCollection == 'SeekerNotifications' ? 'seeker' : 'recruiter'}.';
      } else if (e.toString().contains('No application found')) {
        errorMessage = 'You must apply to the job before messaging the ${_isRecruiter == true ? 'seeker' : 'recruiter'}.';
      } else if (e.toString().contains('Failed to create application')) {
        errorMessage = 'Failed to create application. Please try applying again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendInitialMessage() async {
    final initialMessage = 'Hello, let’s discuss about application for "${_chatDetails?['company'] ?? widget.jobId}"!';
    final recipientCollection = _isRecruiter == true ? 'SeekerNotifications' : 'RecruiterNotifications';
    final senderId = _auth.currentUser?.uid;
    if (senderId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No authenticated user. Please log in.'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    try {
      if (recipientCollection == 'RecruiterNotifications') {
        await _validateAndCreateApplication(widget.jobId, widget.recipientId);
      }
      await _authService.sendMessage(widget.recipientId, widget.jobId, initialMessage, status: 'sent');
      _messageController.clear();
      if (mounted) {
        setState(() {
          isNewChat = false;
          _showInitialMessagePrompt = false;
        });
      }
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Sent initial message in chat ${widget.chatId} for job ${widget.jobId}', name: 'ChatScreen');
      _sendNotification(recipientCollection, widget.recipientId, senderId, initialMessage, widget.jobId).catchError((e) {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Notification failed but initial message sent: $e', name: 'ChatScreen', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Initial message sent, but notification delivery failed.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Initial message sent successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error sending initial message in chat ${widget.chatId}: $e', name: 'ChatScreen', error: e);
      String errorMessage = 'Failed to send initial message';
      if (e is FirebaseException && e.code == 'permission-denied') {
        errorMessage = 'Permission denied. Ensure your account is properly set up as a ${_isRecruiter == true ? 'recruiter' : 'seeker'} and the recipient is a valid ${recipientCollection == 'SeekerNotifications' ? 'seeker' : 'recruiter'}.';
      } else if (e.toString().contains('No application found')) {
        errorMessage = 'You must apply to the job before messaging the ${_isRecruiter == true ? 'seeker' : 'recruiter'}.';
      } else if (e.toString().contains('Failed to create application')) {
        errorMessage = 'Failed to create application. Please try applying again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markMessagesAsReceived() async {
    try {
      final batch = _firestore.batch();
      final messages = await _firestore
          .collection('Messages')
          .doc(widget.chatId)
          .collection('Chats')
          .where('recipientId', isEqualTo: _auth.currentUser?.uid)
          .where('status', isEqualTo: 'sent')
          .get();
      for (var doc in messages.docs) {
        batch.update(doc.reference, {'status': 'received'});
      }
      await batch.commit();
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Marked messages as received in chat ${widget.chatId}', name: 'ChatScreen');
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error marking messages as received: $e', name: 'ChatScreen', error: e);
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final batch = _firestore.batch();
      final messages = await _firestore
          .collection('Messages')
          .doc(widget.chatId)
          .collection('Chats')
          .where('recipientId', isEqualTo: _auth.currentUser?.uid)
          .where('status', isNotEqualTo: 'read')
          .get();
      for (var doc in messages.docs) {
        batch.update(doc.reference, {'status': 'read'});
        final messageData = doc.data();
        _lastSeenMessageTimestamp = messageData['timestamp'] as Timestamp?;
      }
      await batch.commit();
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Marked messages as read in chat ${widget.chatId}', name: 'ChatScreen');
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error marking messages as read: $e', name: 'ChatScreen', error: e);
    }
  }

  Widget _getTickIcon(String status) {
    switch (status) {
      case 'sent':
        return Icon(Icons.check, color: Colors.grey, size: 16.sp);
      case 'received':
        return Icon(Icons.done_all, color: Colors.grey, size: 16.sp);
      case 'read':
        return Icon(Icons.done_all, color: Colors.blue, size: 16.sp);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: FutureBuilder<void>(
              future: _initializationFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting || _isRecruiter == null || _chatDetails == null) {
                  return Text(
                    widget.recipientId,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16.sp),
                    overflow: TextOverflow.ellipsis,
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    widget.recipientId,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16.sp),
                    overflow: TextOverflow.ellipsis,
                  );
                }
                return Text(
                  _isRecruiter! ? _chatDetails!['recipientName'] : _chatDetails!['company'],
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16.sp),
                  overflow: TextOverflow.ellipsis,
                );
              },
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
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: _getMessagesStream(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error loading messages for chat ${widget.chatId}: ${snapshot.error}', name: 'ChatScreen');
                          return Center(
                            child: Text(
                              'Unable to load messages. Please check your permissions or try again.',
                              style: TextStyle(color: Colors.red, fontSize: 16.sp),
                            ),
                          );
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final messages = snapshot.data?.docs ?? [];
                        if (messages.isNotEmpty && messages.first.id != _lastMessageId) {
                          final latestMessage = messages.first.data() as Map<String, dynamic>;
                          final latestTimestamp = latestMessage['timestamp'] as Timestamp?;
                          _lastMessageId = messages.first.id;
                          if (latestMessage['senderId'] != _auth.currentUser?.uid) {
                            final senderName = _isRecruiter == true ? (_chatDetails?['recipientName'] as String?) ?? 'User' : (_chatDetails?['company'] as String?) ?? 'Recruiter';
                            _showOutsideNotification(senderName, latestMessage['message'] ?? 'New message');
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'New message from $senderName: ${latestMessage['message'].toString().length > 30 ? '${latestMessage['message'].toString().substring(0, 27)}...' : latestMessage['message']}',
                                    ),
                                    backgroundColor: Colors.teal,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            });
                            _markMessagesAsReceived();
                          }
                          if (latestTimestamp != null && (_lastSeenMessageTimestamp == null || latestTimestamp.compareTo(_lastSeenMessageTimestamp!) > 0)) {
                            _lastSeenMessageTimestamp = latestTimestamp;
                            _markMessagesAsRead();
                          }
                        }
                        return ListView.builder(
                          reverse: true,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final messageData = messages[index].data() as Map<String, dynamic>;
                            final isSender = messageData['senderId'] == _auth.currentUser?.uid;
                            late final status = messageData['status'] ?? 'sent';
                            return AnimatedListItem(child: Container(
                              margin: EdgeInsets.symmetric(vertical: 5.h, horizontal: 10.w),
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(
                                color: isSender ? Colors.teal.shade100 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Column(
                                crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    messageData['message'] ?? '',
                                    style: TextStyle(fontSize: 16.sp),
                                  ),
                                  SizedBox(height: 5.h),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        messageData['timestamp'] != null
                                            ? DateFormat('MMM d, h:mm a').format((messageData['timestamp'] as Timestamp).toDate())
                                            : 'Unknown time',
                                        style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                                      ),
                                      if (isSender) SizedBox(width: 4.w),
                                      if (isSender) _getTickIcon(status),
                                    ],
                                  ),
                                ],
                              ),
                            ));
                          },
                        );
                      },
                    ),
                    if (_showInitialMessagePrompt && isNewChat)
                      Center(
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          color: Colors.white.withOpacity(0.9),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Start a new chat with a default message?',
                                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 10.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: _sendInitialMessage,
                                    child: Text('Yes', style: TextStyle(fontSize: 14.sp)),
                                  ),
                                  SizedBox(width: 10.w),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _showInitialMessagePrompt = false;
                                      });
                                    },
                                    child: Text('No', style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
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
                    AnimatedScaleButton(
                      onPressed: _sendMessage,
                      child: Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.teal,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4.r,
                              offset: const Offset(0, 2),
                            ),
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
        );
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

class AnimatedScaleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;

  const AnimatedScaleButton({required this.onPressed, required this.child, super.key});

  @override
  AnimatedScaleButtonState createState() => AnimatedScaleButtonState();
}

class AnimatedScaleButtonState extends State<AnimatedScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
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