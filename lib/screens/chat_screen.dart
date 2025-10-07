import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:developer' as dev;
import '../services/auth_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart'; // ADDED: For Cloud Function calls

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
    _determineRole().then((_) {
      setState(() {
        _initializationFuture = _initializeChat();
      });
      _setupFCMListeners();
    }).catchError((e) {
      dev.log('[2025-10-07 20:06 IST] Error determining role: $e', name: 'ChatScreen');
      setState(() {
        _isRecruiter = false;
        _initializationFuture = _initializeChat();
      });
    });
  }

  void _setupFCMListeners() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      dev.log('[2025-10-07 20:06 IST] Notification opened: ${message.messageId}', name: 'ChatScreen FCM');
      if (message.data['chatId'] == widget.chatId) {
        _markMessagesAsRead();
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && message.data['chatId'] == widget.chatId) {
        dev.log('[2025-10-07 20:06 IST] App opened via notification: ${message.messageId}', name: 'ChatScreen FCM');
        _markMessagesAsRead();
      }
    });
  }

  Future<void> _determineRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      dev.log('[2025-10-07 20:06 IST] No authenticated user', name: 'ChatScreen');
      setState(() {
        _isRecruiter = false;
      });
      return;
    }
    try {
      final userDoc = await _firestore.collection('UsersIndex').doc(uid).get();
      if (!userDoc.exists) {
        dev.log('[2025-10-07 20:06 IST] No user data in UsersIndex/$uid', name: 'ChatScreen');
        setState(() {
          _isRecruiter = false;
        });
        return;
      }
      final userRole = userDoc.data()?['role'] as String?;
      if (userRole == 'recruiter') {
        final recruiterDoc = await _firestore.collection('Recruiters').doc(uid).get();
        if (!recruiterDoc.exists) {
          dev.log('[2025-10-07 20:06 IST] User $uid marked as recruiter in UsersIndex but missing in Recruiters/$uid', name: 'ChatScreen');
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
          dev.log('[2025-10-07 20:06 IST] User $uid marked as seeker in UsersIndex but missing in Seekers/$uid', name: 'ChatScreen');
          setState(() {
            _isRecruiter = false;
          });
          return;
        }
        setState(() {
          _isRecruiter = false;
        });
      } else {
        dev.log('[2025-10-07 20:06 IST] Invalid role for user $uid: $userRole', name: 'ChatScreen');
        setState(() {
          _isRecruiter = false;
        });
      }
      dev.log('[2025-10-07 20:06 IST] Determined role for $uid: _isRecruiter=$_isRecruiter', name: 'ChatScreen');
    } catch (e) {
      dev.log('[2025-10-07 20:06 IST] Firestore error in _determineRole: $e', name: 'ChatScreen');
      setState(() {
        _isRecruiter = false;
      });
    }
  }

  Future<void> _initializeChat() async {
    try {
      dev.log('[2025-10-07 20:06 IST] Initializing chat ${widget.chatId} with recipientId: ${widget.recipientId}, jobId: ${widget.jobId}', name: 'ChatScreen');
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
      dev.log('[2025-10-07 20:06 IST] Error initializing chat ${widget.chatId}: $e', name: 'ChatScreen');
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
          dev.log('[2025-10-07 20:06 IST] Chat ${widget.chatId} is ${isNewChat ? 'new' : 'existing'}', name: 'ChatScreen');
        });
      }
    } catch (e) {
      dev.log('[2025-10-07 20:06 IST] Error checking chat status for ${widget.chatId}: $e', name: 'ChatScreen');
    }
  }

  Future<void> _fetchChatDetails() async {
    try {
      final details = await _getChatDetails();
      if (mounted) {
        setState(() {
          _chatDetails = details;
          dev.log('[2025-10-07 20:06 IST] Fetched chat details for ${widget.chatId}: $details', name: 'ChatScreen');
        });
      }
    } catch (e) {
      dev.log('[2025-10-07 20:06 IST] Error fetching chat details for ${widget.chatId}: $e', name: 'ChatScreen');
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
      dev.log('[2025-10-07 20:06 IST] No authenticated user for chat ${widget.chatId}', name: 'ChatScreen');
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
            dev.log('[2025-10-07 20:06 IST] Application data for ${widget.recipientId}_${widget.jobId}: ${appDoc.data()}', name: 'ChatScreen');
          } else {
            dev.log('[2025-10-07 20:06 IST] No application data found for ${widget.recipientId}_${widget.jobId}', name: 'ChatScreen');
          }
          final seekerDoc = await _firestore.collection('UsersIndex').doc(widget.recipientId).get(options);
          if (seekerDoc.exists) {
            final data = seekerDoc.data()!;
            recipientName = data['name'] ?? data['fullName'] ?? recipientName;
            dev.log('[2025-10-07 20:06 IST] Seeker data from UsersIndex: $data', name: 'ChatScreen');
          } else {
            dev.log('[2025-10-07 20:06 IST] No seeker data found in UsersIndex for ${widget.recipientId}', name: 'ChatScreen');
          }
        } else {
          final appDoc = await _firestore.collection('Applications').doc('${uid}_${widget.jobId}').get(options);
          if (appDoc.exists) {
            company = appDoc.data()?['company'] ?? 'Unknown';
            dev.log('[2025-10-07 20:06 IST] Fallback company from Applications: $company', name: 'ChatScreen');
          } else {
            dev.log('[2025-10-07 20:06 IST] No application data found for ${uid}_${widget.jobId}', name: 'ChatScreen');
          }
        }
        break;
      } catch (e) {
        retryCount++;
        dev.log('[2025-10-07 20:06 IST] Error fetching chat details for ${widget.chatId} (Attempt $retryCount): $e', name: 'ChatScreen');
        if (retryCount == maxRetries) {
          dev.log('[2025-10-07 20:06 IST] Max retries reached, using fallback values', name: 'ChatScreen');
          return {'recipientName': 'Unknown', 'company': 'Unknown'};
        }
        await Future.delayed(retryDelay * retryCount);
      }
    }
    dev.log('[2025-10-07 20:06 IST] Final recipient details for ${widget.recipientId}: name=$recipientName, company=$company', name: 'ChatScreen');
    return {
      'recipientName': recipientName,
      'company': company,
    };
  }

  Future<void> _showOutsideNotification(String senderName, String message) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _flutterLocalNotificationsPlugin.show(
      widget.chatId.hashCode,
      'New Message from $senderName',
      message.length > 50 ? '${message.substring(0, 47)}...' : message,
      notificationDetails,
    );
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
      dev.log('[2025-10-07 20:06 IST] No application found for $applicationId, attempting to create', name: 'ChatScreen');
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
        dev.log('[2025-10-07 20:06 IST] Created application $applicationId', name: 'ChatScreen');
      } catch (e) {
        dev.log('[2025-10-07 20:06 IST] Error creating application $applicationId: $e', name: 'ChatScreen');
        throw Exception('Failed to create application for job $jobId: $e');
      }
    } else {
      dev.log('[2025-10-07 20:06 IST] Application $applicationId exists', name: 'ChatScreen');
    }
  }

  Future<void> _sendNotification(String recipientCollection, String recipientId, String senderId, String messageText, String jobId) async {
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);
    while (retryCount < maxRetries) {
      try {
        // Validate sender role
        if (recipientCollection == 'SeekerNotifications') {
          final recruiterDoc = await _firestore.collection('Recruiters').doc(senderId).get(const GetOptions(source: Source.server));
          if (!recruiterDoc.exists) {
            throw Exception('Sender is not a valid recruiter in Recruiters/$senderId');
          }
          final appDoc = await _firestore.collection('Applications').doc('${recipientId}_$jobId').get(const GetOptions(source: Source.server));
          if (!appDoc.exists) {
            throw Exception('No application found for recipient $recipientId and job $jobId');
          }
        } else if (recipientCollection == 'RecruiterNotifications') {
          final seekerDoc = await _firestore.collection('Seekers').doc(senderId).get(const GetOptions(source: Source.server));
          if (!seekerDoc.exists) {
            throw Exception('Sender is not a valid seeker in Seekers/$senderId');
          }
          final appDoc = await _firestore.collection('Applications').doc('${senderId}_$jobId').get(const GetOptions(source: Source.server));
          if (!appDoc.exists) {
            throw Exception('No application found for sender $senderId and job $jobId');
          }
        } else {
          throw Exception('Invalid recipient collection: $recipientCollection');
        }

        // Validate recipient
        final recipientDoc = await _firestore.collection('UsersIndex').doc(recipientId).get(const GetOptions(source: Source.server));
        if (!recipientDoc.exists) {
          throw Exception('Invalid recipient ID: $recipientId in UsersIndex');
        }
        final recipientRole = recipientDoc.data()?['role'] as String?;
        if (recipientCollection == 'SeekerNotifications' && recipientRole != 'seeker') {
          throw Exception('Recipient $recipientId is not a valid seeker for SeekerNotifications, found role: $recipientRole');
        }
        if (recipientCollection == 'RecruiterNotifications' && recipientRole != 'recruiter') {
          throw Exception('Recipient $recipientId is not a valid recruiter for RecruiterNotifications, found role: $recipientRole');
        }

        // Fetch sender details and job title
        String senderName = 'Unknown';
        String? jobTitle;
        final appDoc = await _firestore.collection('Applications').doc('${recipientCollection == 'RecruiterNotifications' ? senderId : recipientId}_$jobId').get(const GetOptions(source: Source.server));
        if (appDoc.exists) {
          jobTitle = appDoc.data()?['jobTitle'];
          dev.log('[2025-10-07 20:06 IST] Fetched job title from Applications/${recipientCollection == 'RecruiterNotifications' ? senderId : recipientId}_$jobId: $jobTitle', name: 'ChatScreen');
        } else {
          dev.log('[2025-10-07 20:06 IST] No application found for ${recipientCollection == 'RecruiterNotifications' ? senderId : recipientId}_$jobId when fetching job title', name: 'ChatScreen');
        }

        if (recipientCollection == 'SeekerNotifications') {
          try {
            final recruiterDoc = await _firestore.collection('Recruiters').doc(senderId).get(const GetOptions(source: Source.server));
            if (recruiterDoc.exists) {
              senderName = recruiterDoc.data()?['companyName'] ?? 'Recruiter';
              dev.log('[2025-10-07 20:06 IST] Fetched company name for $senderId from Recruiters: $senderName', name: 'ChatScreen');
            } else if (appDoc.exists) {
              senderName = appDoc.data()?['company'] ?? 'Recruiter';
              dev.log('[2025-10-07 20:06 IST] Fetched company name from Applications/${recipientId}_$jobId: $senderName', name: 'ChatScreen');
            } else {
              dev.log('[2025-10-07 20:06 IST] No recruiter or application data found for $senderId, using fallback name: $senderName', name: 'ChatScreen');
            }
          } catch (e) {
            dev.log('[2025-10-07 20:06 IST] Error fetching Recruiters/$senderId: $e', name: 'ChatScreen', error: e);
            if (appDoc.exists) {
              senderName = appDoc.data()?['company'] ?? 'Recruiter';
              dev.log('[2025-10-07 20:06 IST] Fetched company name from Applications/${recipientId}_$jobId: $senderName', name: 'ChatScreen');
            }
          }
        } else if (recipientCollection == 'RecruiterNotifications') {
          try {
            if (appDoc.exists) {
              senderName = appDoc.data()?['resume']?['name'] ?? 'Seeker';
              dev.log('[2025-10-07 20:06 IST] Fetched seeker name from Applications/${senderId}_$jobId: $senderName (Resume data: ${appDoc.data()?['resume']})', name: 'ChatScreen');
            }
            if (senderName == 'Seeker' || senderName == 'Unknown') {
              final seekerDoc = await _firestore.collection('UsersIndex').doc(senderId).get(const GetOptions(source: Source.server));
              if (seekerDoc.exists) {
                final data = seekerDoc.data();
                senderName = data?['name'] ?? data?['fullName'] ?? 'Seeker';
                dev.log('[2025-10-07 20:06 IST] Fetched seeker name for $senderId from UsersIndex: $senderName (Data: $data)', name: 'ChatScreen');
              } else {
                dev.log('[2025-10-07 20:06 IST] No seeker data found for $senderId in UsersIndex', name: 'ChatScreen');
              }
            }
          } catch (e) {
            dev.log('[2025-10-07 20:06 IST] Error fetching name for $senderId from Applications or UsersIndex: $e', name: 'ChatScreen', error: e);
            final seekerDoc = await _firestore.collection('UsersIndex').doc(senderId).get(const GetOptions(source: Source.server));
            if (seekerDoc.exists) {
              final data = seekerDoc.data();
              senderName = data?['name'] ?? data?['fullName'] ?? 'Seeker';
              dev.log('[2025-10-07 20:06 IST] Fetched seeker name for $senderId from UsersIndex (fallback): $senderName (Data: $data)', name: 'ChatScreen');
            } else {
              dev.log('[2025-10-07 20:06 IST] No seeker data found for $senderId in UsersIndex (fallback)', name: 'ChatScreen');
            }
          }
        }

        // Construct message
        String message;
        if (jobTitle == null || jobTitle == 'Unknown') {
          message = 'New message from $senderName';
          dev.log('[2025-10-07 20:06 IST] Omitted job title from message due to unknown value: $jobTitle', name: 'ChatScreen');
        } else {
          message = 'New message from $senderName for $jobTitle';
          dev.log('[2025-10-07 20:06 IST] Included job title in message: $jobTitle', name: 'ChatScreen');
        }

        // Store notification in Firestore
        final notificationId = '${senderId}_${jobId}_${DateTime.now().millisecondsSinceEpoch}';
        final notificationData = {
          'notificationId': notificationId,
          'to': recipientId,
          'from': senderId,
          'message': message,
          'type': 'message',
          'jobId': jobId,
          'seekerId': recipientCollection == 'RecruiterNotifications' ? senderId : recipientId,
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
        dev.log('[2025-10-07 20:06 IST] Stored notification $notificationId in $recipientCollection/$recipientId/Notifications: $notificationData', name: 'ChatScreen');

        // Send FCM push notification via Cloud Function
        final recipientFcmToken = await _getFcmToken(recipientId);
        if (recipientFcmToken != null) {
          await _callSendNotificationFunction(
            recipientFcmToken,
            message,
            notificationId,
            widget.chatId,
            jobId,
            recipientCollection == 'RecruiterNotifications' ? senderId : recipientId,
            senderId,
            jobTitle ?? 'Unknown',
          );
          dev.log('[2025-10-07 20:06 IST] Sent FCM notification to $recipientId for $notificationId via Cloud Function', name: 'ChatScreen');
        } else {
          dev.log('[2025-10-07 20:06 IST] No FCM token found for $recipientId', name: 'ChatScreen');
        }

        dev.log('[2025-10-07 20:06 IST] Validated and sent notification to $recipientCollection/$recipientId, attempt ${retryCount + 1}', name: 'ChatScreen');
        return;
      } catch (e) {
        retryCount++;
        dev.log('[2025-10-07 20:06 IST] Error sending notification to $recipientCollection/$recipientId (Attempt $retryCount): $e', name: 'ChatScreen', error: e);
        if (retryCount == maxRetries) {
          dev.log('[2025-10-07 20:06 IST] Max retries reached for notification to $recipientCollection/$recipientId', name: 'ChatScreen');
          throw Exception('Failed to send notification after $maxRetries attempts: $e');
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
        dev.log('[2025-10-07 20:06 IST] Fetched FCM token for $userId: $fcmToken', name: 'ChatScreen');
        return fcmToken;
      } else {
        dev.log('[2025-10-07 20:06 IST] No user data found for $userId in UsersIndex', name: 'ChatScreen');
        return null;
      }
    } catch (e) {
      dev.log('[2025-10-07 20:06 IST] Error fetching FCM token for $userId: $e', name: 'ChatScreen', error: e);
      return null;
    }
  }

  Future<void> _callSendNotificationFunction(
    String recipientFcmToken,
    String message,
    String notificationId,
    String chatId,
    String jobId,
    String seekerId,
    String fromId,
    String jobTitle,
  ) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendNotification');
      final response = await callable.call({
        'token': recipientFcmToken,
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
      });
      if (response.data['success'] == true) {
        dev.log('[2025-10-07 20:06 IST] Cloud Function sendNotification called successfully for $recipientFcmToken', name: 'ChatScreen');
      } else {
        dev.log('[2025-10-07 20:06 IST] Cloud Function sendNotification failed: ${response.data}', name: 'ChatScreen');
      }
    } catch (e) {
      dev.log('[2025-10-07 20:06 IST] Error calling sendNotification Cloud Function: $e', name: 'ChatScreen', error: e);
      throw Exception('Failed to send notification via Cloud Function: $e');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      dev.log('[2025-10-07 20:06 IST] Empty message not sent in chat ${widget.chatId}', name: 'ChatScreen');
      return;
    }
    final recipientCollection = _isRecruiter == true ? 'SeekerNotifications' : 'RecruiterNotifications';
    try {
      final senderId = _auth.currentUser?.uid;
      if (senderId == null) {
        throw Exception('No authenticated user');
      }
      if (recipientCollection == 'RecruiterNotifications') {
        await _validateAndCreateApplication(widget.jobId, widget.recipientId);
      }
      await _authService.sendMessage(widget.recipientId, widget.jobId, message, status: 'sent');
      await _sendNotification(recipientCollection, widget.recipientId, senderId, message, widget.jobId);
      _messageController.clear();
      if (mounted) {
        setState(() {
          isNewChat = false;
          _showInitialMessagePrompt = false;
        });
      }
      dev.log('[2025-10-07 20:06 IST] Sent message in chat ${widget.chatId} for job ${widget.jobId}: $message', name: 'ChatScreen');
    } catch (e) {
      dev.log('[2025-10-07 20:06 IST] Error sending message in chat ${widget.chatId}: $e', name: 'ChatScreen', error: e);
      String errorMessage = 'Failed to send message';
      if (e is FirebaseException && e.code == 'permission-denied') {
        errorMessage = 'Permission denied. Ensure your account is properly set up as a ${_isRecruiter == true ? 'recruiter' : 'seeker'} and the recipient is a valid ${recipientCollection == 'SeekerNotifications' ? 'seeker' : 'recruiter'}.';
      } else if (e.toString().contains('No application found')) {
        errorMessage = 'You must apply to the job before messaging the ${_isRecruiter == true ? 'seeker' : 'recruiter'}.';
      } else if (e.toString().contains('Sender is not a valid seeker')) {
        errorMessage = 'Your account is not recognized as a valid seeker. Please contact support.';
      } else if (e.toString().contains('Sender is not a valid recruiter')) {
        errorMessage = 'Your account is not recognized as a valid recruiter. Please contact support.';
      } else if (e.toString().contains('Recipient is not a valid recruiter')) {
        errorMessage = 'The recipient is not a valid recruiter. Please try again later.';
      } else if (e.toString().contains('Recipient is not a valid seeker')) {
        errorMessage = 'The recipient is not a valid seeker. Please try again later.';
      } else if (e.toString().contains('Failed to create application')) {
        errorMessage = 'Failed to create application. Please try applying again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _sendInitialMessage() async {
    final initialMessage = 'Hello, let’s discuss about application for "${_chatDetails?['company'] ?? widget.jobId}"!';
    final recipientCollection = _isRecruiter == true ? 'SeekerNotifications' : 'RecruiterNotifications';
    try {
      final senderId = _auth.currentUser?.uid;
      if (senderId == null) {
        throw Exception('No authenticated user');
      }
      if (recipientCollection == 'RecruiterNotifications') {
        await _validateAndCreateApplication(widget.jobId, widget.recipientId);
      }
      await _authService.sendMessage(widget.recipientId, widget.jobId, initialMessage, status: 'sent');
      await _sendNotification(recipientCollection, widget.recipientId, senderId, initialMessage, widget.jobId);
      if (mounted) {
        setState(() {
          isNewChat = false;
          _showInitialMessagePrompt = false;
        });
      }
      dev.log('[2025-10-07 20:06 IST] Sent initial message in chat ${widget.chatId} for job ${widget.jobId}', name: 'ChatScreen');
    } catch (e) {
      dev.log('[2025-10-07 20:06 IST] Error sending initial message in chat ${widget.chatId}: $e', name: 'ChatScreen', error: e);
      String errorMessage = 'Failed to send initial message';
      if (e is FirebaseException && e.code == 'permission-denied') {
        errorMessage = 'Permission denied. Ensure your account is properly set up as a ${_isRecruiter == true ? 'recruiter' : 'seeker'} and the recipient is a valid ${recipientCollection == 'SeekerNotifications' ? 'seeker' : 'recruiter'}.';
      } else if (e.toString().contains('No application found')) {
        errorMessage = 'You must apply to the job before messaging the ${_isRecruiter == true ? 'seeker' : 'recruiter'}.';
      } else if (e.toString().contains('Sender is not a valid seeker')) {
        errorMessage = 'Your account is not recognized as a valid seeker. Please contact support.';
      } else if (e.toString().contains('Sender is not a valid recruiter')) {
        errorMessage = 'Your account is not recognized as a valid recruiter. Please contact support.';
      } else if (e.toString().contains('Recipient is not a valid recruiter')) {
        errorMessage = 'The recipient is not a valid recruiter. Please try again later.';
      } else if (e.toString().contains('Recipient is not a valid seeker')) {
        errorMessage = 'The recipient is not a valid seeker. Please try again later.';
      } else if (e.toString().contains('Failed to create application')) {
        errorMessage = 'Failed to create application. Please try applying again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _markMessagesAsReceived() async {
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
  }

  Future<void> _markMessagesAsRead() async {
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
                          dev.log('[2025-10-07 20:06 IST] Error loading messages for chat ${widget.chatId}: ${snapshot.error}', name: 'ChatScreen');
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
                            final status = messageData['status'] ?? 'sent';
                            return AnimatedListItem(
                              child: Container(
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
                              ),
                            );
                          },
                        );
                      },
                    ),
                    if (_showInitialMessagePrompt && isNewChat)
                      Center(
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          color: Colors.white.withValues(alpha: 0.9),
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
                              color: Colors.black.withValues(alpha: 0.2),
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