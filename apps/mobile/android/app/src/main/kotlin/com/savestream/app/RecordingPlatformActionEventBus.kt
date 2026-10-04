package com.savestream.app

import io.flutter.plugin.common.EventChannel

object RecordingPlatformActionEventBus {
    @Volatile
    private var sink: EventChannel.EventSink? = null

    fun attach(eventSink: EventChannel.EventSink?) {
        sink = eventSink
    }

    fun emit(action: String) {
        sink?.success(action)
    }
}
