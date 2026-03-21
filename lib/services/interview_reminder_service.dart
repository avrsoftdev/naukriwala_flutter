import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class InterviewReminderService {
  static final InterviewReminderService _instance = InterviewReminderService._internal();
  factory InterviewReminderService() => _instance;
  InterviewReminderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  Timer? _reminderCheckTimer;
  
  // Track sent reminders to prevent duplicates
  final Set<String> _sentReminders = <String>{};
  
  // Channel ID for interview reminders
  static const String _channelId = 'interview_reminders';
  static const String _channelName = 'Interview Reminders';
  static const String _channelDescription = 'Notifications for upcoming interviews';

  /// Initialize the interview reminder service
  Future<void> initialize() async {
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Initializing Interview Reminder Service', name: 'InterviewReminderService');
    
    // Initialize local notifications for interview reminders
    await _initializeLocalNotifications();
    
    // Start the reminder check timer
    _startReminderCheckTimer();
    
    // Set up FCM for remote notifications
    await _setupFCM();
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Setup FCM for remote interview reminders
  Future<void> _setupFCM() async {
    try {
      // Request permission for iOS
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] FCM permission granted for interview reminders', name: 'InterviewReminderService');
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error requesting FCM permission: $e', name: 'InterviewReminderService', error: e);
    }
  }

  /// Start timer to check for upcoming interviews every 15 minutes
  void _startReminderCheckTimer() {
    _reminderCheckTimer?.cancel();
    _reminderCheckTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _checkAndScheduleReminders();
    });
    
    // Also check immediately on start
    _checkAndScheduleReminders();
    
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Started interview reminder check timer (15-minute intervals)', name: 'InterviewReminderService');
  }

  /// Check for upcoming interviews and schedule reminders
  Future<void> _checkAndScheduleReminders() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      // Check both seeker and recruiter interviews
      await Future.wait([
        _checkSeekerInterviews(user.uid),
        _checkRecruiterInterviews(user.uid),
      ]);
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error checking interview reminders: $e', name: 'InterviewReminderService', error: e);
    }
  }

  /// Check seeker's upcoming interviews
  Future<void> _checkSeekerInterviews(String uid) async {
    final now = DateTime.now();
    final twoHoursFromNow = now.add(const Duration(hours: 2));
    final sixHoursFromNow = now.add(const Duration(hours: 6));
    
    final applications = await _firestore
        .collection('Applications')
        .where('seekerId', isEqualTo: uid)
        .where('status', isEqualTo: 'Interview Scheduled')
        .where('interviewDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('interviewDate', isLessThanOrEqualTo: Timestamp.fromDate(sixHoursFromNow))
        .get();
    
    for (final doc in applications.docs) {
      final data = doc.data();
      final interviewDate = (data['interviewDate'] as Timestamp?)?.toDate();
      
      if (interviewDate != null) {
        // Schedule reminder for 2 hours before interview
        final reminderTime = interviewDate.subtract(const Duration(hours: 2));
        
        // Only schedule if reminder time is in the future and within next 6 hours
        if (reminderTime.isAfter(now) && reminderTime.isBefore(sixHoursFromNow)) {
          await _scheduleLocalReminder(
            interviewId: doc.id,
            jobTitle: data['jobTitle'] ?? 'Job Interview',
            companyName: data['company'] ?? 'Company',
            interviewTime: interviewDate,
            reminderTime: reminderTime,
            isRecruiter: false,
            seekerId: uid,
            recruiterId: data['recruiterId'] ?? '',
          );
        }
        
        // Also check if we need to send immediate reminder (within 2 hour window)
        if (interviewDate.isBefore(twoHoursFromNow) && interviewDate.isAfter(now)) {
          final reminderKey = '${doc.id}_${interviewDate.millisecondsSinceEpoch}';
          if (!_sentReminders.contains(reminderKey)) {
            await sendImmediateReminder(
              interviewId: doc.id,
              jobTitle: data['jobTitle'] ?? 'Job Interview',
              companyName: data['company'] ?? 'Company',
              interviewTime: interviewDate,
              isRecruiter: false,
              seekerId: uid,
              recruiterId: data['recruiterId'] ?? '',
            );
            _sentReminders.add(reminderKey);
          }
        }
      }
    }
  }

  /// Check recruiter's upcoming interviews
  Future<void> _checkRecruiterInterviews(String uid) async {
    final now = DateTime.now();
    final twoHoursFromNow = now.add(const Duration(hours: 2));
    final sixHoursFromNow = now.add(const Duration(hours: 6));
    
    final applications = await _firestore
        .collection('Applications')
        .where('recruiterId', isEqualTo: uid)
        .where('status', isEqualTo: 'Interview Scheduled')
        .where('interviewDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('interviewDate', isLessThanOrEqualTo: Timestamp.fromDate(sixHoursFromNow))
        .get();
    
    for (final doc in applications.docs) {
      final data = doc.data();
      final interviewDate = (data['interviewDate'] as Timestamp?)?.toDate();
      
      if (interviewDate != null) {
        // Schedule reminder for 2 hours before interview
        final reminderTime = interviewDate.subtract(const Duration(hours: 2));
        
        // Only schedule if reminder time is in the future and within next 6 hours
        if (reminderTime.isAfter(now) && reminderTime.isBefore(sixHoursFromNow)) {
          await _scheduleLocalReminder(
            interviewId: doc.id,
            jobTitle: data['jobTitle'] ?? 'Job Interview',
            companyName: data['company'] ?? 'Company',
            interviewTime: interviewDate,
            reminderTime: reminderTime,
            isRecruiter: true,
            seekerId: data['seekerId'] ?? '',
            recruiterId: uid,
          );
        }
        
        // Also check if we need to send immediate reminder (within 2 hour window)
        if (interviewDate.isBefore(twoHoursFromNow) && interviewDate.isAfter(now)) {
          final reminderKey = '${doc.id}_${interviewDate.millisecondsSinceEpoch}';
          if (!_sentReminders.contains(reminderKey)) {
            await sendImmediateReminder(
              interviewId: doc.id,
              jobTitle: data['jobTitle'] ?? 'Job Interview',
              companyName: data['company'] ?? 'Company',
              interviewTime: interviewDate,
              isRecruiter: true,
              seekerId: data['seekerId'] ?? '',
              recruiterId: uid,
            );
            _sentReminders.add(reminderKey);
          }
        }
      }
    }
  }

  /// Schedule a local notification reminder
  Future<void> _scheduleLocalReminder({
    required String interviewId,
    required String jobTitle,
    required String companyName,
    required DateTime interviewTime,
    required DateTime reminderTime,
    required bool isRecruiter,
    required String seekerId,
    required String recruiterId,
  }) async {
    try {
      // Use a simple timer-based approach for scheduling
      final delay = reminderTime.difference(DateTime.now());
      if (delay.inMilliseconds > 0) {
        Timer(delay, () async {
          await sendImmediateReminder(
            interviewId: interviewId,
            jobTitle: jobTitle,
            companyName: companyName,
            interviewTime: interviewTime,
            isRecruiter: isRecruiter,
            seekerId: seekerId,
            recruiterId: recruiterId,
          );
        });
      }
      
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Scheduled local reminder for $jobTitle at ${DateFormat('yyyy-MM-dd HH:mm').format(reminderTime)}', name: 'InterviewReminderService');
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error scheduling local reminder: $e', name: 'InterviewReminderService', error: e);
    }
  }

  /// Send immediate reminder notification
  Future<void> sendImmediateReminder({
    required String interviewId,
    required String jobTitle,
    required String companyName,
    required DateTime interviewTime,
    required bool isRecruiter,
    required String seekerId,
    required String recruiterId,
  }) async {
    try {
      // Create unique key for this reminder
      final reminderKey = '${interviewId}_${interviewTime.millisecondsSinceEpoch}';
      
      // Check if we already sent this reminder
      if (_sentReminders.contains(reminderKey)) {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Skipping duplicate reminder for $jobTitle', name: 'InterviewReminderService');
        return;
      }
      
      // Mark as sent
      _sentReminders.add(reminderKey);
      
      final notificationId = '${interviewId}_immediate'.hashCode;
      
      // Create Firestore notification entries for both seeker and recruiter
      await _createReminderNotification(
        jobTitle: jobTitle,
        companyName: companyName,
        interviewTime: interviewTime,
        seekerId: seekerId,
        recruiterId: recruiterId,
        interviewId: interviewId,
      );
      
      await _localNotifications.show(
        notificationId,
        'Interview Starting Soon!',
        'Your interview for $jobTitle at $companyName starts in less than 2 hours!\nTime: ${DateFormat('hh:mm a').format(interviewTime)}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            color: const Color(0xFF0A8F7B),
            ledColor: const Color(0xFF0A8F7B),
            icon: '@mipmap/ic_launcher',
            ticker: 'Interview starting soon!',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode({
          'type': 'interview_reminder',
          'interviewId': interviewId,
          'jobTitle': jobTitle,
          'companyName': companyName,
          'isRecruiter': isRecruiter,
          'seekerId': seekerId,
          'recruiterId': recruiterId,
        }),
      );
      
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Sent immediate reminder for $jobTitle', name: 'InterviewReminderService');
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error sending immediate reminder: $e', name: 'InterviewReminderService', error: e);
    }
  }

  /// Create Firestore notification entries for interview reminders
  Future<void> _createReminderNotification({
    required String jobTitle,
    required String companyName,
    required DateTime interviewTime,
    required String seekerId,
    required String recruiterId,
    required String interviewId,
  }) async {
    try {
      final batch = _firestore.batch();
      final now = Timestamp.now();
      
      // Create notification for seeker
      final seekerNotificationId = _firestore
          .collection('SeekerNotifications')
          .doc(seekerId)
          .collection('Notifications')
          .doc().id;
      
      batch.set(
        _firestore
            .collection('SeekerNotifications')
            .doc(seekerId)
            .collection('Notifications')
            .doc(seekerNotificationId),
        {
          'to': seekerId,
          'recipientId': seekerId,
          'from': recruiterId,
          'jobId': interviewId.split('_').last, // Extract jobId from interviewId
          'jobTitle': jobTitle,
          'seekerId': seekerId,
          'notificationId': seekerNotificationId,
          'type': 'interview_reminder',
          'interviewDate': Timestamp.fromDate(interviewTime),
          'read': false,
          'timestamp': now,
          'message': 'Your interview will be in 2hrs, All the Best!',
        },
      );
      
      // Create notification for recruiter
      final recruiterNotificationId = _firestore
          .collection('RecruiterNotifications')
          .doc(recruiterId)
          .collection('Notifications')
          .doc().id;
      
      batch.set(
        _firestore
            .collection('RecruiterNotifications')
            .doc(recruiterId)
            .collection('Notifications')
            .doc(recruiterNotificationId),
        {
          'to': recruiterId,
          'recipientId': recruiterId,
          'from': seekerId,
          'jobId': interviewId.split('_').last, // Extract jobId from interviewId
          'jobTitle': jobTitle,
          'seekerId': seekerId,
          'notificationId': recruiterNotificationId,
          'type': 'interview_reminder',
          'interviewDate': Timestamp.fromDate(interviewTime),
          'read': false,
          'timestamp': now,
          'message': 'Your interview with seeker will be in 2hrs, All the Best!',
        },
      );
      
      await batch.commit();
      
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Created Firestore reminder notifications for $jobTitle', name: 'InterviewReminderService');
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error creating Firestore reminder notifications: $e', name: 'InterviewReminderService', error: e);
    }
  }

  /// Create confirmation notification when seeker confirms interview availability
  Future<void> createInterviewConfirmationNotification({
    required String jobTitle,
    required String companyName,
    required DateTime interviewTime,
    required String seekerId,
    required String recruiterId,
    required String interviewId,
  }) async {
    try {
      final batch = _firestore.batch();
      final now = Timestamp.now();
      
      // Create confirmation notification for seeker
      final seekerNotificationId = _firestore
          .collection('SeekerNotifications')
          .doc(seekerId)
          .collection('Notifications')
          .doc().id;
      
      batch.set(
        _firestore
            .collection('SeekerNotifications')
            .doc(seekerId)
            .collection('Notifications')
            .doc(seekerNotificationId),
        {
          'to': seekerId,
          'recipientId': seekerId,
          'from': recruiterId,
          'jobId': interviewId.split('_').last, // Extract jobId from interviewId
          'jobTitle': jobTitle,
          'seekerId': seekerId,
          'notificationId': seekerNotificationId,
          'type': 'interview_reminder',
          'interviewDate': Timestamp.fromDate(interviewTime),
          'read': false,
          'timestamp': now,
          'message': 'Interview confirmed! Your interview for $jobTitle at $companyName is scheduled. You will receive a reminder 2 hours before the interview.',
        },
      );
      
      // Create confirmation notification for recruiter
      final recruiterNotificationId = _firestore
          .collection('RecruiterNotifications')
          .doc(recruiterId)
          .collection('Notifications')
          .doc().id;
      
      batch.set(
        _firestore
            .collection('RecruiterNotifications')
            .doc(recruiterId)
            .collection('Notifications')
            .doc(recruiterNotificationId),
        {
          'to': recruiterId,
          'recipientId': recruiterId,
          'from': seekerId,
          'jobId': interviewId.split('_').last, // Extract jobId from interviewId
          'jobTitle': jobTitle,
          'seekerId': seekerId,
          'notificationId': recruiterNotificationId,
          'type': 'interview_reminder',
          'interviewDate': Timestamp.fromDate(interviewTime),
          'read': false,
          'timestamp': now,
          'message': 'Seeker confirmed interview for $jobTitle at $companyName! Interview is scheduled. You will receive a reminder 2 hours before the interview.',
        },
      );
      
      await batch.commit();
      
      // Also schedule the 2-hour reminder
      await scheduleInterviewReminder(
        interviewId: interviewId,
        jobTitle: jobTitle,
        companyName: companyName,
        interviewTime: interviewTime,
        seekerId: seekerId,
        recruiterId: recruiterId,
      );
      
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Created interview confirmation notifications for $jobTitle', name: 'InterviewReminderService');
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error creating interview confirmation notifications: $e', name: 'InterviewReminderService', error: e);
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      
      if (type == 'interview_reminder') {
        // Navigate to calls screen to show interview details
        navigatorKey.currentState?.pushNamed('/calls');
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Interview reminder notification tapped', name: 'InterviewReminderService');
      }
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error handling notification tap: $e', name: 'InterviewReminderService', error: e);
    }
  }

  /// Schedule reminder for a specific interview when it's created/updated
  Future<void> scheduleInterviewReminder({
    required String interviewId,
    required String jobTitle,
    required String companyName,
    required DateTime interviewTime,
    required String seekerId,
    required String recruiterId,
  }) async {
    try {
      final reminderTime = interviewTime.subtract(const Duration(hours: 2));
      final now = DateTime.now();
      
      // Only schedule if reminder is in the future
      if (reminderTime.isAfter(now)) {
        // Schedule for seeker
        await _scheduleLocalReminder(
          interviewId: interviewId,
          jobTitle: jobTitle,
          companyName: companyName,
          interviewTime: interviewTime,
          reminderTime: reminderTime,
          isRecruiter: false,
          seekerId: seekerId,
          recruiterId: recruiterId,
        );
        
        // Schedule for recruiter
        await _scheduleLocalReminder(
          interviewId: interviewId,
          jobTitle: jobTitle,
          companyName: companyName,
          interviewTime: interviewTime,
          reminderTime: reminderTime,
          isRecruiter: true,
          seekerId: seekerId,
          recruiterId: recruiterId,
        );
        
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Scheduled interview reminders for $jobTitle', name: 'InterviewReminderService');
      }
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error scheduling interview reminder: $e', name: 'InterviewReminderService', error: e);
    }
  }

  /// Cancel reminder for a specific interview
  Future<void> cancelInterviewReminder(String interviewId) async {
    try {
      await _localNotifications.cancel(interviewId.hashCode);
      await _localNotifications.cancel('${interviewId}_immediate'.hashCode);
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Cancelled interview reminder for interview $interviewId', name: 'InterviewReminderService');
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error cancelling interview reminder: $e', name: 'InterviewReminderService', error: e);
    }
  }

  /// Cancel all interview reminders
  Future<void> cancelAllInterviewReminders() async {
    try {
      await _localNotifications.cancelAll();
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Cancelled all interview reminders', name: 'InterviewReminderService');
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error cancelling all interview reminders: $e', name: 'InterviewReminderService', error: e);
    }
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _localNotifications.pendingNotificationRequests();
  }

  /// Dispose the service
  void dispose() {
    _reminderCheckTimer?.cancel();
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Interview Reminder Service disposed', name: 'InterviewReminderService');
  }
}
