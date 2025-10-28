// ignore_for_file: unused_import, unused_element, deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:naukariwala/services/auth_service.dart';
import 'firebase_options.dart';
import 'screens/unified_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/notifications_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:intl/intl.dart';

// Import the newly created Play Integrity Service
import 'play_integrity_service.dart'; // Ensure this path is correct if placed in lib/services/

// Cache for App Check token
String? _cachedAppCheckToken;
DateTime? _tokenExpiry;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // Avoid redundant App Check init—rely on cached token or app-level init
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Handling background message: ${message.messageId}', name: 'FCM Background');

    // Use existing auth state if available
    final data = message.data;
    final type = data['type'] as String? ?? 'unknown';
    final recipientId = data['recipientId'] as String? ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    final notificationId = data['notificationId'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
    final jobId = data['jobId'] as String?;
    final from = data['from'] as String?;
    final chatId = data['chatId'] as String?;
    final jobTitle = data['jobTitle'] as String? ?? 'Untitled';
    final messageBody = data['body'] ?? data['message'] ?? 'New notification';

    if (recipientId.isNotEmpty && type.isNotEmpty) {
      final collection = type == 'message' ? 'SeekerNotifications' : 'RecruiterNotifications';
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(recipientId)
          .collection('Notifications')
          .doc(notificationId)
          .set({
        'to': recipientId,
        'recipientId': recipientId,
        'from': from,
        'jobId': jobId,
        'jobTitle': jobTitle,
        'notificationId': notificationId,
        'type': type,
        'chatId': chatId,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'message': messageBody,
      }, SetOptions(merge: true));
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Stored background notification in $collection/$recipientId/Notifications/$notificationId', name: 'FCM Background');
    }

    await _showLocalNotification(message, customTitle: data['title'] ?? 'Naukariwala', customBody: messageBody);
  } catch (e) {
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error in background handler: $e', name: 'FCM Background', error: e);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize App Check with caching
  await _initializeAppCheckWithRetry();

  // Initialize AuthService and FCM token refresh
  final authService = AuthService();
  await authService.setupFcmTokenRefresh();

  // Set up FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] User granted permission', name: 'FCM');
  } else {
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] User denied or provisional permission: ${settings.authorizationStatus}', name: 'FCM');
  }

  // Initialize local notifications
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iOSInit = DarwinInitializationSettings(
    requestSoundPermission: true,
    requestBadgePermission: true,
    requestAlertPermission: true,
  );
  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
    iOS: iOSInit,
  );
  await localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      try {
        final payload = response.payload;
        final data = payload != null ? jsonDecode(payload) as Map<String, dynamic> : <String, dynamic>{};
        _handleNotificationNavigation(RemoteMessage(data: data));
      } catch (e) {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error parsing notification payload: $e', name: 'Local Notification', error: e);
      }
    },
  );

  // Create Android notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'fcm_default_channel',
    'FCM Notifications',
    description: 'Notifications from Naukariwala',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('notification'),
    enableVibration: true,
  );
  await localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  runApp(const NaukariwalaApp());
}

// Enhanced App Check initialization with caching
Future<void> _initializeAppCheckWithRetry() async {
  int attempts = 0;
  const maxAttempts = 3;
  while (attempts < maxAttempts) {
    try {
      // Activate only if not already initialized (no direct check, assume token fetch succeeds)
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      );
      // Fetch token only if cache expired
      if (_cachedAppCheckToken == null || _tokenExpiry == null || DateTime.now().isAfter(_tokenExpiry!)) {
        final token = await FirebaseAppCheck.instance.getToken(false); // Positional forceRefresh
        _cachedAppCheckToken = token;
        _tokenExpiry = DateTime.now().add(const Duration(minutes: 50)); // Refresh at 50 min (tokens ~1h)
        final tokenPreview = token?.substring(0, 20) ?? '[null]';
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] App Check activated successfully. Token (partial): $tokenPreview...', name: 'AppCheck');
      }
      if (kDebugMode) {
        final debugToken = await FirebaseAppCheck.instance.getLimitedUseToken();
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Debug secret (register in Firebase Console): $debugToken', name: 'AppCheck');
      }
      return;
    } catch (e) {
      attempts++;
      if (e.toString().contains('App attestation failed') || e.toString().contains('Too many attempts')) {
        final delay = Duration(seconds: (2 << attempts).clamp(2, 8)); // Exponential backoff: 2s, 4s, 8s
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] App Check retry $attempts after ${delay.inSeconds}s due to: $e', name: 'AppCheck');
        await Future.delayed(delay);
      } else {
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] App Check error (non-retryable): $e', name: 'AppCheck', error: e);
        break;
      }
    }
  }
  dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] App Check failed after $maxAttempts attempts; using placeholder token', name: 'AppCheck');
  _cachedAppCheckToken = 'placeholder'; // Fallback for testing
}

