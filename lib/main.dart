import 'dart:io';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/unified_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kDebugMode) {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
      );
    } catch (e) {
      dev.log('App Check activation failed: $e', name: 'Main');
    }
  }

  if (kDebugMode) {
    try {
      final String emulatorHost = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
      await _testEmulatorConnection(emulatorHost, 8080);
      await _testEmulatorConnection(emulatorHost, 9099);
      await _testEmulatorConnection(emulatorHost, 9199);

      FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
      FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
      FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);

      dev.log('✅ Connected to Firebase emulators at $emulatorHost.', name: 'Main');
    } catch (e) {
      dev.log('⚠️ Emulator connection failed: $e. Falling back to live servers.', name: 'Main', error: e);
    }
  }

  if (kDebugMode) {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        dev.log('FCM Token: $fcmToken', name: 'Main');
      }
    } catch (e) {
      dev.log('FCM token retrieval failed: $e', name: 'Main', error: e);
    }
  }

  runApp(const NaukariwalaApp());
}

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
    return MaterialApp(
      title: 'Naukariwala',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: const UnifiedScreen(),
    );
  }
}