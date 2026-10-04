package com.savestream.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.ContextCompat
import androidx.core.app.NotificationCompat

class LocalRecordingService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_START -> {
                ensureChannel()
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(intent.getStringExtra(EXTRA_SESSION_ID)),
                )
                START_NOT_STICKY
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                START_NOT_STICKY
            }
            else -> START_NOT_STICKY
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        val appLabel = applicationInfo.loadLabel(packageManager).toString()
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                appLabel,
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
    }

    private fun buildNotification(sessionId: String?): Notification {
        val appLabel = applicationInfo.loadLabel(packageManager).toString()
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(appLabel)
            .setContentText(sessionId ?: appLabel)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .build()
    }

    companion object {
        private const val ACTION_START =
            "com.savestream.app.localrecording.START"
        private const val ACTION_STOP =
            "com.savestream.app.localrecording.STOP"
        private const val EXTRA_SESSION_ID = "session_id"
        private const val EXTRA_STREAM_URL = "stream_url"
        private const val EXTRA_GRANTED_SECONDS = "granted_seconds"
        private const val CHANNEL_ID = "savestream_local_recording"
        private const val NOTIFICATION_ID = 3201

        fun start(
            context: Context,
            sessionId: String,
            streamUrl: String,
            grantedSeconds: Int,
        ) {
            val intent = Intent(context, LocalRecordingService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_SESSION_ID, sessionId)
                .putExtra(EXTRA_STREAM_URL, streamUrl)
                .putExtra(EXTRA_GRANTED_SECONDS, grantedSeconds)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, LocalRecordingService::class.java)
                .setAction(ACTION_STOP)
            context.startService(intent)
        }
    }
}
