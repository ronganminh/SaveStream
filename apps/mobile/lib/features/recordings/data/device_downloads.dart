import 'dart:io';

import 'package:flutter/services.dart';

/// A recording saved on this device.
final class SavedRecordingCopy {
  const SavedRecordingCopy({required this.location, this.sizeBytes});

  /// A `content://` URI (Android MediaStore, Downloads/SaveStream) or a file
  /// path (iOS app storage; Android 9 and older app-specific Downloads).
  final String location;
  final int? sizeBytes;

  bool get isContentUri => location.startsWith('content://');
}

/// The public Downloads/SaveStream folder.
abstract interface class DeviceDownloads {
  /// Copies [source] into Downloads/SaveStream as [displayName].
  Future<SavedRecordingCopy> save({
    required File source,
    required String displayName,
    String mimeType = 'video/mp4',
  });

  /// The finished copy named [displayName] that this app saved, if it is
  /// still there.
  Future<SavedRecordingCopy?> find(String displayName);
}

/// Android host side: `MainActivity` / `SaveStreamDownloads.kt`.
///
/// Android 10+ writes through `MediaStore.Downloads` (RELATIVE_PATH
/// `Download/SaveStream`, IS_PENDING while writing) and needs no storage
/// permission. Android 7–9 falls back to the app-specific
/// `getExternalFilesDir(DIRECTORY_DOWNLOADS)/SaveStream`, also without a
/// permission.
final class AndroidDeviceDownloads implements DeviceDownloads {
  const AndroidDeviceDownloads();

  static const MethodChannel _channel = MethodChannel('savestream/downloads');

  @override
  Future<SavedRecordingCopy> save({
    required File source,
    required String displayName,
    String mimeType = 'video/mp4',
  }) async {
    final Map<Object?, Object?>? result = await _channel
        .invokeMethod<Map<Object?, Object?>>('save', <String, Object?>{
          'source_path': source.path,
          'display_name': displayName,
          'mime_type': mimeType,
        });
    final SavedRecordingCopy? copy = _parse(result);
    if (copy == null) {
      throw StateError('Saving to Downloads returned no location.');
    }
    return copy;
  }

  @override
  Future<SavedRecordingCopy?> find(String displayName) async {
    final Map<Object?, Object?>? result = await _channel
        .invokeMethod<Map<Object?, Object?>>('find', <String, Object?>{
          'display_name': displayName,
        });
    return _parse(result);
  }

  static SavedRecordingCopy? _parse(Map<Object?, Object?>? result) {
    final Object? location = result?['uri'] ?? result?['path'];
    if (location is! String || location.isEmpty) return null;
    final Object? size = result?['size_bytes'];
    return SavedRecordingCopy(
      location: location,
      sizeBytes: size is int ? size : null,
    );
  }
}
