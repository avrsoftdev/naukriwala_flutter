import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart'; // Needed for PlatformException and MethodChannel
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart'; // For kDebugMode

/// Service to handle communication with the native side for Play Integrity tokens
/// and sending integrity-checked notifications via Firebase Cloud Functions.
class PlayIntegrityService {
  final FirebaseFunctions functions = FirebaseFunctions.instance;
  // Using a direct MethodChannel to communicate with MainActivity.kt for native calls
  final MethodChannel _channel = const MethodChannel('play_integrity_channel'); 
  
  // 1. Implementation to get the token from native Android code.
  Future<String> getIntegrityToken() async {
    // Only attempt to get a real token in release builds (not kDebugMode)
    if (!kDebugMode) { 
      try {
        // Step 1: Call the native Android method channel to get the token.
        final String? token = await _channel.invokeMethod<String>('getPlayIntegrityToken');
        
        // Ensure the token is present before returning
        if (token == null || token.isEmpty) {
          developer.log('Native method returned a null or empty integrity token.', name: 'PlayIntegrityService');
          throw PlatformException(
            code: 'INTEGRITY_TOKEN_EMPTY',
            message: 'Integrity token retrieval failed on native side.',
          );
        }
        return token;
      } on PlatformException catch (e) {
        developer.log('Platform Exception getting integrity token: ${e.message}', name: 'PlayIntegrityService', error: e);
        throw Exception('Failed to get Play Integrity Token: ${e.message}');
      } catch (e) {
        developer.log('Unexpected error getting integrity token: $e', name: 'PlayIntegrityService', error: e);
        throw Exception('Unexpected error getting Play Integrity Token.');
      }
    } else {
      // DEBUG MODE: Return a placeholder token for local testing
      developer.log('Running in debug mode. Returning mock integrity token.', name: 'PlayIntegrityService');
      return 'MOCK_INTEGRITY_TOKEN_DEBUG'; 
    }
  }

  // 2. The method called from main.dart to send the notification via a secure, integrity-checked Cloud Function.
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
      developer.log('Retrieved integrity token (partial): ${integrityToken.substring(0, 10)}...', name: 'PlayIntegrityService');

      // Step B: Prepare the data payload for the Cloud Function
      final Map<String, dynamic> functionData = {
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'recipientId': recipientId,
        'recipientRole': recipientRole,
        // CRITICAL: Include the token generated on the client
        'integrityToken': integrityToken, 
        'data': data ?? {},
      };

      // Step C: Call the Firebase Callable Function
      // Assuming the cloud function is named 'sendNotification'
      final HttpsCallable callable = functions.httpsCallable('sendNotification');
      
      developer.log('Calling Cloud Function with integrity token...', name: 'PlayIntegrityService');
      final result = await callable.call(functionData);

      final response = result.data as Map<String, dynamic>;
      
      if (response['success'] == true) {
        developer.log('Cloud Function succeeded: ${response['message']}', name: 'PlayIntegrityService');
        return {'success': true, 'message': response['message']};
      } else {
        developer.log('Cloud Function executed but failed: ${response['message']}', name: 'PlayIntegrityService', error: response['message']);
        return {'success': false, 'message': 'Function executed but failed: ${response['message']}'};
      }

    } on FirebaseFunctionsException catch (e) {
      developer.log('Firebase Function Exception: ${e.code} - ${e.message}', name: 'PlayIntegrityService', error: e);
      // Handle HttpsError codes returned by your Firebase function
      return {
        'success': false,
        'message': 'Firebase Error (${e.code}): ${e.message}',
      };
    } catch (e) {
      developer.log('Unexpected error in sendNotificationWithIntegrity: $e', name: 'PlayIntegrityService', error: e);
      // Generic error handler
      return {
        'success': false,
        'message': 'Unexpected error occurred: $e',
      };
    }
  }
}
