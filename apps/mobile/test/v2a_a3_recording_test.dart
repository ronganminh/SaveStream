import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/mock/mock_providers.dart';
import 'package:savestream_mobile/core/mock/mock_scenario.dart';
import 'package:savestream_mobile/features/channels/domain/models/watch_summary.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/controllers/local_recording_controller.dart';

void main() {
  const MockBehavior behavior = MockBehavior(
    scenario: MockScenario.success,
    latency: Duration.zero,
  );
  const WatchSummary liveWatch = WatchSummary(
    id: 'watch_a3',
    creatorDisplayName: 'Lina Studio',
    creatorUsername: '@linastudio',
    status: WatchStatus.active,
    isLive: true,
  );

  test('A3 local controller starts and safely finalizes a recording', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        mockBehaviorProvider.overrideWithValue(behavior),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(localRecordingControllerProvider.notifier)
        .start(liveWatch);
    await Future<void>.delayed(Duration.zero);

    final LocalRecordingFlowState active = container.read(
      localRecordingControllerProvider,
    );
    expect(active.watchId, liveWatch.id);
    expect(active.session?.grantedSeconds, 600);
    expect(active.remainingSeconds, 600);

    await container.read(localRecordingControllerProvider.notifier).stop();

    final LocalRecordingFlowState completed = container.read(
      localRecordingControllerProvider,
    );
    expect(completed.phase, LocalRecordingFlowPhase.completed);
    expect(completed.completed?.watchId, liveWatch.id);
  });
}
