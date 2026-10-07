import 'dart:async';

import 'package:flutter/services.dart';

import '../app/router/app_routes.dart';

class ForegroundPushMessage {
  const ForegroundPushMessage({
    required this.title,
    required this.body,
    required this.kind,
    this.resourceType,
    this.resourceId,
  });

  final String title;
  final String body;
  final String kind;
  final String? resourceType;
  final String? resourceId;
}

abstract final class PushRuntime {
  static const MethodChannel _channel = MethodChannel('savestream/push');

  static Future<void> configureAndroidChannels({
    required String liveName,
    required String recordingName,
  }) {
    return _channel.invokeMethod<void>('configureChannels', <String, String>{
      'live_name': liveName,
      'recording_name': recordingName,
    });
  }

  static String routeFor({
    required String kind,
    String? resourceType,
    String? resourceId,
  }) {
    final String? id = resourceId?.trim();
    return switch (resourceType) {
      'watch' when id != null && id.isNotEmpty =>
        kind == 'creator_live'
            ? AppRoutes.liveNotification(id)
            : AppRoutes.channelDetail(id),
      'recording' when id != null && id.isNotEmpty => AppRoutes.recordingDetail(
        id,
      ),
      _ => AppRoutes.notifications,
    };
  }
}
