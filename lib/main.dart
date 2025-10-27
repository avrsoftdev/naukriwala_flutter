// ignore_for_file: unused_import, unused_element, deprecated_member_use

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
import 'package:intl/intl.dart'; // Added for DateFormat

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );
  dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Handling background message: ${message.messageId}', name: 'FCM Background');

  // Ensure Firebase Auth is initialized for current user
  await FirebaseAuth.instance.authStateChanges().first;
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
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Stored background notification in $collection/$recipientId/Notifications/$notificationId', name: 'FCM Background');
    } catch (e) {
      dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Error storing background notification: $e', name: 'FCM Background', error: e);
    }
  }

  // Display local notification
  await _showLocalNotification(message, customTitle: data['title'] ?? 'Naukariwala', customBody: messageBody);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize App Check
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Firebase App Check activated successfully', name: 'AppCheck');
  } catch (e) {
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] App Check activation failed: $e', name: 'AppCheck', error: e);
  }

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
        final payloadMap = jsonDecode(response.payload ?? '{}') as Map<String, dynamic>;
        _handleNotificationNavigation(RemoteMessage(data: payloadMap));
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

  // Mark notification as read if notificationId is provided and not a message type (to avoid duplicate reads)
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
      builder: (context) => ChatScreen(
        chatId: chatId,
        recipientId: seekerId,
        jobId: jobId,
      ),
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

// Global NavigatorKey for navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _testEmulatorConnection(String host, int port) async {
  try {
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
    await socket.close();
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Successfully connected to emulator $host:$port', name: 'Emulator');
  } catch (e) {
    dev.log('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} IST] Failed to connect to $host:$port - $e', name: 'Emulator', error: e);
  }
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