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
      tone: local ? SsStatusTone.local : SsStatusTone.cloud,
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
    this.metrics = const <SsQuotaMetric>[],
    super.key,
  });

  final String title;
  final String value;
  final String? subtitle;
  final double? progress;
  final List<SsQuotaMetric> metrics;

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
        if (metrics.isNotEmpty) ...<Widget>[
          const SizedBox(height: SsSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int index = 0; index < metrics.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: SsSpacing.sm),
                Expanded(child: _SsQuotaMetricCell(metric: metrics[index])),
              ],
            ],
          ),
        ],
      ],
    ),
  );
}

class SsQuotaMetric {
  const SsQuotaMetric({required this.label, required this.value});

  final String label;
  final String value;
}

class _SsQuotaMetricCell extends StatelessWidget {
  const _SsQuotaMetricCell({required this.metric});

  final SsQuotaMetric metric;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: SsRadii.field,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SsSpacing.md,
          vertical: SsSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(metric.value, style: SsTypography.mono),
          ],
        ),
      ),
    );
  }
}

class SsCreatorTile extends StatelessWidget {
  const SsCreatorTile({
    required this.name,
    required this.handle,
    this.isLive = false,
    this.imageUrl,
    this.trailing,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.onTap,
    super.key,
  });
  final String name;
  final String handle;
  final bool isLive;
  final String? imageUrl;
  final Widget? trailing;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SsCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SsListTile(
          title: name,
          subtitle: handle,
          leading: SsAvatar(
            label: name,
            imageUrl: imageUrl,
            radius: 22,
            isLive: isLive,
          ),
          trailing: trailing ?? SsLiveBadge(isLive: isLive),
          onTap: onTap,
        ),
        if (actionLabel != null) ...<Widget>[
          const SizedBox(height: SsSpacing.sm),
          FilledButton.icon(
            onPressed: onAction,
            icon: Icon(actionIcon ?? Icons.arrow_forward_rounded),
            label: Text(actionLabel!),
          ),
        ],
      ],
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
                    style: SsTypography.timer.copyWith(fontSize: 24),
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
              Text(elapsed, style: SsTypography.mono),
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
    this.icon,
    super.key,
  });
  final String title;
  final String? message;
  final SsInlineAlertTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final IconData resolvedIcon =
        icon ??
        switch (tone) {
          SsInlineAlertTone.info => Icons.info_outline_rounded,
          SsInlineAlertTone.success => Icons.check_circle_outline_rounded,
          SsInlineAlertTone.warning => Icons.warning_amber_rounded,
          SsInlineAlertTone.error => Icons.error_outline_rounded,
        };
    return Semantics(
      container: true,
      liveRegion:
          tone == SsInlineAlertTone.warning || tone == SsInlineAlertTone.error,
      child: SsCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(resolvedIcon),
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
  const SsChecklistItem({
    required this.label,
    this.done = false,
    this.active = false,
  });
  final String label;
  final bool done;
  final bool active;
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
                  : item.active
                  ? Icons.sync_rounded
                  : Icons.radio_button_unchecked_rounded,
            ),
            title: Text(item.label),
          ),
        )
        .toList(growable: false),
  );
}
