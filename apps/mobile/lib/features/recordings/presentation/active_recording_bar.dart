import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/local_recorder.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../home/presentation/controllers/home_dashboard_controller.dart';
import '../../local_recordings/presentation/controllers/local_recording_controller.dart';
import '../domain/models/recording_summary.dart';

class ActiveRecordingBarItem {
  const ActiveRecordingBarItem({
    required this.id,
    required this.creatorName,
    required this.engine,
    required this.elapsedSeconds,
    required this.route,
  });

  final String id;
  final String creatorName;
  final Engine engine;
  final int elapsedSeconds;
  final String route;
}

final Provider<List<ActiveRecordingBarItem>> activeRecordingBarItemsProvider =
    Provider<List<ActiveRecordingBarItem>>((Ref ref) {
      final dashboard = ref.watch(homeDashboardProvider).value;
      final LocalRecordingController localController = ref.watch(
        localRecordingControllerProvider,
      );
      final LocalRecorderState? primary = ref
          .watch(localRecorderStateProvider)
          .value;
      final LocalRecorderState? secondary = ref
          .watch(secondaryLocalRecorderStateProvider)
          .value;
      final List<ActiveRecordingBarItem> items = <ActiveRecordingBarItem>[];

      String creatorNameForWatch(String watchId) {
        if (dashboard != null) {
          for (final watch in dashboard.watches) {
            if (watch.id == watchId) return watch.creatorDisplayName;
          }
        }
        return watchId;
      }

      final primarySession = localController.activeSession;
      if (primarySession != null && _isActiveLocalPhase(primary?.phase)) {
        items.add(
          ActiveRecordingBarItem(
            id: primarySession.sessionId,
            creatorName: creatorNameForWatch(primarySession.watchId),
            engine: Engine.local,
            elapsedSeconds: primary?.recordedSeconds ?? 0,
            route: AppRoutes.localRecording(primarySession.watchId),
          ),
        );
      }

      final secondarySession = localController.secondarySession;
      if (secondarySession != null && _isActiveLocalPhase(secondary?.phase)) {
        items.add(
          ActiveRecordingBarItem(
            id: secondarySession.sessionId,
            creatorName: creatorNameForWatch(secondarySession.watchId),
            engine: Engine.local,
            elapsedSeconds: secondary?.recordedSeconds ?? 0,
            route: AppRoutes.localRecording(secondarySession.watchId),
          ),
        );
      }

      if (dashboard != null) {
        for (final RecordingSummary recording in dashboard.recordings) {
          if (recording.engine != Engine.cloud ||
              (recording.status != RecordingStatus.recording &&
                  recording.status != RecordingStatus.reconnecting)) {
            continue;
          }
          items.add(
            ActiveRecordingBarItem(
              id: recording.id,
              creatorName: recording.creatorDisplayName,
              engine: Engine.cloud,
              elapsedSeconds: recording.durationSeconds,
              route: AppRoutes.recordingDetail(recording.id),
            ),
          );
        }
      }

      return List<ActiveRecordingBarItem>.unmodifiable(items);
    });

bool _isActiveLocalPhase(LocalRecorderPhase? phase) {
  return phase == LocalRecorderPhase.starting ||
      phase == LocalRecorderPhase.recording ||
      phase == LocalRecorderPhase.reconnecting;
}

class ActiveRecordingBar extends StatelessWidget {
  const ActiveRecordingBar({required this.items, super.key});

  final List<ActiveRecordingBarItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final ActiveRecordingBarItem first = items.first;
    final String label = items.length == 1
        ? context.l10n.recordingBarSingle(first.creatorName)
        : context.l10n.recordingBarMultiple(items.length);
    final String elapsed = items.length == 1
        ? formatDurationHms(Duration(seconds: first.elapsedSeconds))
        : items
              .take(2)
              .map(
                (ActiveRecordingBarItem item) =>
                    formatDurationHms(Duration(seconds: item.elapsedSeconds)),
              )
              .join(' · ');

    return SsRecordingBar(
      label: label,
      elapsed: elapsed,
      onTap: () {
        if (items.length == 1) {
          context.push(first.route);
          return;
        }
        showModalBottomSheet<void>(
          context: context,
          builder: (BuildContext sheetContext) {
            return SsBottomSheet(
              title: context.l10n.recordingBarMultiple(items.length),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final ActiveRecordingBarItem item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SsSpacing.sm),
                      child: SsRecordingTile(
                        title: item.creatorName,
                        subtitle: formatDurationHms(
                          Duration(seconds: item.elapsedSeconds),
                        ),
                        engine: item.engine,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          context.push(item.route);
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
