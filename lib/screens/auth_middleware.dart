import 'package:firebase_auth/firebase_auth.dart';

class AuthMiddleware {
  static Future<void> requireRole(String role) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
    if (token?.claims?['role'] != role) {
      throw FirebaseAuthException(
        code: 'permission-denied',
        message: 'User does not have the $role role',
      );
    }
  }
}