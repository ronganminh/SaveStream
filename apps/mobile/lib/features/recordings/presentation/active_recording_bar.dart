import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../home/presentation/controllers/home_dashboard_controller.dart';
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
      final List<ActiveRecordingBarItem> items = <ActiveRecordingBarItem>[];

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
