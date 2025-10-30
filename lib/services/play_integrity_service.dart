// lib/services/play_integrity_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;

class PlayIntegrityService {
  static const _channel = MethodChannel('play_integrity_channel');
  static const _placeholder = 'DEVELOPMENT_PLACEHOLDER_TOKEN';
  bool _sending = false;

  Future<String> getIntegrityToken() async {
    // DEBUG MODE: Use placeholder
    if (kDebugMode) {
      dev.log('PlayIntegrity: Debug mode → using placeholder');
      return _placeholder;
    }

    try {
      final token = await _channel.invokeMethod<String>('getPlayIntegrityToken');
      if (token == null || token.isEmpty) {
        dev.log('PlayIntegrity: Token is null/empty → fallback');
        return _fallback();
      }
      dev.log('PlayIntegrity: Token generated successfully');
      return token;
    } on PlatformException catch (e) {
      dev.log('PlayIntegrity: PlatformException → ${e.code}: ${e.message}');
      return _fallback();
    } catch (e) {
      dev.log('PlayIntegrity: Unexpected error → $e');
      return _fallback();
    }
  }

  String _fallback() {
    dev.log('PlayIntegrity: Using fallback token');
    return _placeholder;
  }

  Future<Map<String, dynamic>> sendNotificationWithIntegrity({
    required String fcmToken,
    required String recipientId,
    required String recipientRole,
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    if (_sending) return {'success': false, 'message': 'Sending...'};
    _sending = true;

    try {
      final token = await getIntegrityToken();
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('sendNotification');

      final result = await callable({
        'token': fcmToken,
        'title': title ?? 'New Message',
        'body': body ?? 'Tap to view',
        'data': (data ?? {}).map((k, v) => MapEntry(k, v.toString())),
        'recipientId': recipientId,
        'recipientRole': recipientRole,
        'integrityToken': token,
      });

      final response = result.data as Map<String, dynamic>;
      if (response['success'] == true) {
        dev.log('FCM sent successfully: ${response['fcmMessageId']}');
      }
      return response;
    } catch (e) {
      dev.log('sendNotificationWithIntegrity error: $e');
      return {'success': false, 'message': e.toString()};
    } finally {
      _sending = false;
    }
  }
}