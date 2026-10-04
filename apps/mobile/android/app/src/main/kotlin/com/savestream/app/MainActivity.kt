package com.savestream.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.StatFs
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val deviceInfoChannel = "savestream/device_info"
    private val localRecordingChannel = "savestream/local_recording"
    private val localRecordingEvents = "savestream/local_recording/events"
    private val recordingPlatformChannel = "savestream/recording_platform"
    private val recordingPlatformActions = "savestream/recording_platform/actions"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            localRecordingEvents,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    LocalRecordingEventBus.attach(events)
                }

                override fun onCancel(arguments: Any?) {
                    LocalRecordingEventBus.attach(null)
                }
            },
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            localRecordingChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val args = call.arguments as? Map<*, *>
                    val sessionId = args?.get("session_id") as? String
                    val userId = args?.get("user_id") as? String
                    val watchId = args?.get("watch_id") as? String
                    val deviceId = args?.get("device_id") as? String
                    val streamUrl = args?.get("stream_url") as? String
                    val streamFormat = args?.get("stream_format") as? String
                    val grantedSeconds = args?.get("granted_seconds") as? Int
                    val rawHeaders = args?.get("stream_headers") as? Map<*, *>
                    if (
                        sessionId == null ||
                            userId == null ||
                            watchId == null ||
                            deviceId == null ||
                            streamUrl == null ||
                            streamFormat == null ||
                            grantedSeconds == null
                    ) {
                        result.error("INVALID_ARGUMENTS", "Missing local recording arguments.", null)
                    } else {
                        val headers = rawHeaders
                            ?.entries
                            ?.associate { it.key.toString() to it.value.toString() }
                            ?: emptyMap()
                        LocalRecordingService.start(
                            context = this,
                            sessionId = sessionId,
                            userId = userId,
                            watchId = watchId,
                            deviceId = deviceId,
                            streamUrl = streamUrl,
                            streamFormat = streamFormat,
                            streamHeaders = JSONObject(headers).toString(),
                            grantedSeconds = grantedSeconds,
                        )
                        result.success(null)
                    }
                }
                "stop" -> {
                    LocalRecordingService.stop(this)
                    result.success(null)
                }
                "recover" -> {
                    val sessionId = call.argument<String>("session_id")
                    val userId = call.argument<String>("user_id")
                    if (sessionId == null || userId == null) {
                        result.error("INVALID_ARGUMENTS", "Missing recovery identity.", null)
                    } else {
                        LocalRecordingService.recover(this, userId, sessionId)
                        result.success(null)
                    }
                }
                "findInterrupted" -> {
                    val userId = call.argument<String>("user_id")
                    if (userId == null) {
                        result.error("INVALID_ARGUMENTS", "Missing user id.", null)
                    } else {
                        result.success(
                            LocalRecordingService.findInterrupted(this, userId),
                        )
                    }
                }
                "markRegistered" -> {
                    val sessionId = call.argument<String>("session_id")
                    val userId = call.argument<String>("user_id")
                    if (sessionId == null || userId == null) {
                        result.error("INVALID_ARGUMENTS", "Missing registration identity.", null)
                    } else {
                        LocalRecordingService.markRegistered(this, userId, sessionId)
                        result.success(null)
                    }
                }
                "deleteInterrupted" -> {
                    val sessionId = call.argument<String>("session_id")
                    val userId = call.argument<String>("user_id")
                    if (sessionId == null || userId == null) {
                        result.error("INVALID_ARGUMENTS", "Missing interrupted identity.", null)
                    } else {
                        LocalRecordingService.deleteInterrupted(this, userId, sessionId)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            recordingPlatformActions,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    RecordingPlatformActionEventBus.attach(events)
                }

                override fun onCancel(arguments: Any?) {
                    RecordingPlatformActionEventBus.attach(null)
                }
            },
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            recordingPlatformChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "androidState" -> {
                    val powerManager = getSystemService(PowerManager::class.java)
                    result.success(
                        mapOf(
                            "battery_mode" to if (
                                powerManager.isIgnoringBatteryOptimizations(packageName)
                            ) {
                                "unrestricted"
                            } else {
                                "optimized"
                            },
                            "oem_family" to oemFamily(),
                            "device_name" to Build.MODEL,
                            "os_name" to "Android " + Build.VERSION.RELEASE,
                        ),
                    )
                }
                "openBatterySettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }
                "openAppSettings" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:" + packageName),
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title").orEmpty()
                    val body = call.argument<String>("body").orEmpty()
                    val ongoing = call.argument<Boolean>("ongoing") ?: true
                    LocalRecordingService.updateNotification(
                        context = this,
                        title = title,
                        body = body,
                        ongoing = ongoing,
                    )
                    result.success(null)
                }
                "clearNotification" -> {
                    LocalRecordingService.clearNotification(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun oemFamily(): String {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return when {
            manufacturer.contains("xiaomi") -> "xiaomi"
            manufacturer.contains("samsung") -> "samsung"
            manufacturer.contains("oppo") ||
                manufacturer.contains("realme") ||
                manufacturer.contains("vivo") -> "oppo_realme_vivo"
            manufacturer.contains("huawei") ||
                manufacturer.contains("honor") -> "huawei"
            else -> "generic"
        }
    }
}
