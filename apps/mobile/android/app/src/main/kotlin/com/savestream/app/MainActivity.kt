package com.savestream.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val deviceInfoChannel = "savestream/device_info"
    private val pushChannel = "savestream/push"
    private val downloadsChannel = "savestream/downloads"
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            pushChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "configureChannels" -> {
                    val liveName = call.argument<String>("live_name")
                    val recordingName = call.argument<String>("recording_name")
                    if (liveName == null || recordingName == null) {
                        result.error("INVALID_ARGUMENTS", "Missing push channel names.", null)
                    } else {
                        val manager = getSystemService(NotificationManager::class.java)
                        manager.createNotificationChannel(
                            NotificationChannel(
                                "savestream_creator_live",
                                liveName,
                                NotificationManager.IMPORTANCE_HIGH,
                            ),
                        )
                        manager.createNotificationChannel(
                            NotificationChannel(
                                "savestream_recordings",
                                recordingName,
                                NotificationManager.IMPORTANCE_DEFAULT,
                            ),
                        )
                        result.success(null)
                    }
                }
                // "Open settings" when POST_NOTIFICATIONS was denied: the app's
                // notification settings (API 26+), else its App info page.
                "openNotificationSettings" -> {
                    val details = Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", packageName, null),
                    )
                    val candidates = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        listOf(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
                            details,
                        )
                    } else {
                        listOf(details)
                    }
                    val opened = candidates.any { candidate ->
                        try {
                            startActivity(candidate.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            true
                        } catch (error: ActivityNotFoundException) {
                            false
                        }
                    }
                    result.success(opened)
                }
                else -> result.notImplemented()
            }
        }

        // Free-space check used before saving cloud recordings to the device.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceInfoChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "freeStorageBytes" -> {
                    val stats = StatFs(filesDir.absolutePath)
                    result.success(stats.availableBytes)
                }
                else -> result.notImplemented()
            }
        }

        // "Save to device": copies a finished download into Downloads/SaveStream.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            downloadsChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "save" -> {
                    val sourcePath = call.argument<String>("source_path")
                    val displayName = call.argument<String>("display_name")
                    val mimeType = call.argument<String>("mime_type") ?: "video/mp4"
                    if (sourcePath == null || displayName == null) {
                        result.error("INVALID_ARGUMENTS", "Missing source or name.", null)
                    } else {
                        runOffMainThread(result) {
                            SaveStreamDownloads.save(applicationContext, File(sourcePath), displayName, mimeType)
                        }
                    }
                }
                "find" -> {
                    val displayName = call.argument<String>("display_name")
                    if (displayName == null) {
                        result.error("INVALID_ARGUMENTS", "Missing name.", null)
                    } else {
                        runOffMainThread(result) {
                            SaveStreamDownloads.find(applicationContext, displayName)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        ioExecutor.shutdown()
        super.onDestroy()
    }

    private fun runOffMainThread(result: MethodChannel.Result, work: () -> Any?) {
        ioExecutor.execute {
            try {
                val value = work()
                runOnUiThread { result.success(value) }
            } catch (error: Exception) {
                runOnUiThread { result.error("DOWNLOADS_FAILED", error.message, null) }
            }
        }
    }
}
