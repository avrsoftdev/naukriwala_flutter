// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/unified_screen.dart';
import 'services/auth_service.dart';
import 'services/interview_reminder_service.dart';
import 'services/admob_service.dart';
import 'providers/message_state_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  dev.log('Background message: ${message.messageId}');

  final data = message.data;
  final payload = jsonEncode(data);

  final FlutterLocalNotificationsPlugin notif = FlutterLocalNotificationsPlugin();
  const AndroidNotificationDetails android = AndroidNotificationDetails(
    'fcm_default_channel', 'FCM',
    importance: Importance.max, priority: Priority.high,
    sound: RawResourceAndroidNotificationSound('notification')
  );
  const NotificationDetails details = NotificationDetails(android: android);
  await notif.show(0, data['title'] ?? 'Naukariwala', data['body'] ?? 'New message', details, payload: payload);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env optional (e.g. address autocomplete needs GOOGLE_PLACES_API_KEY)
  }

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.appAttest,
  );

  final authService = AuthService();
  await authService.setupFcmTokenRefresh();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Local Notifications
  final localNotif = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await localNotif.initialize(initSettings);

  const channel = AndroidNotificationChannel('fcm_default_channel', 'FCM', importance: Importance.max);
  await localNotif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  // Initialize interview reminder service
  await InterviewReminderService().initialize();

  // Initialize AdMob service
  await AdMobService().initialize();

  runApp(const NaukariwalaApp());
}

class NaukariwalaApp extends StatelessWidget {
  const NaukariwalaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MessageStateProvider(
      child: ScreenUtilInit(
        designSize: const Size(360, 690),
        builder: (context, child) => MaterialApp(
          navigatorKey: navigatorKey,
          theme: ThemeData(primarySwatch: Colors.blue),
          debugShowCheckedModeBanner: false,
          home: const UnifiedScreen(),
        ),
      ),
    );
  }
}
