import 'package:flutter/services.dart';

const MethodChannel androidLocalRecordingMethodChannel = MethodChannel(
  'savestream/local_recording',
);
const EventChannel androidLocalRecordingEventChannel = EventChannel(
  'savestream/local_recording/events',
);
const MethodChannel androidRecordingPlatformMethodChannel = MethodChannel(
  'savestream/recording_platform',
);
const EventChannel androidRecordingPlatformActionEventChannel = EventChannel(
  'savestream/recording_platform/actions',
);

final Stream<dynamic> androidLocalRecordingEvents =
    androidLocalRecordingEventChannel
        .receiveBroadcastStream()
        .asBroadcastStream();
