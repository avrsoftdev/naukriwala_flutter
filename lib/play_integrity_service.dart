import 'package:cloud_functions/cloud_functions.dart';
// REMOVED: import 'package:app_device_integrity/app_device_integrity.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart'; // Needed for PlatformException and MethodChannel
import 'dart:developer' as developer;

class PlayIntegrityService {
  final FirebaseFunctions functions = FirebaseFunctions.instance;
  // FIX: Using a direct MethodChannel to communicate with MainActivity.kt
  final MethodChannel _channel = const MethodChannel('play_integrity_channel'); 
  
  // No need for a redundant instance of a plugin that isn't being used.
  // final AppDeviceIntegrity _integrity = AppDeviceIntegrity(); 

  // 1. Implementation to get the token from native Android code.
  // The nonce generation is now handled on the Kotlin side as per MainActivity.kt
  Future<String> getIntegrityToken() async {
    // Check if running in production (which requires a valid token)
    if (const bool.fromEnvironment('dart.vm.product')) {
      
      // Step 1: Call the native Android method channel to get the token.
      try {
        // FIX: Directly invoking the method implemented in MainActivity.kt
        final String? token = await _channel.invokeMethod<String>('getPlayIntegrityToken');
        
        // Ensure the token is present before returning
        if (token == null || token.isEmpty) {
          // If the method channel returns null/empty, throw a specific exception.
          throw Exception("Native Play Integrity Channel returned null or empty token.");
        }
        return token;
        
      } on PlatformException catch (e) { 
        // Catch errors returned by MethodChannel from Kotlin
        developer.log('Play Integrity Channel Error: ${e.code} - ${e.message}', name: 'IntegrityService', error: e.details);
        throw Exception("Failed to get Play Integrity token from native code: ${e.message}");
      }
    }

    // --- FALLBACK FOR DEBUG/DEVELOPMENT ---
    // This allows local testing or running on non-Android platforms 
    // where the Cloud Function is configured to skip verification in 'development' mode.
    return "";
  }

  // 2. The main function to call your Cloud Function
  Future<Map<String, dynamic>> sendNotificationWithIntegrity({
    required String fcmToken,
    required String recipientId,
    required String recipientRole,
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Step A: Get the integrity token from the native side
      final String integrityToken = await getIntegrityToken();

      // Step B: Prepare the data payload for the Cloud Function
      final Map<String, dynamic> functionData = {
        'token': fcmToken,
        'title': title,
        'body': body,
        'recipientId': recipientId,
        'recipientRole': recipientRole,
        // CRITICAL: Include the token generated on the client
        'integrityToken': integrityToken, 
        'data': data,
      };

      // Step C: Call the Firebase Callable Function
      final HttpsCallable callable = functions.httpsCallable('sendNotification');
      
      final result = await callable.call(functionData);

      final response = result.data as Map<String, dynamic>;
      
      if (response['success'] == true) {
        return {'success': true, 'message': response['message']};
      } else {
        return {'success': false, 'message': 'Function executed but failed: ${response['message']}'};
      }

    } on FirebaseFunctionsException catch (e) {
      // Handle HttpsError codes returned by your Firebase function
      return {
        'success': false,
        'message': 'Firebase Error (${e.code}): ${e.message}',
      };
    } catch (e) {
      return {'success': false, 'message': 'An unexpected error occurred: $e'};
    }
  }
}
