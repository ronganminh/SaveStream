package com.savestream.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val deviceInfoChannel = "savestream/device_info"
    private val pushChannel = "savestream/push"

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
    }
}
