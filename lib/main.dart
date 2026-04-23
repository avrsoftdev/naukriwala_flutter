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
import 'services/admob_service_new.dart';
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

  var firebaseReady = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
  } catch (e, stackTrace) {
    dev.log(
      'Firebase initialization failed',
      name: 'Startup',
      error: e,
      stackTrace: stackTrace,
    );
  }

  if (!firebaseReady) {
    runApp(const StartupErrorApp());
    return;
  }

  // App Check
  dev.log(
    'Build mode: debug=$kDebugMode, profile=$kProfileMode, release=$kReleaseMode',
    name: 'AppCheck',
  );
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: (kDebugMode || kProfileMode)
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    );
  } catch (e, stackTrace) {
    dev.log(
      'App Check activation failed. Continuing without crash.',
      name: 'AppCheck',
      error: e,
      stackTrace: stackTrace,
    );
  }
  if (kDebugMode || kProfileMode) {
    // Debug provider already prints the debug secret in logcat.
    dev.log(
      'App Check debug provider active. Use the debug secret printed by Firebase and add it in Firebase Console.',
      name: 'AppCheck',
    );
  }

  final authService = AuthService();
  try {
    await authService.setupFcmTokenRefresh();
  } catch (e, stackTrace) {
    dev.log(
      'FCM token refresh setup failed. Continuing without crash.',
      name: 'Startup',
      error: e,
      stackTrace: stackTrace,
    );
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Local Notifications
  final localNotif = FlutterLocalNotificationsPlugin();
  try {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await localNotif.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      'fcm_default_channel',
      'FCM',
      importance: Importance.max,
    );
    await localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  } catch (e, stackTrace) {
    dev.log(
      'Local notifications initialization failed. Continuing without crash.',
      name: 'Startup',
      error: e,
      stackTrace: stackTrace,
    );
  }

  // Initialize interview reminder service
  try {
    await InterviewReminderService().initialize();
  } catch (e, stackTrace) {
    dev.log(
      'Interview reminder initialization failed. Continuing without crash.',
      name: 'Startup',
      error: e,
      stackTrace: stackTrace,
    );
  }

  // Initialize AdMob service (google_mobile_ads)
  try {
    await AdMobService().initialize();
    dev.log('AdMob initialize() completed', name: 'AdMob');
  } catch (e, stackTrace) {
    dev.log(
      'AdMob initialization failed. Continuing without crash.',
      name: 'AdMob',
      error: e,
      stackTrace: stackTrace,
    );
  }

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

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'App startup failed. Please restart the app and check your internet connection.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );
  }
}
