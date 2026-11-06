package app.cue.next

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Import progress in the notification shade, so Cue can be minimised. */
class MainActivity : FlutterActivity() {
    private val channelId = "imports"
    private val notificationId = 4101
    private var asked = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cue/import_progress")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "progress" -> show(
                        call.argument<String>("text") ?: "",
                        call.argument<Int>("done") ?: 0,
                        call.argument<Int>("total") ?: 0,
                        ongoing = true,
                    )
                    "finished" -> show(call.argument<String>("text") ?: "", 0, 0, ongoing = false)
                    "clear" -> NotificationManagerCompat.from(this).cancel(notificationId)
                    else -> return@setMethodCallHandler result.notImplemented()
                }
                result.success(null)
            }
    }

    private fun show(text: String, done: Int, total: Int, ongoing: Boolean) {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            // Asked once per launch, the first time an import reports progress.
            if (!asked) {
                asked = true
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 41)
            }
            return
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(channelId) == null) {
            manager.createNotificationChannel(
                NotificationChannel(channelId, "Imports", NotificationManager.IMPORTANCE_LOW)
                    .apply { description = "Progress while your list is matched" },
            )
        }
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(if (ongoing) "Importing your list" else "Cue import")
            .setContentText(text)
            .setContentIntent(open)
            .setOnlyAlertOnce(true)
            .setOngoing(ongoing)
            .setAutoCancel(!ongoing)
            .setPriority(NotificationCompat.PRIORITY_LOW)
        if (ongoing && total > 0) builder.setProgress(total, done, false)
        try {
            NotificationManagerCompat.from(this).notify(notificationId, builder.build())
        } catch (e: SecurityException) {
            // Permission withdrawn meanwhile: progress stays in the app.
        }
    }
}
