import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class PlayIntegrityService {
  static const MethodChannel _channel = MethodChannel('play_integrity_channel');
  static const String _placeholder = 'DEVELOPMENT_PLACEHOLDER_TOKEN';
  bool _isSending = false;

  /// Get fresh integrity token EVERY TIME
  Future<String> getIntegrityToken() async {
    if (kDebugMode) {
      developer.log('DEBUG: Using placeholder', name: 'PlayIntegrity');
      return _placeholder;
    }

    try {
      final token = await _channel.invokeMethod<String>('getPlayIntegrityToken');
      if (token == null || token.isEmpty) {
        throw Exception('Empty token');
      }
      developer.log('Real token received', name: 'PlayIntegrity');
      return token;
    } catch (e) {
      developer.log('Token error: $e', name: 'PlayIntegrity', error: e);
      rethrow;
    }
  }

  /// Send notification (prevents duplicates)
  Future<Map<String, dynamic>> sendNotificationWithIntegrity({
    required String fcmToken,
    required String recipientId,
    required String recipientRole,
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    if (_isSending) {
      return {'success': false, 'message': 'Please wait...'};
    }
    _isSending = true;

    try {
      final integrityToken = await getIntegrityToken(); // ← FRESH EVERY TIME

      final payload = {
        'token': fcmToken,
        'title': title ?? 'New Message',
        'body': body ?? 'You have a new message',
        'recipientId': recipientId,
        'recipientRole': recipientRole,
        'integrityToken': integrityToken,
        'data': data ?? {},
      };

      final result = await FirebaseFunctions.instance
          .httpsCallable('sendNotification')
          .call(payload);

      return {'success': true, 'message': result.data['message'] ?? 'Sent'};
    } on FirebaseFunctionsException catch (e) {
      return {'success': false, 'message': '${e.code}: ${e.message}'};
    } finally {
      _isSending = false;
    }
  }
}