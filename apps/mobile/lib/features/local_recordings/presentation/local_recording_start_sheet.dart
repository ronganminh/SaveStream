/// R01-android/R01-ios — Local recording start confirmation.
import 'package:flutter/material.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../devices/domain/models/device_registration.dart';
import '../../entitlement/domain/models/entitlement.dart';

Future<bool> showLocalRecordingStartSheet({
  required BuildContext context,
  required String creatorName,
  required Entitlement entitlement,
  required DevicePlatform platform,
  required int freeStorageBytes,
}) async {
  final bool? confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => LocalRecordingStartSheetBody(
      creatorName: creatorName,
      entitlement: entitlement,
      platform: platform,
      freeStorageBytes: freeStorageBytes,
      onConfirm: () => Navigator.of(sheetContext).pop(true),
      onCancel: () => Navigator.of(sheetContext).pop(false),
    ),
  );
  return confirmed ?? false;
}

class LocalRecordingStartSheetBody extends StatelessWidget {
  const LocalRecordingStartSheetBody({
    required this.creatorName,
    required this.entitlement,
    required this.platform,
    required this.freeStorageBytes,
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });

  final String creatorName;
  final Entitlement entitlement;
  final DevicePlatform platform;
  final int freeStorageBytes;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final bool android = platform == DevicePlatform.android;
    return SsBottomSheet(
      title: context.l10n.localRecordingStartTitle(creatorName),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsLocationChip(engine: Engine.local, label: context.l10n.localLabel),
          const SizedBox(height: SsSpacing.md),
          Text(
            context.l10n.localRecordingFreeStorage(
              formatFileSize(freeStorageBytes),
            ),
          ),
          const SizedBox(height: SsSpacing.sm),
          Text(
            context.l10n.homeFreeMinutesRemaining(
              entitlement.local.minutesRemaining,
              entitlement.local.dailyMinutes,
            ),
          ),
          const SizedBox(height: SsSpacing.sm),
          Text(context.l10n.localRecordingSlot(0, 1)),
          const SizedBox(height: SsSpacing.lg),
          SsInlineAlert(
            title: android
                ? context.l10n.localRecordingAndroidStartTitle
                : context.l10n.nativeKeepAppOpenReminderTitle,
            message: android
                ? context.l10n.localRecordingAndroidStartBody
                : context.l10n.nativeKeepAppOpenReminderBody,
          ),
          const SizedBox(height: SsSpacing.lg),
          SsPrimaryButton(
            label: context.l10n.localRecordingStartAction,
            icon: Icons.fiber_manual_record_rounded,
            onPressed: entitlement.local.minutesRemaining > 0
                ? onConfirm
                : null,
          ),
          const SizedBox(height: SsSpacing.sm),
          SsSecondaryButton(
            label: context.l10n.cancelAction,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
