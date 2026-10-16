package com.Hynox.Hynox_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.app.Activity

class MainActivity : FlutterActivity() {
    private var saveResult: MethodChannel.Result? = null
    private var saveBytes: ByteArray? = null
    private val saveRequest = 6701

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hynox/files")
            .setMethodCallHandler { call, result ->
                if (call.method != "save") { result.notImplemented(); return@setMethodCallHandler }
                if (saveResult != null) { result.error("busy", "A file save is already open.", null); return@setMethodCallHandler }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name")
                val mime = call.argument<String>("mime")
                if (bytes == null || name == null || mime == null) {
                    result.error("invalid", "File details are missing.", null); return@setMethodCallHandler
                }
                saveResult = result
                saveBytes = bytes
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = mime
                        putExtra(Intent.EXTRA_TITLE, name)
                    }
                    startActivityForResult(intent, saveRequest)
                } catch (e: Exception) {
                    saveResult = null; saveBytes = null
                    result.error("unavailable", "The file picker could not be opened.", null)
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveRequest) return
        val result = saveResult ?: return
        val bytes = saveBytes
        saveResult = null; saveBytes = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) { result.success(false); return }
        try {
            val stream = contentResolver.openOutputStream(data.data!!, "w")
                ?: throw IllegalStateException("No file output stream")
            stream.use { it.write(bytes ?: throw IllegalStateException("No file data")) }
            result.success(true)
        } catch (e: Exception) {
            result.error("save_failed", "The report could not be saved. Choose another location and retry.", null)
        }
    }
}
