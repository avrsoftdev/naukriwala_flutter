import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as dev;

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

class AuthMiddleware {
  static Future<void> requireRole(String role) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      dev.log('No authenticated user', name: 'AuthMiddleware');
      throw const AuthException('User not authenticated');
    }

    final firestore = FirebaseFirestore.instance;
    final collection = role == 'recruiter' ? 'Recruiters' : 'Seekers';
    final docRef = firestore.collection(collection).doc(uid);
    
    try {
      final doc = await docRef.get();
      if (!doc.exists) {
        dev.log('$role document missing for $uid, initializing', name: 'AuthMiddleware');
        final user = FirebaseAuth.instance.currentUser;
        await docRef.set({
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
          'email': user?.email ?? '',
          'name': user?.displayName ?? 'Unknown ${role.capitalize()}',
        }, SetOptions(merge: true));
        dev.log('Initialized $role document for $uid', name: 'AuthMiddleware');
      } else {
        dev.log('$role document exists for $uid: ${doc.data()}', name: 'AuthMiddleware');
      }
    } catch (e) {
      dev.log('Failed to verify or initialize $role for $uid: $e', name: 'AuthMiddleware', error: e);
      throw AuthException('Failed to verify $role: ${e.toString()}');
    }
  }
}

extension StringExtension on String {
  String capitalize() => this[0].toUpperCase() + substring(1);
}