// Show local notification
Future<void> _showLocalNotification(RemoteMessage message, {String? customTitle, String? customBody}) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'fcm_default_channel',
    'FCM Notifications',
    channelDescription: 'Notifications from Naukariwala',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    sound: RawResourceAndroidNotificationSound('notification'),
    enableVibration: true,
  );
  const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
    iOS: iOSDetails,
  );
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  await localNotifications.show(
    message.hashCode,
    customTitle ?? 'Naukariwala',
    customBody ?? 'New notification',
    details,
    payload: jsonEncode(message.data),
  );
}

// Handle notification navigation
Future<void> _handleNotificationNavigation(RemoteMessage message) async {
  final data = message.data;
  final type = data['type'] as String? ?? 'unknown';
  final jobId = data['jobId'] as String?;
  final seekerId = data['seekerId'] as String?;
  final chatId = data['chatId'] as String?;
  final notificationId = data['notificationId'] as String?;

  final navigator = navigatorKey.currentState;
  if (navigator == null) {
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Navigator not available for notification navigation', name: 'FCM Navigation');
    return;
  }

  if (notificationId != null && type != 'message') {
    try {
      final collection = type == 'message' ? 'SeekerNotifications' : 'RecruiterNotifications';
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(uid)
            .collection('Notifications')
            .doc(notificationId)
            .update({'read': true});
        dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Marked notification $notificationId as read', name: 'FCM Navigation');
      }
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error marking notification $notificationId as read: $e', name: 'FCM Navigation', error: e);
    }
  }

  if (type == 'message' && chatId != null && jobId != null && seekerId != null) {
    navigator.push(MaterialPageRoute(
      builder: (context) => ChatScreen(chatId: chatId, recipientId: seekerId, jobId: jobId),
    ));
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Navigated to ChatScreen: chatId=$chatId, jobId=$jobId', name: 'FCM Navigation');
  } else if (type == 'application' || type == 'status_update' || type == 'interview_scheduled') {
    navigator.push(MaterialPageRoute(
      builder: (context) => NotificationsScreen(isRecruiter: type == 'application'),
    ));
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Navigated to NotificationsScreen for type=$type', name: 'FCM Navigation');
  } else {
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Unknown notification type: $type', name: 'FCM Navigation');
    navigator.push(MaterialPageRoute(builder: (context) => const UnifiedScreen()));
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NaukariwalaApp extends StatelessWidget {
  const NaukariwalaApp({super.key});

  // Example function to show how to use the Play Integrity Service
  Future<void> _sendTestNotification(BuildContext context) async {
    // IMPORTANT: Replace these with real data from your app
    final String mockFcmToken = 'MOCK_FCM_TOKEN'; // The recipient's FCM token
    final String mockRecipientId = 'RECIPIENT_USER_ID';
    const String mockRecipientRole = 'seeker'; // or 'recruiter'

    final integrityService = PlayIntegrityService();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attempting to send integrity-checked notification...')));
    
    try {
      final result = await integrityService.sendNotificationWithIntegrity(
        fcmToken: mockFcmToken,
        recipientId: mockRecipientId,
        recipientRole: mockRecipientRole,
        title: 'Application Update',
        body: 'Your application status has been updated.',
        data: {'jobId': 'job_001', 'type': 'status_update'},
      );
      
      if (result['success'] == true) {
        dev.log('Notification sent successfully: ${result['message']}', name: 'TestNotification');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Success: ${result['message']}')));
      } else {
        dev.log('Notification failed: ${result['message']}', name: 'TestNotification', error: result['message']);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${result['message']}')));
      }
    } catch (e) {
      dev.log('Unexpected error during notification send: $e', name: 'TestNotification', error: e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }


  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Naukariwala',
          navigatorKey: navigatorKey,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            textTheme: TextTheme(
              bodyMedium: TextStyle(fontSize: 16.sp),
              titleLarge: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
          ),
          debugShowCheckedModeBanner: false,
          // Wrap UnifiedScreen in a Builder to get a valid context for ScaffoldMessenger
          home: Builder(
            builder: (context) => Scaffold(
              body: const UnifiedScreen(),
              // Added a floating action button for testing the integrity call
              floatingActionButton: kDebugMode ? FloatingActionButton(
                onPressed: () => _sendTestNotification(context),
                tooltip: 'Test Notification',
                child: const Icon(Icons.security),
              ) : null,
            ),
          ),
        );
      },
    );
  }
}
