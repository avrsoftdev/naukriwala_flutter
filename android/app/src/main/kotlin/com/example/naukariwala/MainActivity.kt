package com.naukariwala.avr

import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.SecureRandom
import java.util.Base64

class MainActivity : FlutterActivity() {
    private val CHANNEL = "play_integrity_channel"

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
        val nonceBytes = ByteArray(16)
        SecureRandom().nextBytes(nonceBytes)
        val nonce = Base64.getEncoder().encodeToString(nonceBytes)

        val request = IntegrityTokenRequest.builder()
            .setNonce(nonce)
            .build()

        integrityManager.requestIntegrityToken(request)
            .addOnSuccessListener { response ->
                result.success(response.token())
            }
            .addOnFailureListener { exception ->
                result.error("INTEGRITY_ERROR", "Failed to get token: ${exception.message}", null)
            }
    }
}