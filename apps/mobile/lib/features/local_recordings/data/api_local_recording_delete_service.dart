import '../../../../core/api/api_client.dart';

final class ApiLocalRecordingDeleteService {
  const ApiLocalRecordingDeleteService({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<void> delete({
    required String recordingId,
    required String deviceId,
  }) async {
    await _apiClient.delete<Object?>(
      '/v1/local-recordings/${Uri.encodeComponent(recordingId)}',
      queryParameters: <String, dynamic>{'device_id': deviceId},
      decoder: (_) => null,
    );
  }
}
