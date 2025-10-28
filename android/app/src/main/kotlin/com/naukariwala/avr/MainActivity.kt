package com.naukariwala.avr

import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.SecureRandom
import java.util.Base64
import android.content.Context
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val CHANNEL = "play_integrity_channel"
    private val TAG = "PlayIntegrity"

    // 🔹 Replace this with your actual GCP project number
    private val CLOUD_PROJECT_NUMBER = 307134434935// Use Long type as per API docs

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getPlayIntegrityToken") {
                getPlayIntegrityToken(result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getPlayIntegrityToken(result: MethodChannel.Result) {
        val integrityManager = IntegrityManagerFactory.create(this)
        val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
        val timestamp = dateFormat.format(Date())

        // Generate a secure random nonce
        val nonceBytes = ByteArray(32)
        SecureRandom().nextBytes(nonceBytes)
        val nonce = Base64.getEncoder().encodeToString(nonceBytes)
        Log.d(TAG, "[$timestamp IST] Generated nonce: $nonce")

        // Build the integrity token request
        val request = IntegrityTokenRequest.builder()
            .setNonce(nonce)
            .setCloudProjectNumber(CLOUD_PROJECT_NUMBER)
            .build()

        integrityManager.requestIntegrityToken(request)
            .addOnSuccessListener { response ->
                val token = response.token()
                Log.d(TAG, "[$timestamp IST] Successfully retrieved Play Integrity token: $token")
                result.success(token)
            }
            .addOnFailureListener { exception ->
                Log.e(TAG, "[$timestamp IST] Failed to get Play Integrity token", exception)
                when (exception) {
                    is SecurityException -> result.error("SECURITY_ERROR", "Security exception: ${exception.message}", null)
                    is IllegalStateException -> result.error("STATE_ERROR", "Invalid state: ${exception.message}", null)
                    else -> result.error("INTEGRITY_ERROR", "Failed to get token: ${exception.message}", null)
                }
            }
    }
}