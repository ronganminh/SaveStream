package com.savestream.app

import io.flutter.plugin.common.EventChannel

object LocalRecordingEventBus {
    @Volatile
    private var sink: EventChannel.EventSink? = null

    fun attach(eventSink: EventChannel.EventSink?) {
        sink = eventSink
    }

    fun emit(event: Map<String, Any?>) {
        sink?.success(event)
    }
}
