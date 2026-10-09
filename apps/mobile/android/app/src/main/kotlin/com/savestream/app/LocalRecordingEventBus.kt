package com.savestream.app

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object LocalRecordingEventBus {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var sink: EventChannel.EventSink? = null

    fun attach(eventSink: EventChannel.EventSink?) {
        sink = eventSink
    }

    fun emit(event: Map<String, Any?>) {
        // The recorder runs on a background executor, whereas Flutter's
        // EventSink must only be called on Android's main thread. Calling it
        // directly can silently lose terminal states and leave Dart waiting
        // forever for a stop/error event.
        mainHandler.post {
            sink?.success(event)
        }
    }
}
