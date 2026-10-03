package com.savestream.app

import android.os.Bundle
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val deviceInfoChannel = "savestream/device_info"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        MethodChannel(
            flutterEngine!!.dartExecutor.binaryMessenger,
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
