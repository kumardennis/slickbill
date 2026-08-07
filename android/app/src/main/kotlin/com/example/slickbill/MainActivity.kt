package com.slickbills.app

import android.content.Intent
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL_PDF_BYTES = "com.slickbills.app/getPdfBytes"
    private val CHANNEL_EXTRACT_TEXT = "com.slickbills.app/extractText"
    private val CHANNEL_NFC = "com.slickbills.app/nfc"

    private var pendingFileUri: Uri? = null

    private fun getBytesFromContentUri(contentUri: Uri): ByteArray? {
        return try {
            val contentResolver = applicationContext.contentResolver
            val inputStream = contentResolver.openInputStream(contentUri)
            inputStream?.readBytes()
        } catch (e: Exception) {
            Log.e("MainActivity", "Error reading file bytes: ${e.message}")
            null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        when (intent.action) {
            Intent.ACTION_VIEW, Intent.ACTION_SEND -> {
                val uri = intent.data ?: intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (uri != null) {
                    if (uri.scheme == "w3a") {
                        Log.d("MainActivity", "Ignoring Web3Auth callback URI in file handler: $uri")
                        return
                    }
                    pendingFileUri = uri
                    Log.d("MainActivity", "File URI received: $uri")
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Handle initial intent
        handleIntent(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NFC).setMethodCallHandler { call, result ->
            if (call.method == "getIntentAction") {
                result.success(intent?.action)
            } else {
                result.notImplemented()
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_PDF_BYTES).setMethodCallHandler { call, result ->
            if (call.method == "getPdfBytes") {
                if (pendingFileUri != null) {
                    val fileBytes = getBytesFromContentUri(pendingFileUri!!)
                    if (fileBytes != null) {
                        result.success(fileBytes)
                        pendingFileUri = null // Clear after use
                    } else {
                        result.error("READ_ERROR", "Failed to read file bytes", null)
                    }
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}