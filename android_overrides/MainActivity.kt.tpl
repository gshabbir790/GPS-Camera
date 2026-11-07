package __PKG__

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var volumeChannel: MethodChannel? = null
    private var intercept = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // والیوم بٹن: Dart کو بھیجنا (تصویر / زوم)
        val vc = MethodChannel(messenger, "gps_camera/volume")
        volumeChannel = vc
        vc.setMethodCallHandler { call, result ->
            if (call.method == "intercept") {
                intercept = (call.arguments as? Boolean) ?: false
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // PDF وغیرہ کو Downloads/GPS Camera میں محفوظ کرنا
        MethodChannel(messenger, "gps_camera/files").setMethodCallHandler { call, result ->
            if (call.method == "saveToDownloads") {
                try {
                    val path = call.argument<String>("path") ?: ""
                    val name = call.argument<String>("name") ?: "file"
                    val mime = call.argument<String>("mime") ?: "application/octet-stream"
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val values = ContentValues()
                        values.put(MediaStore.Downloads.DISPLAY_NAME, name)
                        values.put(MediaStore.Downloads.MIME_TYPE, mime)
                        values.put(
                            MediaStore.Downloads.RELATIVE_PATH,
                            Environment.DIRECTORY_DOWNLOADS + "/GPS Camera"
                        )
                        val uri = contentResolver.insert(
                            MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
                        )
                        if (uri == null) {
                            result.error("SAVE", "Could not create file", null)
                        } else {
                            contentResolver.openOutputStream(uri)?.use { out ->
                                File(path).inputStream().use { input -> input.copyTo(out) }
                            }
                            result.success(true)
                        }
                    } else {
                        result.error("OLD_ANDROID", "Android 10 or newer required", null)
                    }
                } catch (e: Exception) {
                    result.error("SAVE", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (intercept &&
            (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            val args = HashMap<String, Any>()
            args["dir"] = if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) "up" else "down"
            args["repeat"] = event?.repeatCount ?: 0
            volumeChannel?.invokeMethod("key", args)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (intercept &&
            (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            return true
        }
        return super.onKeyUp(keyCode, event)
    }
}
