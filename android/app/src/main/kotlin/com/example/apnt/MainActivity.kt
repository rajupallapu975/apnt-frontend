package com.example.apnt

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.content.Context
import androidx.core.content.FileProvider
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.apnt/file_opener"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "openFile") {
                val path = call.argument<String>("path")
                val mimeType = call.argument<String>("mimeType")
                if (path != null) {
                    try {
                        openFile(path, mimeType)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                } else {
                    result.error("UNAVAILABLE", "File path is null.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun openFile(path: String, mimeType: String?) {
        val file = File(path)
        val uri = FileProvider.getUriForFile(applicationContext, "${packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_VIEW)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.setDataAndType(uri, mimeType ?: getMimeType(path))
        startActivity(intent)
    }

    private fun getMimeType(url: String): String {
        val extension = url.substringAfterLast('.', "")
        return when (extension.lowercase()) {
            "pdf" -> "application/pdf"
            "doc" -> "application/msword"
            "docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            else -> "*/*"
        }
    }
}
