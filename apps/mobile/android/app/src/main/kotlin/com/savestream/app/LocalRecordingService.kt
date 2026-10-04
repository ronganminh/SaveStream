package com.savestream.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.StatFs
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicBoolean
import org.json.JSONObject

class LocalRecordingService : Service() {
    private val executor = Executors.newSingleThreadExecutor()
    private val stopRequested = AtomicBoolean(false)

    @Volatile
    private var worker: Future<*>? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopRequested.set(true)
        worker?.cancel(true)
        executor.shutdownNow()
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_START -> {
                ensureChannel()
                stopRequested.set(false)
                startForeground(NOTIFICATION_ID, buildNotification())
                if (worker?.isDone != false) {
                    worker = executor.submit { record(intent) }
                }
                START_NOT_STICKY
            }
            ACTION_STOP -> {
                stopRequested.set(true)
                emitState("finalizing", finalizationStep = "stopCapture")
                START_NOT_STICKY
            }
            ACTION_RECOVER -> {
                ensureChannel()
                stopRequested.set(false)
                startForeground(NOTIFICATION_ID, buildNotification())
                if (worker?.isDone != false) {
                    worker = executor.submit { recoverAndFinalize(intent) }
                }
                START_NOT_STICKY
            }
            else -> START_NOT_STICKY
        }
    }

    private fun record(intent: Intent) {
        val sessionId = intent.getStringExtra(EXTRA_SESSION_ID) ?: return stopWithError(
            "Missing local recording session id.",
        )
        val watchId = intent.getStringExtra(EXTRA_WATCH_ID).orEmpty()
        val deviceId = intent.getStringExtra(EXTRA_DEVICE_ID).orEmpty()
        val streamUrl = intent.getStringExtra(EXTRA_STREAM_URL) ?: return stopWithError(
            "Missing local recording stream URL.",
        )
        val streamFormat = intent.getStringExtra(EXTRA_STREAM_FORMAT) ?: "flv"
        val grantedSeconds = intent.getIntExtra(EXTRA_GRANTED_SECONDS, 0)
        val headers = parseHeaders(intent.getStringExtra(EXTRA_STREAM_HEADERS))

        if (grantedSeconds <= 0) {
            return stopWithError("Local recording lease is empty.")
        }

        val directory = File(filesDir, "local_recordings/$deviceId").apply { mkdirs() }
        val tempFile = File(directory, "$sessionId.part")
        val metadataFile = File(directory, "$sessionId.json")
        val startedAtMs = System.currentTimeMillis()
        val leaseDeadlineElapsedMs =
            SystemClock.elapsedRealtime() + grantedSeconds * 1000L

        persistMetadata(
            metadataFile = metadataFile,
            sessionId = sessionId,
            watchId = watchId,
            deviceId = deviceId,
            streamUrl = streamUrl,
            streamFormat = streamFormat,
            streamHeaders = headers,
            grantedSeconds = grantedSeconds,
            startedAtMs = startedAtMs,
            interruptedAtMs = null,
            recordedSeconds = 0,
            sizeBytes = tempFile.length(),
        )

        emitState("starting", sizeBytes = tempFile.length())
        capture(
            sessionId = sessionId,
            watchId = watchId,
            deviceId = deviceId,
            streamUrl = streamUrl,
            streamFormat = streamFormat,
            streamHeaders = headers,
            grantedSeconds = grantedSeconds,
            startedAtMs = startedAtMs,
            leaseDeadlineElapsedMs = leaseDeadlineElapsedMs,
            tempFile = tempFile,
            metadataFile = metadataFile,
            initialRecordedMillis = 0L,
        )
    }

    private fun recoverAndFinalize(intent: Intent) {
        val tempId = intent.getStringExtra(EXTRA_SESSION_ID) ?: return stopWithError(
            "Missing interrupted recording id.",
        )
        val metadataFile = findMetadata(tempId) ?: return stopWithError(
            "Interrupted recording metadata was not found.",
        )
        val metadata = readMetadata(metadataFile) ?: return stopWithError(
            "Interrupted recording metadata is invalid.",
        )
        val tempFile = File(metadataFile.parentFile, "$tempId.part")
        finalizeRecoveredFile(tempFile, metadataFile, metadata)
    }

    private fun capture(
        sessionId: String,
        watchId: String,
        deviceId: String,
        streamUrl: String,
        streamFormat: String,
        streamHeaders: Map<String, String>,
        grantedSeconds: Int,
        startedAtMs: Long,
        leaseDeadlineElapsedMs: Long,
        tempFile: File,
        metadataFile: File,
        initialRecordedMillis: Long,
    ) {
        var recordedMillis = initialRecordedMillis
        var sizeBytes = tempFile.length()
        var reconnectAttempts = 0
        var endReason = "free_minutes_exhausted"
        var failureMessage: String? = null
        var liveEnded = false

        while (!stopRequested.get() && SystemClock.elapsedRealtime() < leaseDeadlineElapsedMs) {
            if (freeStorageBytes(tempFile.parentFile) < CRITICAL_STORAGE_BYTES) {
                endReason = "storage_low"
                break
            }

            var connection: HttpURLConnection? = null
            var segmentLastChunkAt = SystemClock.elapsedRealtime()
            try {
                connection = (URL(streamUrl).openConnection() as HttpURLConnection).apply {
                    connectTimeout = CONNECT_TIMEOUT_MS
                    readTimeout = READ_TIMEOUT_MS
                    useCaches = false
                    instanceFollowRedirects = true
                    requestMethod = "GET"
                    streamHeaders.forEach { (name, value) ->
                        setRequestProperty(name, value)
                    }
                }
                connection.connect()
                val status = connection.responseCode
                if (status !in 200..299) {
                    throw IOException("Stream HTTP status $status")
                }

                reconnectAttempts = 0
                emitState(
                    "recording",
                    recordedSeconds = (recordedMillis / 1000L).toInt(),
                    sizeBytes = sizeBytes,
                    freeBytesOverride = freeStorageBytes(tempFile.parentFile),
                )
                connection.inputStream.use { input ->
                    FileOutputStream(tempFile, true).use { output ->
                        val buffer = ByteArray(BUFFER_SIZE)
                        while (
                            !stopRequested.get() &&
                                SystemClock.elapsedRealtime() < leaseDeadlineElapsedMs
                        ) {
                            val count = input.read(buffer)
                            if (count < 0) {
                                liveEnded = true
                                endReason = "live_ended"
                                break
                            }
                            if (count == 0) {
                                continue
                            }

                            val now = SystemClock.elapsedRealtime()
                            recordedMillis +=
                                (now - segmentLastChunkAt).coerceIn(0L, MAX_CHUNK_GAP_MS)
                            segmentLastChunkAt = now
                            output.write(buffer, 0, count)
                            sizeBytes += count

                            val freeBytes = freeStorageBytes(tempFile.parentFile)
                            if (freeBytes < CRITICAL_STORAGE_BYTES) {
                                endReason = "storage_low"
                                stopRequested.set(true)
                            }

                            val recordedSeconds = (recordedMillis / 1000L).toInt()
                            persistMetadata(
                                metadataFile = metadataFile,
                                sessionId = sessionId,
                                watchId = watchId,
                                deviceId = deviceId,
                                streamUrl = streamUrl,
                                streamFormat = streamFormat,
                                streamHeaders = streamHeaders,
                                grantedSeconds = grantedSeconds,
                                startedAtMs = startedAtMs,
                                interruptedAtMs = null,
                                recordedSeconds = recordedSeconds,
                                sizeBytes = sizeBytes,
                            )
                            emitState(
                                "recording",
                                recordedSeconds = recordedSeconds,
                                sizeBytes = sizeBytes,
                                freeBytesOverride = freeBytes,
                            )
                        }
                        output.flush()
                    }
                }

                if (liveEnded) {
                    break
                }
            } catch (error: IOException) {
                failureMessage = error.message
                reconnectAttempts += 1
                if (
                    reconnectAttempts > MAX_RECONNECT_ATTEMPTS ||
                        SystemClock.elapsedRealtime() >= leaseDeadlineElapsedMs
                ) {
                    endReason = "interrupted"
                    break
                }
                emitState(
                    "reconnecting",
                    recordedSeconds = (recordedMillis / 1000L).toInt(),
                    sizeBytes = sizeBytes,
                    freeBytesOverride = freeStorageBytes(tempFile.parentFile),
                    errorMessage = error.message,
                )
                SystemClock.sleep(reconnectDelayMillis(reconnectAttempts))
            } finally {
                connection?.disconnect()
            }
        }

        if (stopRequested.get() && endReason != "storage_low") {
            endReason = "user_stopped"
        }

        emitState(
            "finalizing",
            recordedSeconds = (recordedMillis / 1000L).toInt(),
            sizeBytes = sizeBytes,
            freeBytesOverride = freeStorageBytes(tempFile.parentFile),
            finalizationStep = "flushFile",
        )

        val finalFile = finalizeFile(tempFile, streamFormat)
        val recordedSeconds = (recordedMillis / 1000L).toInt()
        persistMetadata(
            metadataFile = metadataFile,
            sessionId = sessionId,
            watchId = watchId,
            deviceId = deviceId,
            streamUrl = streamUrl,
            streamFormat = streamFormat,
            streamHeaders = streamHeaders,
            grantedSeconds = grantedSeconds,
            startedAtMs = startedAtMs,
            interruptedAtMs = if (endReason == "interrupted") System.currentTimeMillis() else null,
            recordedSeconds = recordedSeconds,
            sizeBytes = finalFile?.length() ?: sizeBytes,
        )
        markPendingRegistration(metadataFile, endReason)

        val phase = if (endReason == "interrupted" && failureMessage != null) "error" else "stopped"
        emitState(
            phase,
            recordedSeconds = recordedSeconds,
            sizeBytes = finalFile?.length() ?: sizeBytes,
            freeBytesOverride = freeStorageBytes(tempFile.parentFile),
            finalizationStep = "registerRecording",
            errorMessage = failureMessage,
            endReason = endReason,
        )
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun finalizeRecoveredFile(
        tempFile: File,
        metadataFile: File,
        metadata: JSONObject,
    ) {
        emitState("finalizing", finalizationStep = "verifyFile")
        val format = metadata.optString("stream_format", "flv")
        if (format == "flv") {
            repairFlvTail(tempFile)
        }
        val finalFile = finalizeFile(tempFile, format)
        val size = finalFile?.length() ?: tempFile.length()
        metadata.put("interrupted_at_ms", JSONObject.NULL)
        metadata.put("size_bytes", size)
        metadata.put("needs_registration", true)
        metadata.put("end_reason", "interrupted")
        metadataFile.writeText(metadata.toString())
        emitState(
            "stopped",
            recordedSeconds = metadata.optInt("recorded_seconds", 0),
            sizeBytes = size,
            freeBytesOverride = freeStorageBytes(metadataFile.parentFile),
            finalizationStep = "registerRecording",
            endReason = "interrupted",
        )
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun repairFlvTail(file: File): Boolean {
        if (!file.exists() || file.length() < 13L) {
            return false
        }
        return try {
            RandomAccessFile(file, "rw").use { raf ->
                if (
                    raf.readUnsignedByte() != 0x46 ||
                        raf.readUnsignedByte() != 0x4c ||
                        raf.readUnsignedByte() != 0x56
                ) {
                    return false
                }
                raf.seek(5)
                val dataOffset = raf.readInt().toLong() and 0xffffffffL
                var cursor = dataOffset + 4L
                var safeLength = cursor
                while (cursor < raf.length()) {
                    if (raf.length() - cursor < 11L) {
                        break
                    }
                    raf.seek(cursor + 1L)
                    val dataSize =
                        (raf.readUnsignedByte() shl 16) or
                            (raf.readUnsignedByte() shl 8) or
                            raf.readUnsignedByte()
                    val payloadEnd = cursor + 11L + dataSize
                    val tagEnd = payloadEnd + 4L
                    if (tagEnd > raf.length()) {
                        break
                    }
                    raf.seek(payloadEnd)
                    val previousTagSize = raf.readInt().toLong() and 0xffffffffL
                    if (previousTagSize != 11L + dataSize) {
                        break
                    }
                    safeLength = tagEnd
                    cursor = tagEnd
                }
                if (safeLength in 13L until raf.length()) {
                    raf.setLength(safeLength)
                }
                safeLength >= 13L
            }
        } catch (_: IOException) {
            false
        }
    }

    private fun finalizeFile(tempFile: File, streamFormat: String): File? {
        if (!tempFile.exists()) {
            return null
        }
        val extension = if (streamFormat == "hls") "ts" else "flv"
        val finalFile = File(
            tempFile.parentFile,
            tempFile.nameWithoutExtension + "." + extension,
        )
        if (finalFile.exists()) {
            finalFile.delete()
        }
        return if (tempFile.renameTo(finalFile)) finalFile else tempFile
    }

    private fun persistMetadata(
        metadataFile: File,
        sessionId: String,
        watchId: String,
        deviceId: String,
        streamUrl: String,
        streamFormat: String,
        streamHeaders: Map<String, String>,
        grantedSeconds: Int,
        startedAtMs: Long,
        interruptedAtMs: Long?,
        recordedSeconds: Int,
        sizeBytes: Long,
    ) {
        val json = JSONObject()
            .put("session_id", sessionId)
            .put("watch_id", watchId)
            .put("device_id", deviceId)
            .put("stream_url", streamUrl)
            .put("stream_format", streamFormat)
            .put("stream_headers", JSONObject(streamHeaders))
            .put("granted_seconds", grantedSeconds)
            .put("started_at_ms", startedAtMs)
            .put("recorded_seconds", recordedSeconds)
            .put("size_bytes", sizeBytes)
        if (interruptedAtMs == null) {
            json.put("interrupted_at_ms", JSONObject.NULL)
        } else {
            json.put("interrupted_at_ms", interruptedAtMs)
        }
        metadataFile.writeText(json.toString())
    }

    private fun findMetadata(tempId: String): File? {
        val root = File(filesDir, "local_recordings")
        return root.walkTopDown().firstOrNull {
            it.isFile && it.name == "$tempId.json"
        }
    }

    private fun markPendingRegistration(metadataFile: File, endReason: String) {
        val metadata = readMetadata(metadataFile) ?: return
        metadata.put("needs_registration", true)
        metadata.put("end_reason", endReason)
        metadataFile.writeText(metadata.toString())
    }

    private fun readMetadata(file: File): JSONObject? {
        return try {
            JSONObject(file.readText())
        } catch (_: Exception) {
            null
        }
    }

    private fun parseHeaders(raw: String?): Map<String, String> {
        if (raw.isNullOrBlank()) {
            return emptyMap()
        }
        return jsonObjectToMap(JSONObject(raw))
    }

    private fun jsonObjectToMap(json: JSONObject?): Map<String, String> {
        if (json == null) {
            return emptyMap()
        }
        return buildMap {
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                put(key, json.optString(key))
            }
        }
    }

    private fun freeStorageBytes(directory: File?): Long {
        val path = directory ?: filesDir
        return StatFs(path.absolutePath).availableBytes
    }

    private fun reconnectDelayMillis(attempt: Int): Long {
        return when (attempt) {
            1 -> 2_000L
            2 -> 4_000L
            3 -> 8_000L
            4 -> 16_000L
            else -> 30_000L
        }
    }

    private fun emitState(
        phase: String,
        recordedSeconds: Int = 0,
        sizeBytes: Long = 0L,
        freeBytesOverride: Long? = null,
        finalizationStep: String? = null,
        errorMessage: String? = null,
        endReason: String? = null,
    ) {
        val freeBytes = freeBytesOverride ?: freeStorageBytes(filesDir)
        val estimatedMinutes =
            if (sizeBytes <= 0L || recordedSeconds <= 0) {
                null
            } else {
                val bytesPerSecond = sizeBytes.toDouble() / recordedSeconds.toDouble()
                if (bytesPerSecond <= 0.0) null
                else (freeBytes / bytesPerSecond / 60.0).toInt()
            }
        LocalRecordingEventBus.emit(
            mapOf(
                "phase" to phase,
                "recorded_seconds" to recordedSeconds,
                "size_bytes" to sizeBytes,
                "free_storage_bytes" to freeBytes,
                "storage_state" to when {
                    freeBytes < CRITICAL_STORAGE_BYTES -> "critical"
                    estimatedMinutes != null && estimatedMinutes <= 15 -> "low"
                    else -> "ok"
                },
                "estimated_storage_minutes" to estimatedMinutes,
                "finalization_step" to finalizationStep,
                "error_message" to errorMessage,
                "end_reason" to endReason,
            ),
        )
    }

    private fun stopWithError(message: String) {
        emitState("error", errorMessage = message)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
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

    private fun buildNotification(): Notification {
        val appLabel = applicationInfo.loadLabel(packageManager).toString()
        val stopIntent = Intent(this, LocalRecordingService::class.java)
            .setAction(ACTION_STOP)
        val stopPendingIntent = PendingIntent.getService(
            this,
            STOP_REQUEST_CODE,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(appLabel)
            .setContentText(appLabel)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .addAction(0, appLabel, stopPendingIntent)
            .build()
    }

    companion object {
        private const val ACTION_START =
            "com.savestream.app.localrecording.START"
        private const val ACTION_STOP =
            "com.savestream.app.localrecording.STOP"
        private const val ACTION_RECOVER =
            "com.savestream.app.localrecording.RECOVER"
        private const val EXTRA_SESSION_ID = "session_id"
        private const val EXTRA_WATCH_ID = "watch_id"
        private const val EXTRA_DEVICE_ID = "device_id"
        private const val EXTRA_STREAM_URL = "stream_url"
        private const val EXTRA_STREAM_FORMAT = "stream_format"
        private const val EXTRA_STREAM_HEADERS = "stream_headers"
        private const val EXTRA_GRANTED_SECONDS = "granted_seconds"
        private const val CHANNEL_ID = "savestream_local_recording"
        private const val NOTIFICATION_ID = 3201
        private const val STOP_REQUEST_CODE = 3202
        private const val CONNECT_TIMEOUT_MS = 15_000
        private const val READ_TIMEOUT_MS = 15_000
        private const val BUFFER_SIZE = 64 * 1024
        private const val MAX_RECONNECT_ATTEMPTS = 5
        private const val MAX_CHUNK_GAP_MS = 2_000L
        private const val CRITICAL_STORAGE_BYTES = 250L * 1024L * 1024L

        fun findInterrupted(context: Context): Map<String, Any?>? {
            val root = File(context.filesDir, "local_recordings")
            if (!root.exists()) {
                return null
            }
            val candidates = root.walkTopDown()
                .filter { it.isFile && it.extension == "json" }
                .mapNotNull { metadataFile ->
                    try {
                        val metadata = JSONObject(metadataFile.readText())
                        val sessionId = metadata.optString("session_id")
                        val partFile = File(metadataFile.parentFile, "$sessionId.part")
                        val pending = metadata.optBoolean("needs_registration", false)
                        if (!partFile.exists() && !pending) {
                            null
                        } else {
                            metadata to metadataFile
                        }
                    } catch (_: Exception) {
                        null
                    }
                }
                .maxByOrNull { (metadata, _) ->
                    metadata.optLong("started_at_ms", 0L)
                }
                ?: return null
            val metadata = candidates.first
            val metadataFile = candidates.second
            val sessionId = metadata.optString("session_id")
            val partFile = File(metadataFile.parentFile, "$sessionId.part")
            val interruptedAt = metadata.optLong(
                "interrupted_at_ms",
                if (partFile.exists()) partFile.lastModified() else System.currentTimeMillis(),
            )
            return mapOf(
                "temp_id" to sessionId,
                "watch_id" to metadata.optString("watch_id"),
                "started_at_ms" to metadata.optLong("started_at_ms"),
                "interrupted_at_ms" to interruptedAt,
                "recorded_seconds" to metadata.optInt("recorded_seconds", 0),
                "size_bytes" to metadata.optLong("size_bytes", partFile.length()),
                "end_reason" to metadata.optString("end_reason", "interrupted"),
            )
        }

        fun markRegistered(context: Context, sessionId: String) {
            val root = File(context.filesDir, "local_recordings")
            val metadataFile = root.walkTopDown().firstOrNull {
                it.isFile && it.name == "$sessionId.json"
            } ?: return
            try {
                val metadata = JSONObject(metadataFile.readText())
                metadata.put("needs_registration", false)
                metadataFile.writeText(metadata.toString())
            } catch (_: Exception) {
                return
            }
        }

        fun deleteInterrupted(context: Context, sessionId: String) {
            val root = File(context.filesDir, "local_recordings")
            val metadataFile = root.walkTopDown().firstOrNull {
                it.isFile && it.name == "$sessionId.json"
            } ?: return
            val parent = metadataFile.parentFile
            File(parent, "$sessionId.part").delete()
            metadataFile.delete()
        }

        fun updateNotification(
            context: Context,
            title: String,
            body: String,
            ongoing: Boolean,
        ) {
            val stopIntent = Intent(context, LocalRecordingService::class.java)
                .setAction(ACTION_STOP)
            val stopPendingIntent = PendingIntent.getService(
                context,
                STOP_REQUEST_CODE,
                stopIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(context.applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(body)
                .setOngoing(ongoing)
                .setOnlyAlertOnce(true)
                .setCategory(NotificationCompat.CATEGORY_PROGRESS)
                .addAction(0, title, stopPendingIntent)
                .build()
            context.getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION_ID, notification)
        }

        fun clearNotification(context: Context) {
            context.getSystemService(NotificationManager::class.java)
                .cancel(NOTIFICATION_ID)
        }

        fun start(
            context: Context,
            sessionId: String,
            watchId: String,
            deviceId: String,
            streamUrl: String,
            streamFormat: String,
            streamHeaders: String,
            grantedSeconds: Int,
        ) {
            val intent = Intent(context, LocalRecordingService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_SESSION_ID, sessionId)
                .putExtra(EXTRA_WATCH_ID, watchId)
                .putExtra(EXTRA_DEVICE_ID, deviceId)
                .putExtra(EXTRA_STREAM_URL, streamUrl)
                .putExtra(EXTRA_STREAM_FORMAT, streamFormat)
                .putExtra(EXTRA_STREAM_HEADERS, streamHeaders)
                .putExtra(EXTRA_GRANTED_SECONDS, grantedSeconds)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, LocalRecordingService::class.java)
                .setAction(ACTION_STOP)
            context.startService(intent)
        }

        fun recover(context: Context, sessionId: String) {
            val intent = Intent(context, LocalRecordingService::class.java)
                .setAction(ACTION_RECOVER)
                .putExtra(EXTRA_SESSION_ID, sessionId)
            ContextCompat.startForegroundService(context, intent)
        }
    }
}
