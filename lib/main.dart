// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:io';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:naukariwala/services/auth_service.dart';
import 'firebase_options.dart';
import 'screens/unified_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/notifications_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

const String kCurrentTimestamp = '[2025-10-18 13:45 IST]'; // Updated to current date/time

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  dev.log('$kCurrentTimestamp Handling background message: ${message.messageId}', name: 'FCM Background');

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
  await _localNotifications.initialize(initSettings);

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
      dev.log('$kCurrentTimestamp Stored background notification in $collection/$recipientId/Notifications/$notificationId', name: 'FCM Background');
    } catch (e) {
      dev.log('$kCurrentTimestamp Error storing background notification: $e', name: 'FCM Background', error: e);
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

  // Initialize App Check with retry
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
    dev.log('$kCurrentTimestamp Firebase App Check activated successfully', name: 'AppCheck');
  } catch (e) {
    dev.log('$kCurrentTimestamp App Check activation failed: $e', name: 'AppCheck', error: e);
    await _retryAppCheckInitialization();
  }

  final authService = AuthService();
  await authService.setupFcmTokenRefresh();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request Notification Permissions
  await _requestNotificationPermissions();

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
        dev.log('$kCurrentTimestamp Error parsing notification payload: $e', name: 'Local Notification', error: e);
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

// Retry App Check initialization with exponential backoff
Future<void> _retryAppCheckInitialization() async {
  int attempts = 0;
  const maxAttempts = 3;
  const baseDelay = Duration(seconds: 2);

  while (attempts < maxAttempts) {
    try {
      await FirebaseAppCheck.instance.getToken();
      dev.log('$kCurrentTimestamp App Check token retrieved after retry', name: 'AppCheck');
      return;
    } catch (e) {
      attempts++;
      dev.log('$kCurrentTimestamp App Check retry $attempts failed: $e', name: 'AppCheck', error: e);
      if (e.toString().contains('Too many attempts')) {
        final delay = baseDelay * (1 << (attempts - 1));
        dev.log('$kCurrentTimestamp Retrying App Check in ${delay.inSeconds} seconds', name: 'AppCheck');
        await Future.delayed(delay);
      } else {
        dev.log('$kCurrentTimestamp App Check non-rate-limit error: $e', name: 'AppCheck', error: e);
        break;
      }
    }
  }
  dev.log('$kCurrentTimestamp App Check failed after $maxAttempts attempts', name: 'AppCheck');
}

// Request Notification Permissions
Future<void> _requestNotificationPermissions() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().deviceInfo;
    if (androidInfo is AndroidDeviceInfo && androidInfo.version.sdkInt >= 33) {
      final status = await Permission.notification.request();
      dev.log('$kCurrentTimestamp Notification permission status: $status', name: 'FCM');
      if (status != PermissionStatus.granted) {
        dev.log('$kCurrentTimestamp Notification permission denied', name: 'FCM');
      }
    }
  }
  final settings = await FirebaseMessaging.instance.requestPermission();
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    dev.log('$kCurrentTimestamp User granted FCM permission', name: 'FCM');
  } else {
    dev.log('$kCurrentTimestamp User denied FCM permission', name: 'FCM');
  }
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
    dev.log('$kCurrentTimestamp Navigator not available for notification navigation', name: 'FCM Navigation');
    return;
  }

  if (notificationId != null && type != 'message') {
    try {
      final collection = type == 'message' ? 'SeekerNotifications' : 'RecruiterNotifications';
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(userId)
            .collection('Notifications')
            .doc(notificationId)
            .update({'read': true});
        dev.log('$kCurrentTimestamp Marked notification $notificationId as read', name: 'FCM Navigation');
      }
    } catch (e) {
      dev.log('$kCurrentTimestamp Error marking notification $notificationId as read: $e', name: 'FCM Navigation', error: e);
    }
  }

  if (type == 'message' && chatId != null && jobId != null && seekerId != null) {
    navigator.push(MaterialPageRoute(
      builder: (context) => ChatScreen(chatId: chatId, recipientId: seekerId, jobId: jobId),
    ));
    dev.log('$kCurrentTimestamp Navigated to ChatScreen: chatId=$chatId, jobId=$jobId', name: 'FCM Navigation');
  } else if (type == 'application' || type == 'status_update' || type == 'interview_scheduled') {
    navigator.push(MaterialPageRoute(builder: (context) => const NotificationsScreen()));
    dev.log('$kCurrentTimestamp Navigated to NotificationsScreen for type=$type', name: 'FCM Navigation');
  } else {
    dev.log('$kCurrentTimestamp Unknown notification type: $type', name: 'FCM Navigation');
    navigator.push(MaterialPageRoute(builder: (context) => const UnifiedScreen()));
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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