// ignore_for_file: unused_import, unused_element, deprecated_member_use

import 'dart:io';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';
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
import 'package:permission_handler/permission_handler.dart'; // For runtime permissions

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  dev.log('[2025-10-25 14:00 IST] Handling background message: ${message.messageId}', name: 'FCM Background');

  final data = message.data;
  final type = data['type'] as String? ?? 'unknown';
  final recipientId = data['recipientId'] as String? ?? FirebaseAuth.instance.currentUser?.uid;
  final notificationId = data['notificationId'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
  final jobId = data['jobId'] as String?;
  final from = data['from'] as String?;
  final chatId = data['chatId'] as String?;
  final jobTitle = data['jobTitle'] as String? ?? 'Untitled';
  final messageBody = data['body'] ?? data['message'] ?? 'New notification';

  if (recipientId != null && type.isNotEmpty) {
    try {
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
      dev.log('[2025-10-25 14:00 IST] Stored background notification in $collection/$recipientId/Notifications/$notificationId', name: 'FCM Background');
    } catch (e) {
      dev.log('[2025-10-25 14:00 IST] Error storing background notification: $e', name: 'FCM Background', error: e);
    }
  }

  await _showLocalNotification(message, customTitle: data['title'] ?? 'Naukariwala', customBody: messageBody);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize App Check with retry logic (moved from auth_service.dart)
  await _initializeAppCheckWithRetry();

  final authService = AuthService();
  await authService.setupFcmTokenRefresh();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  if (Platform.isAndroid) {
    await Permission.notification.request();
  }
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission();
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    dev.log('[2025-10-25 14:00 IST] User granted permission', name: 'FCM');
  } else {
    dev.log('[2025-10-25 14:00 IST] User denied permission', name: 'FCM');
  }

  final _localNotifications = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iOSInit = DarwinInitializationSettings(
    requestSoundPermission: false,
    requestBadgePermission: false,
    requestAlertPermission: false,
  );
  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
    iOS: iOSInit,
  );
  await _localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      try {
        final payloadMap = jsonDecode(response.payload ?? '{}') as Map<String, dynamic>;
        _handleNotificationNavigation(RemoteMessage(data: payloadMap));
      } catch (e) {
        dev.log('[2025-10-25 14:00 IST] Error parsing notification payload: $e', name: 'Local Notification', error: e);
      }
    },
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'fcm_default_channel',
    'FCM Notifications',
    description: 'Notifications from Naukariwala',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('default'),
    enableVibration: true,
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  runApp(const NaukariwalaApp());
}

// Show local notification
Future<void> _showLocalNotification(RemoteMessage message, {String? customTitle, String? customBody}) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'fcm_default_channel',
    'FCM Notifications',
    channelDescription: 'Notifications from Naukariwala',
    importance: Importance.max,
    priority: Priority.high,  // Already correct here
    icon: '@mipmap/ic_launcher',
    sound: RawResourceAndroidNotificationSound('default'),
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
  final _localNotifications = FlutterLocalNotificationsPlugin();
  await _localNotifications.show(
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
    dev.log('[2025-10-25 14:00 IST] Navigator not available for notification navigation', name: 'FCM Navigation');
    return;
  }

  if (notificationId != null && type != 'message') {
    try {
      final collection = type == 'message' ? 'SeekerNotifications' : 'RecruiterNotifications';
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('Notifications')
          .doc(notificationId)
          .update({'read': true});
      dev.log('[2025-10-25 14:00 IST] Marked notification $notificationId as read', name: 'FCM Navigation');
    } catch (e) {
      dev.log('[2025-10-25 14:00 IST] Error marking notification $notificationId as read: $e', name: 'FCM Navigation', error: e);
    }
  }

  if (type == 'message' && chatId != null && jobId != null && seekerId != null) {
    navigator.push(MaterialPageRoute(
      builder: (context) => ChatScreen(
        chatId: chatId,
        recipientId: seekerId,
        jobId: jobId,
      ),
    ));
    dev.log('[2025-10-25 14:00 IST] Navigated to ChatScreen: chatId=$chatId, jobId=$jobId', name: 'FCM Navigation');
  } else if (type == 'application' || type == 'status_update' || type == 'interview_scheduled') {
    navigator.push(MaterialPageRoute(
      builder: (context) => NotificationsScreen(),
    ));
    dev.log('[2025-10-25 14:00 IST] Navigated to NotificationsScreen for type=$type', name: 'FCM Navigation');
  } else {
    dev.log('[2025-10-25 14:00 IST] Unknown notification type: $type', name: 'FCM Navigation');
    navigator.push(MaterialPageRoute(builder: (context) => const UnifiedScreen()));
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _testEmulatorConnection(String host, int port) async {
  try {
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
    await socket.close();
  } catch (e) {
    throw Exception('Failed to connect to $host:$port - $e');
  }
}

Future<void> _initializeAppCheckWithRetry() async {
  int attempts = 0;
  const maxAttempts = 5;
  while (attempts < maxAttempts) {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
      );
      final token = await FirebaseAppCheck.instance.getToken();
      dev.log('[2025-10-25 14:00 IST] App Check token retrieved successfully: $token', name: 'AppCheck');
      return;
    } catch (e) {
      if (e.toString().contains('Too many attempts')) {
        attempts++;
        final delay = pow(2, attempts).toInt() * 1000; // Exponential backoff (2^attempts seconds)
        dev.log('[2025-10-25 14:00 IST] App Check retry $attempts after $delay ms due to: $e', name: 'AppCheck');
        await Future.delayed(Duration(milliseconds: delay));
      } else {
        dev.log('[2025-10-25 14:00 IST] App Check error (non-rate-limit): $e', name: 'AppCheck', error: e);
        rethrow;
      }
    }
  }
  dev.log('[2025-10-25 14:00 IST] App Check failed after max retries', name: 'AppCheck');
  throw Exception('App Check initialization failed after max retries');
}

class NaukariwalaApp extends StatelessWidget {
  const NaukariwalaApp({super.key});

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
          home: const UnifiedScreen(),
        );
      },
    );
  }
}