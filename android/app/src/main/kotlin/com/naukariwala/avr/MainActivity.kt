package com.naukariwala.avr

import android.util.Base64
import android.util.Log
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.SecureRandom
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {

    // Must match Dart: MethodChannel('play_integrity_channel')
    private val CHANNEL = "play_integrity_channel"
    private val TAG = "PlayIntegrity"

    // Your Firebase Project Number (from google-services.json)
    private val CLOUD_PROJECT_NUMBER = 307134434935L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getPlayIntegrityToken") {
                    getPlayIntegrityToken(result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun getPlayIntegrityToken(result: MethodChannel.Result) {
        val integrityManager = IntegrityManagerFactory.create(this)

        // Timestamp in IST
        val istFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
        val timestamp = istFormat.format(Date())

        // Generate 32-byte cryptographically secure nonce
        val nonceBytes = ByteArray(32)
        SecureRandom().nextBytes(nonceBytes)
        val nonce = Base64.encodeToString(nonceBytes, Base64.NO_WRAP)
        Log.d(TAG, "[$timestamp IST] Generated nonce: $nonce")

        // Build request
        val request = IntegrityTokenRequest.builder()
            .setNonce(nonce)
            .setCloudProjectNumber(CLOUD_PROJECT_NUMBER)
            .build()

        // Request token
        integrityManager.requestIntegrityToken(request)
            .addOnSuccessListener { response ->
                val token = response.token()
                if (token.isNullOrBlank()) {
                    Log.e(TAG, "[$timestamp IST] Token is null or empty")
                    result.error("TOKEN_EMPTY", "Play Integrity returned empty token", null)
                    return@addOnSuccessListener
                }

                Log.d(TAG, "[$timestamp IST] Play Integrity token retrieved (first 20 chars): ${token.take(20)}...")
                result.success(token)
            }
            .addOnFailureListener { exception ->
                Log.e(TAG, "[$timestamp IST] Play Integrity failed", exception)

                val (code, message) = when (exception) {
                    is SecurityException -> "SECURITY_ERROR" to "Security issue: ${exception.message}"
                    is IllegalStateException -> "STATE_ERROR" to "Invalid state: ${exception.message}"
                    else -> "INTEGRITY_ERROR" to "Failed: ${exception.message}"
                }

                result.error(code, message, exception.stackTraceToString())
            }
    }
}