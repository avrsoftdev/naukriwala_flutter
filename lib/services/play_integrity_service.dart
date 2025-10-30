import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;

class PlayIntegrityService {
  static const _channel = MethodChannel('play_integrity_channel');
  static const _placeholder = 'DEVELOPMENT_PLACEHOLDER_TOKEN';
  bool _sending = false;

  Future<String> getIntegrityToken() async {
    if (kDebugMode) return _placeholder;

    final token = await _channel.invokeMethod<String>('getPlayIntegrityToken');
    if (token == null || token.isEmpty) throw Exception('Empty integrity token');
    return token;
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
      final callable = FirebaseFunctions.instance.httpsCallable('sendNotification');
      final result = await callable.call({
        'token': fcmToken,
        'title': title,
        'body': body,
        'recipientId': recipientId,
        'recipientRole': recipientRole,
        'integrityToken': token,
        'data': data ?? {},
      });
      return result.data;
    } finally {
      _sending = false;
    }
  }
}