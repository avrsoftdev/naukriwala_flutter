import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as dev;
class AuthMiddleware {
  static Future<void> requireRole(String role) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'permission-denied',
        message: 'User not authenticated',
      );
    }

    final firestore = FirebaseFirestore.instance;
    final docRef = firestore.collection(role == 'recruiter' ? 'Recruiters' : 'Seekers').doc(uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      // Attempt to initialize the role document if missing (e.g., due to incomplete signup)
      try {
        await docRef.set({
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        dev.log('Initialized $role role document for $uid', name: 'AuthMiddleware');
      } catch (e) {
        dev.log('Failed to initialize $role role document for $uid: $e', name: 'AuthMiddleware', error: e);
        throw FirebaseAuthException(
          code: 'permission-denied',
          message: 'User does not have the $role role and initialization failed',
        );
      }
    }
  }
}