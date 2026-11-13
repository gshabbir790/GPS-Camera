package __PKG__

import android.app.Application
import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.PrintWriter
import java.io.StringWriter

/**
 * ایپ کریش ہو تو تفصیل Downloads فولڈر میں GPS_Camera_crash_*.txt کے نام سے محفوظ ہو جاتی ہے
 * (Android 10 یا نئے پر)۔ یہ فائل ڈویلپر کو بھیجیں۔
 */
class App : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                saveCrash(base, thread, throwable)
            } catch (e: Throwable) {
                // ignore
            }
            previous?.uncaughtException(thread, throwable)
        }
    }

    private fun saveCrash(ctx: Context, thread: Thread, t: Throwable) {
        val sw = StringWriter()
        t.printStackTrace(PrintWriter(sw))
        val text = "GPS Camera crash\n" +
            "Time: " + java.util.Date() + "\n" +
            "Thread: " + thread.name + "\n" +
            "Device: " + Build.MANUFACTURER + " " + Build.MODEL +
            " Android " + Build.VERSION.RELEASE + " (SDK " + Build.VERSION.SDK_INT + ")\n\n" +
            sw.toString()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues()
            values.put(
                MediaStore.Downloads.DISPLAY_NAME,
                "GPS_Camera_crash_" + System.currentTimeMillis() + ".txt"
            )
            values.put(MediaStore.Downloads.MIME_TYPE, "text/plain")
            values.put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            val uri = ctx.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            if (uri != null) {
                ctx.contentResolver.openOutputStream(uri)?.use { it.write(text.toByteArray()) }
            }
        }
    }
}
