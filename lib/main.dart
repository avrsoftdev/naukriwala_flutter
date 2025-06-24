import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Added for kDebugMode
import 'dart:io'; // Added for ping test
import 'firebase_options.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Activate Firebase App Check only in release mode
  if (!kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    );
  }

  // Connect to emulators in debug mode with connectivity check
  if (kDebugMode) {
    try {
      // Test connectivity to emulator ports
      await _testEmulatorConnection('localhost', 8080);
      await _testEmulatorConnection('localhost', 9099);
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      print('Using emulators on localhost:8080 (Firestore) and 9099 (Auth)');
    } catch (e) {
      print('Emulator connection failed: $e. Falling back to live servers.');
    }
  }

  runApp(const NaukariwalaApp());
}

// Helper function to test emulator connectivity
Future<void> _testEmulatorConnection(String host, int port) async {
  final socket = await Socket.connect(host, port, timeout: Duration(seconds: 2));
  await socket.close();
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
      home: HomeScreen(),
    );
  }
}