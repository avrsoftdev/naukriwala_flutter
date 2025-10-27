import 'package:flutter/services.dart';

class PlayIntegrityService {
  static const MethodChannel _channel = MethodChannel('play_integrity_channel');

  static Future<String?> getToken() async {
    try {
      final String? token = await _channel.invokeMethod('getPlayIntegrityToken');
      return token;
    } on PlatformException {
      return null;
    }
  }
}

// Usage example
Future<void> fetchToken() async {
  String? token = await PlayIntegrityService.getToken();
  if (token != null) {
    // Send to your backend
  }
}