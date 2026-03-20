import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const String _tag = 'UpdateService';
  
  // Check if app is in production mode
  static bool get _isProduction => !kDebugMode && !kProfileMode;
  
  // Check for updates and show snackbar if available
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      // Only run in production builds
      if (!_isProduction) {
        developer.log('Update check skipped: Not in production mode', name: _tag);
        return;
      }
      
      developer.log('Checking for app updates...', name: _tag);
      
      // Check if update is available
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        developer.log('Update available: ${updateInfo.availableVersionCode}', name: _tag);
        
        // Show snackbar with update button
        _showUpdateSnackbar(context, updateInfo);
      } else {
        developer.log('No update available', name: _tag);
      }
      
    } catch (e) {
      developer.log('Error checking for updates: $e', name: _tag, error: e);
      
      // Don't show error to user, just log it
      // This is a non-critical feature
    }
  }
  
  // Show snackbar with update button
  static void _showUpdateSnackbar(BuildContext context, AppUpdateInfo updateInfo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('🚀'),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'New update available! Update Naukriwala now for better performance and new features',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 8),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Update',
          textColor: Colors.white,
          onPressed: () => _performUpdate(context, updateInfo),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  // Perform the actual update
  static Future<void> _performUpdate(BuildContext context, AppUpdateInfo updateInfo) async {
    try {
      developer.log('Starting update flow...', name: _tag);
      
      // Use flexible update for better UX
      await InAppUpdate.startFlexibleUpdate();
      developer.log('Flexible update completed', name: _tag);
      
      // Show completion message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Update completed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      developer.log('Error performing update: $e', name: _tag, error: e);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Update failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _performUpdate(context, updateInfo),
            ),
          ),
        );
      }
    }
  }
  
  // Get current app version info
  static Future<String> getCurrentVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version} (${packageInfo.buildNumber})';
    } catch (e) {
      developer.log('Error getting current version: $e', name: _tag, error: e);
      return 'Unknown';
    }
  }
  
  // Log update check for debugging
  static void logUpdateCheck(String message, {Object? error, StackTrace? stackTrace}) {
    if (_isProduction) {
      // In production, you might want to send logs to your analytics service
      developer.log(message, name: _tag, error: error, stackTrace: stackTrace);
    } else {
      developer.log(message, name: _tag, error: error, stackTrace: stackTrace);
    }
  }
}
