import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/router/app_routes.dart';
import 'package:savestream_mobile/platform/push_runtime.dart';

void main() {
  test('C8 routes creator LIVE pushes to live notification screen', () {
    expect(
      PushRuntime.routeFor(
        kind: 'creator_live',
        resourceType: 'watch',
        resourceId: 'watch-1',
      ),
      AppRoutes.liveNotification('watch-1'),
    );
  });

  test('C8 routes recording pushes to recording detail', () {
    expect(
      PushRuntime.routeFor(
        kind: 'recording_ready',
        resourceType: 'recording',
        resourceId: 'rec-1',
      ),
      AppRoutes.recordingDetail('rec-1'),
    );
  });

  test('C8 falls back to notifications when push resource is absent', () {
    expect(
      PushRuntime.routeFor(kind: 'purchase_completed'),
      AppRoutes.notifications,
    );
  });
}
