package com.example.slickbill

import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL_PDF_BYTES = "com.example.slickbill/getPdfBytes"
    private val CHANNEL_EXTRACT_TEXT = "com.example.slickbill/extractText"
    private val CHANNEL_NFC = "com.example.slickbill/nfc"

    private fun getBytesFromContentUri(contentUri: Uri): ByteArray? {
        val contentResolver = applicationContext.contentResolver
        val inputStream = contentResolver.openInputStream(contentUri)
        return inputStream?.readBytes()
    }


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

         MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NFC).setMethodCallHandler { call, result ->
            if (call.method == "getIntentAction") {
                result.success(intent?.action)
            } else {
                result.notImplemented()
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_PDF_BYTES).setMethodCallHandler { call, result ->
            val data: Uri? = intent.data
            if (data != null) {
                val fileBytes = getBytesFromContentUri(data)
                result.success(fileBytes)
                
                // Clear the intent data after processing
                // intent.data = null
            } else {
                result.error("NO_INTENT_DATA", "No data found in the intent.", null)
            }
        }
    }
}
