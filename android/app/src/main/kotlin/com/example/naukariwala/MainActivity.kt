package com.naukariwala.avr

import android.content.Context
import android.os.Bundle
import androidx.annotation.NonNull
import com.google.android.play.core.integrity.IntegrityManager
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.SecureRandom

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.naukariwala.integrity"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getIntegrityToken") {
                val integrityManager = IntegrityManagerFactory.create(applicationContext)
                val nonce = SecureRandom().generateSeed(16) // ByteArray nonce
                val integrityTokenRequest = IntegrityTokenRequest.builder()
                    .setNonce(nonce)
                    .build()
                try {
                    val integrityTokenResponse = integrityManager.requestIntegrityToken(integrityTokenRequest).get()
                    val token = integrityTokenResponse.token() // Retrieve token as String
                    result.success(token)
                } catch (e: Exception) {
                    result.error("INTEGRITY_ERROR", "Failed to get integrity token: ${e.message}", e)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestPermissionsIfNeeded()
    }

    private fun requestPermissionsIfNeeded() {
        val permissions = arrayOf(
            android.Manifest.permission.INTERNET
        )
        requestPermissions(permissions, 1)
    }
}
