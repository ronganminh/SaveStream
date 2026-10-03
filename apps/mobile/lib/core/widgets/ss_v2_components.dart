import 'package:flutter/material.dart';

import '../../app/theme/ss_tokens.dart';
import '../../features/entitlement/domain/models/entitlement.dart';
import 'ss_surfaces.dart';

class SsLocationChip extends StatelessWidget {
  const SsLocationChip({required this.engine, this.label, super.key});
  final Engine engine;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final bool local = engine == Engine.local;
    return SsStatusChip(
      label: label ?? (local ? 'Local' : 'Cloud'),
      icon: local ? Icons.smartphone_rounded : Icons.cloud_rounded,
    );
  }
}

class SsPlanBadge extends StatelessWidget {
  const SsPlanBadge({required this.plan, super.key});
  final Plan plan;

  @override
  Widget build(BuildContext context) => SsStatusChip(
        label: plan == Plan.pro ? 'PRO' : 'FREE',
        icon: plan == Plan.pro ? Icons.workspace_premium_rounded : null,
      );
}

class SsLiveBadge extends StatelessWidget {
  const SsLiveBadge({required this.isLive, super.key});
  final bool isLive;

  @override
  Widget build(BuildContext context) => SsStatusChip(
        label: isLive ? 'LIVE' : 'OFFLINE',
        tone: isLive ? SsStatusTone.recording : SsStatusTone.neutral,
      );
}

class SsQuotaCard extends StatelessWidget {
  const SsQuotaCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.progress,
    super.key,
  });

  final String title;
  final String value;
  final String? subtitle;
  final double? progress;

  @override
  Widget build(BuildContext context) => SsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: SsSpacing.sm),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: SsSpacing.xs),
              Text(subtitle!),
            ],
            if (progress != null) ...<Widget>[
              const SizedBox(height: SsSpacing.md),
              LinearProgressIndicator(
                value: progress! < 0
                    ? 0.0
                    : progress! > 1
                    ? 1.0
                    : progress!,
              ),
            ],
          ],
        ),
      );
}

class SsCreatorTile extends StatelessWidget {
  const SsCreatorTile({
    required this.name,
    required this.handle,
    this.isLive = false,
    this.trailing,
    this.onTap,
    super.key,
  });
  final String name;
  final String handle;
  final bool isLive;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SsCard(
        child: SsListTile(
          title: name,
          subtitle: handle,
          leading: SsAvatar(label: name),
          trailing: trailing ?? SsLiveBadge(isLive: isLive),
          onTap: onTap,
        ),
      );
}

class SsRecordingTile extends StatelessWidget {
  const SsRecordingTile({
    required this.title,
    required this.subtitle,
    required this.engine,
    this.onTap,
    super.key,
  });
  final String title;
  final String subtitle;
  final Engine engine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SsListTile(
        title: title,
        subtitle: subtitle,
        trailing: SsLocationChip(engine: engine),
        onTap: onTap,
      );
}

class SsActiveRecordingCard extends StatelessWidget {
  const SsActiveRecordingCard({
    required this.creatorName,
    required this.elapsed,
    required this.engine,
    this.onTap,
    super.key,
  });
  final String creatorName;
  final String elapsed;
  final Engine engine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SsCard(
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: <Widget>[
              SsAvatar(label: creatorName),
              const SizedBox(width: SsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(creatorName),
                    Semantics(
                      label: 'Recording timer',
                      value: elapsed,
                      child: Text(
                        elapsed,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
              ),
              SsLocationChip(engine: engine),
            ],
          ),
        ),
      );
}

class SsRecordingBar extends StatelessWidget {
  const SsRecordingBar({
    required this.label,
    required this.elapsed,
    this.onTap,
    super.key,
  });
  final String label;
  final String elapsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.inverseSurface,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SsSpacing.lg,
                vertical: SsSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.fiber_manual_record_rounded, size: 14),
                  const SizedBox(width: SsSpacing.sm),
                  Expanded(child: Text(label)),
                  Text(elapsed),
                ],
              ),
            ),
          ),
        ),
      );
}

enum SsInlineAlertTone { info, success, warning, error }

class SsInlineAlert extends StatelessWidget {
  const SsInlineAlert({
    required this.title,
    this.message,
    this.tone = SsInlineAlertTone.info,
    super.key,
  });
  final String title;
  final String? message;
  final SsInlineAlertTone tone;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (tone) {
      SsInlineAlertTone.info => Icons.info_outline_rounded,
      SsInlineAlertTone.success => Icons.check_circle_outline_rounded,
      SsInlineAlertTone.warning => Icons.warning_amber_rounded,
      SsInlineAlertTone.error => Icons.error_outline_rounded,
    };
    return Semantics(
      container: true,
      liveRegion: tone == SsInlineAlertTone.warning || tone == SsInlineAlertTone.error,
      child: SsCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon),
            const SizedBox(width: SsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  if (message != null) Text(message!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SsFilterChips extends StatelessWidget {
  const SsFilterChips({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < items.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: SsSpacing.sm),
              ChoiceChip(
                label: Text(items[i]),
                selected: i == selectedIndex,
                onSelected: (_) => onSelected(i),
              ),
            ],
          ],
        ),
      );
}

class SsBannerAdSlot extends StatelessWidget {
  const SsBannerAdSlot({this.label = 'Advertisement', super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 60),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: SsRadii.card,
        ),
        child: Text(label),
      );
}

class SsBottomSheet extends StatelessWidget {
  const SsBottomSheet({required this.title, required this.child, super.key});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SsSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: SsSpacing.lg),
              child,
            ],
          ),
        ),
      );
}

abstract final class SsToast {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class SsChecklistItem {
  const SsChecklistItem({required this.label, this.done = false});
  final String label;
  final bool done;
}

class SsChecklist extends StatelessWidget {
  const SsChecklist({required this.items, super.key});
  final List<SsChecklistItem> items;

  @override
  Widget build(BuildContext context) => Column(
        children: items
            .map(
              (SsChecklistItem item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
                title: Text(item.label),
              ),
            )
            .toList(growable: false),
      );
}
