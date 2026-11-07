package __PKG__

import android.content.ContentValues
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.media.ExifInterface
import android.media.MediaActionSound
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private var volumeChannel: MethodChannel? = null
    private var intercept = false
    private var sound: MediaActionSound? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // کیمرے کی آواز (shutter / video start / stop)
        val ms = MediaActionSound()
        ms.load(MediaActionSound.SHUTTER_CLICK)
        ms.load(MediaActionSound.START_VIDEO_RECORDING)
        ms.load(MediaActionSound.STOP_VIDEO_RECORDING)
        sound = ms

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

        MethodChannel(messenger, "gps_camera/files").setMethodCallHandler { call, result ->
            when (call.method) {
                "sound" -> {
                    val kind = (call.arguments as? String) ?: "shutter"
                    val which = when (kind) {
                        "start" -> MediaActionSound.START_VIDEO_RECORDING
                        "stop" -> MediaActionSound.STOP_VIDEO_RECORDING
                        else -> MediaActionSound.SHUTTER_CLICK
                    }
                    sound?.play(which)
                    result.success(true)
                }

                "composePhoto" -> {
                    val src = call.argument<String>("src") ?: ""
                    val out = call.argument<String>("out") ?: ""
                    val stamp = call.argument<ByteArray>("stamp")
                    val ratio = call.argument<Double>("ratio") ?: 0.75
                    val maxW = call.argument<Int>("maxWidth") ?: 1600
                    val quality = call.argument<Int>("quality") ?: 85
                    val mirror = call.argument<Boolean>("mirror") ?: false
                    // بھاری کام الگ تھریڈ میں تاکہ ایپ نہ رکے
                    Thread {
                        try {
                            composePhoto(src, out, stamp, ratio, maxW, quality, mirror)
                            runOnUiThread { result.success(true) }
                        } catch (e: Throwable) {
                            runOnUiThread { result.error("COMPOSE", e.message, null) }
                        }
                    }.start()
                }

                "saveToDownloads" -> {
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
                }

                else -> result.notImplemented()
            }
        }
    }

    /** تصویر: گھمانا (EXIF) + کراپ + سائز + مرر + اسٹیمپ + JPG - سب native */
    private fun composePhoto(
        src: String, out: String, stampBytes: ByteArray?,
        ratio: Double, maxW: Int, quality: Int, mirror: Boolean
    ) {
        // پہلے صرف سائز پڑھیں، پھر ضرورت کے مطابق چھوٹا کر کے ڈی کوڈ (تیز + کم میموری)
        val bounds = BitmapFactory.Options()
        bounds.inJustDecodeBounds = true
        BitmapFactory.decodeFile(src, bounds)
        var sample = 1
        while (min(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxW) sample *= 2
        val opts = BitmapFactory.Options()
        opts.inSampleSize = sample
        var bmp = BitmapFactory.decodeFile(src, opts) ?: throw Exception("decode failed")

        val rotation = when (
            ExifInterface(src).getAttributeInt(
                ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL
            )
        ) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        if (rotation != 0f) {
            val m = Matrix()
            m.postRotate(rotation)
            val r = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
            if (r !== bmp) bmp.recycle()
            bmp = r
        }

        // مطلوبہ ریشو پر درمیان سے کراپ
        val cur = bmp.width.toDouble() / bmp.height
        var cx = 0
        var cy = 0
        var cw = bmp.width
        var ch = bmp.height
        if (abs(cur - ratio) > 0.01) {
            if (cur > ratio) {
                cw = (bmp.height * ratio).roundToInt()
                cx = (bmp.width - cw) / 2
            } else {
                ch = (bmp.width / ratio).roundToInt()
                cy = (bmp.height - ch) / 2
            }
        }
        val outW = min(cw, maxW)
        val outH = (outW.toDouble() * ch / cw).roundToInt()

        val result = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
        canvas.save()
        if (mirror) canvas.scale(-1f, 1f, outW / 2f, outH / 2f)
        canvas.drawBitmap(bmp, Rect(cx, cy, cx + cw, cy + ch), Rect(0, 0, outW, outH), paint)
        canvas.restore()
        bmp.recycle()

        if (stampBytes != null) {
            val stamp = BitmapFactory.decodeByteArray(stampBytes, 0, stampBytes.size)
            if (stamp != null) {
                val sh = (stamp.height.toDouble() * outW / stamp.width).roundToInt()
                canvas.drawBitmap(
                    stamp, Rect(0, 0, stamp.width, stamp.height),
                    Rect(0, outH - sh, outW, outH), paint
                )
                stamp.recycle()
            }
        }

        FileOutputStream(out).use { result.compress(Bitmap.CompressFormat.JPEG, quality, it) }
        result.recycle()
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
