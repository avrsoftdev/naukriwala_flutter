import 'dart:io';
import 'dart:convert'; // Added for jsonDecode and jsonEncode
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
import 'screens/chat_screen.dart'; // Adjust path as needed
import 'screens/notifications_screen.dart'; // Adjust path as needed
import 'package:firebase_app_check/firebase_app_check.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Add App Check activation
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
    dev.log('[2025-10-10 00:31 IST] App Check activated in background handler', name: 'FCM Background');
  } catch (e) {
    dev.log('[2025-10-10 00:31 IST] App Check activation failed in background: $e', name: 'FCM Background', error: e);
  }

  dev.log('[2025-10-07 13:59 IST] Handling background message: ${message.messageId}', name: 'FCM Background');

  // Store notification in Firestore for display in NotificationsScreen
  final data = message.data;
  final type = data['type'] as String? ?? 'unknown';
  final recipientId = data['recipientId'] as String? ?? FirebaseAuth.instance.currentUser?.uid;
  final notificationId = data['notificationId'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
  final jobId = data['jobId'] as String?;
  final from = data['from'] as String?;
  final chatId = data['chatId'] as String?;
  final jobTitle = data['jobTitle'] as String? ?? 'Untitled';

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
        'message': message.notification?.body ?? 'New notification',
      }, SetOptions(merge: true));
      dev.log('[2025-10-07 13:59 IST] Stored background notification in $collection/$recipientId/Notifications/$notificationId', name: 'FCM Background');
    } catch (e) {
      dev.log('[2025-10-07 13:59 IST] Error storing background notification: $e', name: 'FCM Background', error: e);
    }
  }

  // Display local notification in background, even for data-only payloads
  String title = message.notification?.title ?? 'Naukariwala';
  String body = message.notification?.body ?? 'New notification';
  if (type == 'message') {
    title = 'New Message';
    body = data['message'] ?? 'You have a new message';
  } else if (type == 'application') {
    title = 'New Application';
    body = data['message'] ?? 'A new application was submitted';
  } // Add more types as needed

  await _showLocalNotification(message, customTitle: title, customBody: body);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the app to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize AuthService and set up FCM token refresh
  final authService = AuthService();
  authService.setupFcmTokenRefresh();

  // FCM Background Handler Setup
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request Notification Permissions (Android 13+)
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  dev.log('[2025-10-07 13:59 IST] User granted permission: ${settings.authorizationStatus}', name: 'FCM Permissions');

  // Initialize Local Notifications
  await _initializeLocalNotifications();

  // Foreground Message Handling
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    dev.log('[2025-10-07 13:59 IST] Received foreground message: ${message.messageId}', name: 'FCM Foreground');
    if (message.notification != null) {
      _showLocalNotification(message);
    }
  });

  // Handle Notification Tap (Background/Terminated)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    dev.log('[2025-10-07 13:59 IST] Notification opened from background: ${message.messageId}', name: 'FCM Open');
    _handleNotificationNavigation(message);
  });

  // Handle Initial Message (Terminated State)
  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    dev.log('[2025-10-07 13:59 IST] App opened from terminated state via notification: ${initialMessage.messageId}', name: 'FCM Open');
    _handleNotificationNavigation(initialMessage);
  }
try {
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode
        ? AppleProvider.debug
        : AppleProvider.appAttest,
  );

  if (kDebugMode) {
    // Print Debug Token to register it in Firebase Console
    final debugToken = await FirebaseAppCheck.instance.getToken(true);
    dev.log('[2025-10-09 11:45 IST] 🔥 App Check Debug Token: $debugToken', name: 'AppCheck');
  }

  dev.log('[2025-10-09 11:45 IST] Firebase App Check activated successfully', name: 'AppCheck');
} catch (e) {
  dev.log('[2025-10-09 11:45 IST] App Check activation failed: $e', name: 'AppCheck', error: e);
}

  // Emulator Setup
  if (kDebugMode) {
    try {
      final String emulatorHost = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
      await _testEmulatorConnection(emulatorHost, 8080);
      await _testEmulatorConnection(emulatorHost, 9099);
      await _testEmulatorConnection(emulatorHost, 9199);

      FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
      FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
      FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);

      dev.log('[2025-10-07 13:59 IST] Connected to Firebase emulators at $emulatorHost', name: 'Main');
    } catch (e) {
      dev.log('[2025-10-07 13:59 IST] Emulator connection failed: $e. Falling back to live servers.', name: 'Main', error: e);
    }
  }

  // Log FCM Token
  if (kDebugMode) {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        dev.log('[2025-10-07 13:59 IST] FCM Token: $fcmToken', name: 'Main');
      }
    } catch (e) {
      dev.log('[2025-10-07 13:59 IST] FCM token retrieval failed: $e', name: 'Main', error: e);
    }
  }

  runApp(const NaukariwalaApp());
}

// Local Notifications Initialization
final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

Future<void> _initializeLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await _localNotifications.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      dev.log('[2025-10-07 13:59 IST] Local notification tapped: ${response.payload}', name: 'Local Notification');
      // Parse payload for navigation
      if (response.payload != null) {
        try {
          final data = jsonDecode(response.payload!);
          _handleNotificationNavigation(RemoteMessage(data: data));
        } catch (e) {
          dev.log('[2025-10-07 13:59 IST] Error parsing notification payload: $e', name: 'Local Notification', error: e);
        }
      }
    },
  );

  // Create Android notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'fcm_default_channel',
    'FCM Notifications',
    description: 'Notifications from Naukariwala',
    importance: Importance.max,
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
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
  await _localNotifications.show(
    message.hashCode,
    customTitle ?? message.notification?.title ?? 'Naukariwala',
    customBody ?? message.notification?.body ?? 'New notification',
    details,
    payload: jsonEncode(message.data),
  );
}

// Handle notification navigation
void _handleNotificationNavigation(RemoteMessage message) {
  final data = message.data;
  final type = data['type'] as String? ?? 'unknown';
  final jobId = data['jobId'] as String?;
  final seekerId = data['seekerId'] as String?;
  final chatId = data['chatId'] as String?;

  // Use NavigatorKey to navigate from main.dart
  final navigator = navigatorKey.currentState;
  if (navigator == null) {
    dev.log('[2025-10-07 13:59 IST] Navigator not available for notification navigation', name: 'FCM Navigation');
    return;
  }

  if (type == 'message' && chatId != null && jobId != null && seekerId != null) {
    navigator.push(MaterialPageRoute(
      builder: (context) => ChatScreen(
        chatId: chatId,
        jobId: jobId,
        recipientId: seekerId,
      ),
    ));
    dev.log('[2025-10-07 13:59 IST] Navigated to ChatScreen: chatId=$chatId, jobId=$jobId', name: 'FCM Navigation');
  } else if (type == 'application' || type == 'status_update' || type == 'interview_scheduled') {
    navigator.push(MaterialPageRoute(
      builder: (context) => NotificationsScreen(),
    ));
    dev.log('[2025-10-07 13:59 IST] Navigated to NotificationsScreen for type=$type', name: 'FCM Navigation');
  } else {
    dev.log('[2025-10-07 13:59 IST] Unknown notification type: $type', name: 'FCM Navigation');
    navigator.push(MaterialPageRoute(builder: (context) => const UnifiedScreen()));
  }
}

// Global NavigatorKey for navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _testEmulatorConnection(String host, int port) async {
  try {
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
    await socket.close();
  } catch (e) {
    throw Exception('Failed to connect to $host:$port - $e');
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