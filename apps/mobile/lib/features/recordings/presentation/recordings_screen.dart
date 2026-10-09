import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_semantic_colors.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/ads_service.dart';
import '../../../platform/platform_providers.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../local_recordings/presentation/controllers/local_recording_controller.dart';
import '../../settings/presentation/notification_action_button.dart';
import '../domain/models/recording_summary.dart';
import 'controllers/recording_file_providers.dart';
import 'controllers/recording_library_controller.dart';
import 'controllers/recording_providers.dart';
import 'models/recording_library_item.dart';
import 'recording_thumbnail.dart';
import 'recording_ui_helpers.dart';

enum _RecordingLibraryView { content, list }

enum _RecordingLibrarySort { date, expiring, size, name }

enum _RecordingLibraryFilter { all, local, cloud, issues }

enum _RecordingStatusGroup { completed, processing, partial, issues }

/// L01 — Unified local + cloud recording library.
class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  _RecordingLibraryFilter _filter = _RecordingLibraryFilter.all;
  _RecordingLibraryView _view = _RecordingLibraryView.content;
  _RecordingLibrarySort _sort = _RecordingLibrarySort.date;
  Set<_RecordingStatusGroup> _statusGroups = <_RecordingStatusGroup>{};
  String _query = '';
  String? _busyItemId;
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _filter != _RecordingLibraryFilter.all ||
      _statusGroups.isNotEmpty ||
      _sort != _RecordingLibrarySort.date;

  void _clearFilters() {
    setState(() {
      _filter = _RecordingLibraryFilter.all;
      _statusGroups = <_RecordingStatusGroup>{};
      _sort = _RecordingLibrarySort.date;
    });
  }

  void _cancelSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _query = '';
      _searching = false;
    });
  }

  String _routeFor(RecordingLibraryItem item) {
    return item.storage == RecordingLibraryStorage.local
        ? AppRoutes.localRecordingDetail(item.id)
        : AppRoutes.recordingDetail(item.id);
  }

  Uri _playerRouteFor(RecordingLibraryItem item) {
    return Uri.parse(AppRoutes.recordingPlayer(item.id)).replace(
      queryParameters: <String, String>{
        'source': item.storage == RecordingLibraryStorage.local
            ? 'local'
            : 'cloud',
        'title': item.creatorDisplayName,
        'duration': item.durationSeconds.toString(),
        if (item.startedAt != null)
          'started': item.startedAt!.toIso8601String(),
      },
    );
  }

  Future<void> _play(RecordingLibraryItem item) async {
    if (!item.canPlay) return;
    await context.push(_playerRouteFor(item).toString());
  }

  Future<void> _share(RecordingLibraryItem item) async {
    if (!item.canShare || _busyItemId != null) return;
    setState(() => _busyItemId = item.id);
    try {
      if (item.storage == RecordingLibraryStorage.local) {
        final String? filePath = item.filePath;
        if (filePath == null) throw StateError('Local file is unavailable.');
        await ref
            .read(shareServiceProvider)
            .shareFile(
              filePath: filePath,
              displayName: item.creatorDisplayName,
            );
      } else {
        final artifacts = await ref.read(
          recordingArtifactsProvider(item.id).future,
        );
        if (artifacts.isEmpty) throw StateError('Artifact is unavailable.');
        await ref
            .read(cloudRecordingShareCoordinatorProvider)
            .share(
              artifactId: artifacts.first.id,
              displayName: item.creatorDisplayName,
            );
      }
    } on Object {
      if (mounted) {
        SsSnackbar.show(context, context.l10n.artifactOpenFailedMessage);
      }
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  Future<void> _delete(RecordingLibraryItem item) async {
    if (!item.canDelete || _busyItemId != null) return;
    final bool? confirmed = await SsConfirmDialog.show(
      context,
      title: context.l10n.deleteRecordingTitle,
      message: context.l10n.deleteRecordingMessage,
      cancelLabel: context.l10n.cancelAction,
      confirmLabel: context.l10n.deleteRecordingAction,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyItemId = item.id);
    try {
      if (item.storage == RecordingLibraryStorage.local) {
        await ref
            .read(localRecordingRepositoryProvider)
            .delete(item.id, deviceId: item.deviceId!);
      } else {
        await ref.read(recordingControllerProvider).delete(item.id);
        await ref.read(cloudRecordingFileServiceProvider).delete(item.id);
      }
      ref.invalidate(recordingLibraryProvider);
    } on Object catch (error) {
      if (mounted) SsSnackbar.show(context, error.toString());
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  bool _matchesStatusGroups(
    RecordingLibraryItem item,
    Set<_RecordingStatusGroup> groups,
  ) {
    if (groups.isEmpty) return true;
    return groups.any((group) {
      return switch (group) {
        _RecordingStatusGroup.completed =>
          item.status == RecordingStatus.completed,
        _RecordingStatusGroup.processing =>
          item.status == RecordingStatus.starting ||
              item.status == RecordingStatus.queued ||
              item.status == RecordingStatus.resolving ||
              item.status == RecordingStatus.waitingLive ||
              item.status == RecordingStatus.waitingForCloudSlot ||
              item.status == RecordingStatus.recording ||
              item.status == RecordingStatus.processing ||
              item.status == RecordingStatus.uploading ||
              item.status == RecordingStatus.finalizing ||
              item.status == RecordingStatus.stopRequested,
        _RecordingStatusGroup.partial =>
          item.status == RecordingStatus.partial ||
              item.status == RecordingStatus.recovered,
        _RecordingStatusGroup.issues =>
          item.issue != RecordingLibraryIssue.none ||
              item.status == RecordingStatus.failed ||
              item.status == RecordingStatus.missedNoCloudSlot,
      };
    });
  }

  bool _matchesStorage(
    RecordingLibraryItem item,
    _RecordingLibraryFilter filter,
  ) {
    return switch (filter) {
      _RecordingLibraryFilter.all => true,
      _RecordingLibraryFilter.local =>
        item.storage == RecordingLibraryStorage.local,
      _RecordingLibraryFilter.cloud =>
        item.storage == RecordingLibraryStorage.cloud,
      _RecordingLibraryFilter.issues =>
        item.issue != RecordingLibraryIssue.none ||
            item.status == RecordingStatus.failed ||
            item.status == RecordingStatus.missedNoCloudSlot,
    };
  }

  int _filteredCount(
    List<RecordingLibraryItem> items,
    _RecordingLibraryFilter filter,
    Set<_RecordingStatusGroup> statuses,
  ) {
    return items
        .where(
          (item) =>
              _matchesStorage(item, filter) &&
              _matchesStatusGroups(item, statuses),
        )
        .length;
  }

  Future<void> _openFilters(List<RecordingLibraryItem> items) async {
    var draftFilter = _filter == _RecordingLibraryFilter.issues
        ? _RecordingLibraryFilter.all
        : _filter;
    var draftStatuses = Set<_RecordingStatusGroup>.from(_statusGroups);
    if (_filter == _RecordingLibraryFilter.issues) {
      draftStatuses.add(_RecordingStatusGroup.issues);
    }
    var draftSort = _sort;

    final _RecordingFilterSelection?
    result = await showModalBottomSheet<_RecordingFilterSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final int count = _filteredCount(items, draftFilter, draftStatuses);
            void reset() => setSheetState(() {
              draftFilter = _RecordingLibraryFilter.all;
              draftStatuses = <_RecordingStatusGroup>{};
              draftSort = _RecordingLibrarySort.date;
            });

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  SsSpacing.lg,
                  0,
                  SsSpacing.lg,
                  MediaQuery.viewInsetsOf(context).bottom + SsSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            context.l10n.recordingFiltersTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: reset,
                          child: Text(context.l10n.recordingFiltersResetAction),
                        ),
                      ],
                    ),
                    const SizedBox(height: SsSpacing.md),
                    Text(
                      context.l10n.recordingFiltersStorageTitle,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: SsSpacing.sm),
                    SsFilterChips(
                      items: <String>[
                        context.l10n.recordingFilterAll,
                        context.l10n.localLabel,
                        context.l10n.cloudLabel,
                      ],
                      selectedIndex: switch (draftFilter) {
                        _RecordingLibraryFilter.local => 1,
                        _RecordingLibraryFilter.cloud => 2,
                        _ => 0,
                      },
                      onSelected: (int index) => setSheetState(() {
                        draftFilter = <_RecordingLibraryFilter>[
                          _RecordingLibraryFilter.all,
                          _RecordingLibraryFilter.local,
                          _RecordingLibraryFilter.cloud,
                        ][index];
                      }),
                    ),
                    const SizedBox(height: SsSpacing.lg),
                    Text(
                      context.l10n.recordingFiltersStatusTitle,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: SsSpacing.xs),
                    for (final _RecordingStatusGroup group
                        in _RecordingStatusGroup.values)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_statusGroupLabel(context, group)),
                        value: draftStatuses.contains(group),
                        onChanged: (bool? selected) => setSheetState(() {
                          if (selected ?? false) {
                            draftStatuses.add(group);
                          } else {
                            draftStatuses.remove(group);
                          }
                        }),
                      ),
                    const SizedBox(height: SsSpacing.md),
                    Text(
                      context.l10n.recordingFiltersSortTitle,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    RadioGroup<_RecordingLibrarySort>(
                      groupValue: draftSort,
                      onChanged: (_RecordingLibrarySort? value) {
                        if (value != null) {
                          setSheetState(() => draftSort = value);
                        }
                      },
                      child: Column(
                        children: <Widget>[
                          for (final _RecordingLibrarySort sort
                              in _RecordingLibrarySort.values)
                            RadioListTile<_RecordingLibrarySort>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(_sortLabel(context, sort)),
                              value: sort,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: SsSpacing.md),
                    SsPrimaryButton(
                      label: context.l10n.recordingFiltersApplyAction(count),
                      onPressed: () => Navigator.of(context).pop(
                        _RecordingFilterSelection(
                          filter: draftFilter,
                          statuses: draftStatuses,
                          sort: draftSort,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() {
      _filter = result.filter;
      _statusGroups = result.statuses;
      _sort = result.sort;
    });
  }

  String _statusGroupLabel(BuildContext context, _RecordingStatusGroup group) {
    return switch (group) {
      _RecordingStatusGroup.completed =>
        context.l10n.recordingStatusGroupCompleted,
      _RecordingStatusGroup.processing =>
        context.l10n.recordingStatusGroupProcessing,
      _RecordingStatusGroup.partial => context.l10n.recordingStatusGroupPartial,
      _RecordingStatusGroup.issues => context.l10n.recordingStatusGroupIssues,
    };
  }

  String _sortLabel(BuildContext context, _RecordingLibrarySort sort) {
    return switch (sort) {
      _RecordingLibrarySort.date => context.l10n.recordingSortDate,
      _RecordingLibrarySort.expiring => context.l10n.recordingSortExpiring,
      _RecordingLibrarySort.size => context.l10n.recordingSortSize,
      _RecordingLibrarySort.name => context.l10n.recordingSortName,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<RecordingLibraryItem>> library = ref.watch(
      recordingLibraryProvider,
    );
    final bool hasForeignLocalRecordings =
        ref.watch(foreignLocalRecordingOwnershipProvider).value ?? false;
    final Entitlement? entitlement = ref.watch(entitlementProvider).value;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SsLargeHeader(
              title: context.l10n.recordingsTitle,
              subtitle: _hasActiveFilters
                  ? context.l10n.recordingFiltersActiveSubtitle
                  : context.l10n.recordingsRetentionSubtitle(
                      entitlement?.limits.cloudRetentionDays ??
                          (entitlement?.plan == Plan.pro ? 14 : 7),
                    ),
              actions: const <Widget>[NotificationActionButton()],
            ),
            Expanded(
              child: library.when(
                loading: () => const _RecordingsSkeleton(),
                error: (Object error, StackTrace stackTrace) => Center(
                  child: SsAsyncErrorState(
                    error: error,
                    onRetry: () => ref.invalidate(recordingLibraryProvider),
                  ),
                ),
                data: (List<RecordingLibraryItem> items) {
                  final String normalized = _query.trim().toLowerCase();
                  final List<RecordingLibraryItem> visible = items.where((
                    RecordingLibraryItem item,
                  ) {
                    final bool queryMatches =
                        normalized.isEmpty ||
                        item.creatorDisplayName.toLowerCase().contains(
                          normalized,
                        ) ||
                        item.creatorHandle.toLowerCase().contains(normalized);
                    return _matchesStorage(item, _filter) &&
                        _matchesStatusGroups(item, _statusGroups) &&
                        queryMatches;
                  }).toList();
                  final List<_RecordingDateGroup> groups = _groupItems(visible);

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(recordingLibraryProvider);
                      await ref.read(recordingLibraryProvider.future);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        SsSpacing.lg,
                        SsSpacing.md,
                        SsSpacing.lg,
                        SsSpacing.xxl,
                      ),
                      children: <Widget>[
                        if (hasForeignLocalRecordings) ...<Widget>[
                          SsInlineAlert(
                            title: context.l10n.foreignLocalRecordingsTitle,
                            message: context.l10n.foreignLocalRecordingsBody,
                            tone: SsInlineAlertTone.warning,
                          ),
                          const SizedBox(height: SsSpacing.md),
                        ],
                        if (items.isEmpty)
                          _EmptyRecordingLibrary(
                            onAddCreator: () =>
                                context.push(AppRoutes.addChannel),
                            onRecordNow: () => context.go(AppRoutes.channels),
                          )
                        else ...<Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocus,
                                  autofocus: _searching,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                    ),
                                    hintText: context.l10n.recordingSearchHint,
                                    suffixIcon: _query.isEmpty
                                        ? null
                                        : IconButton(
                                            onPressed: _cancelSearch,
                                            icon: const Icon(
                                              Icons.cancel_rounded,
                                            ),
                                          ),
                                  ),
                                  onTap: () =>
                                      setState(() => _searching = true),
                                  onChanged: (String value) =>
                                      setState(() => _query = value),
                                ),
                              ),
                              if (_searching) ...<Widget>[
                                const SizedBox(width: SsSpacing.xs),
                                TextButton(
                                  onPressed: _cancelSearch,
                                  child: Text(
                                    context.l10n.recordingSearchCancelAction,
                                  ),
                                ),
                              ] else ...<Widget>[
                                const SizedBox(width: SsSpacing.sm),
                                IconButton.outlined(
                                  tooltip: context.l10n.recordingFiltersTitle,
                                  onPressed: () => _openFilters(items),
                                  icon: Badge(
                                    isLabelVisible: _hasActiveFilters,
                                    child: const Icon(Icons.tune_rounded),
                                  ),
                                ),
                                const SizedBox(width: SsSpacing.xs),
                                _ViewToggle(
                                  value: _view,
                                  onChanged: (_RecordingLibraryView value) =>
                                      setState(() => _view = value),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: SsSpacing.md),
                          if (!_searching) ...<Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: SsFilterChips(
                                    items: <String>[
                                      context.l10n.recordingFilterAll,
                                      context.l10n.localLabel,
                                      context.l10n.cloudLabel,
                                      context.l10n.errorStatus,
                                    ],
                                    selectedIndex: _filter.index,
                                    onSelected: (int index) => setState(
                                      () => _filter =
                                          _RecordingLibraryFilter.values[index],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_hasActiveFilters) ...<Widget>[
                              const SizedBox(height: SsSpacing.sm),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _clearFilters,
                                  child: Text(
                                    context.l10n.recordingClearFiltersAction,
                                  ),
                                ),
                              ),
                            ],
                          ] else if (_query.isNotEmpty) ...<Widget>[
                            Text(
                              context.l10n.recordingSearchResults(
                                visible.length,
                                _query.trim(),
                              ),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                          const SizedBox(height: SsSpacing.md),
                          if (visible.isEmpty)
                            _RecordingResultsEmpty(
                              searching: _query.isNotEmpty,
                              filtered: _hasActiveFilters,
                              onClearSearch: _cancelSearch,
                              onClearFilters: _clearFilters,
                            )
                          else if (_searching && _query.isNotEmpty) ...<Widget>[
                            for (final RecordingLibraryItem item
                                in visible) ...<Widget>[
                              _SwipeActionsCard(
                                key: ValueKey<String>(item.id),
                                item: item,
                                showThumbnail:
                                    _view == _RecordingLibraryView.content,
                                busy: _busyItemId == item.id,
                                onOpen: () => context.push(_routeFor(item)),
                                onPlay: () => _play(item),
                                onShare: () => _share(item),
                                onDelete: () => _delete(item),
                              ),
                              const SizedBox(height: SsSpacing.sm),
                            ],
                            const SizedBox(height: SsSpacing.md),
                            Text(
                              context.l10n.recordingSearchHelpTitle,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: SsSpacing.sm),
                            Text(context.l10n.recordingSearchHelpBody),
                          ] else
                            for (
                              int groupIndex = 0;
                              groupIndex < groups.length;
                              groupIndex++
                            ) ...<Widget>[
                              _RecordingDateHeader(
                                label: _dateGroupLabel(
                                  context,
                                  groups[groupIndex].date,
                                ),
                              ),
                              const SizedBox(height: SsSpacing.sm),
                              for (final RecordingLibraryItem item
                                  in groups[groupIndex].items) ...<Widget>[
                                _SwipeActionsCard(
                                  key: ValueKey<String>(item.id),
                                  item: item,
                                  showThumbnail:
                                      _view == _RecordingLibraryView.content,
                                  busy: _busyItemId == item.id,
                                  onOpen: () => context.push(_routeFor(item)),
                                  onPlay: () => _play(item),
                                  onShare: () => _share(item),
                                  onDelete: () => _delete(item),
                                ),
                                const SizedBox(height: SsSpacing.sm),
                              ],
                              const SizedBox(height: SsSpacing.xs),
                              if (groupIndex == 0 &&
                                  groups.length > 1 &&
                                  entitlement?.plan == Plan.free &&
                                  MediaQuery.textScalerOf(context).scale(1) <
                                      1.8) ...<Widget>[
                                ref
                                        .watch(adsServiceProvider)
                                        .bannerFor(AdPlacement.library) ??
                                    const SizedBox.shrink(),
                              ],
                            ],
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_RecordingDateGroup> _groupItems(List<RecordingLibraryItem> items) {
    final Map<DateTime?, List<RecordingLibraryItem>> byDate =
        <DateTime?, List<RecordingLibraryItem>>{};
    for (final RecordingLibraryItem item in items) {
      final DateTime? local = item.startedAt?.toLocal();
      final DateTime? date = local == null
          ? null
          : DateTime(local.year, local.month, local.day);
      byDate.putIfAbsent(date, () => <RecordingLibraryItem>[]).add(item);
    }

    final List<DateTime?> dates = byDate.keys.toList()
      ..sort((DateTime? a, DateTime? b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return b.compareTo(a);
      });
    return dates
        .map((DateTime? date) {
          final List<RecordingLibraryItem> groupItems = byDate[date]!
            ..sort(_compareWithinDate);
          return _RecordingDateGroup(date: date, items: groupItems);
        })
        .toList(growable: false);
  }

  int _compareWithinDate(RecordingLibraryItem a, RecordingLibraryItem b) {
    final int dateOrder = _dateForSort(b).compareTo(_dateForSort(a));
    switch (_sort) {
      case _RecordingLibrarySort.date:
        return dateOrder;
      case _RecordingLibrarySort.expiring:
        final DateTime farFuture = DateTime.utc(9999);
        final int expiryOrder = (a.expiresAt ?? farFuture).compareTo(
          b.expiresAt ?? farFuture,
        );
        return expiryOrder == 0 ? dateOrder : expiryOrder;
      case _RecordingLibrarySort.size:
        final int sizeOrder = b.sizeBytes.compareTo(a.sizeBytes);
        return sizeOrder == 0 ? dateOrder : sizeOrder;
      case _RecordingLibrarySort.name:
        final int nameOrder = a.creatorDisplayName.toLowerCase().compareTo(
          b.creatorDisplayName.toLowerCase(),
        );
        return nameOrder == 0 ? dateOrder : nameOrder;
    }
  }

  DateTime _dateForSort(RecordingLibraryItem item) =>
      item.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  String _dateGroupLabel(BuildContext context, DateTime? date) {
    if (date == null) return context.l10n.notStartedLabel;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    if (date == today) return context.l10n.recordingDateToday;
    if (date == today.subtract(const Duration(days: 1))) {
      return context.l10n.recordingDateYesterday;
    }
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }
}

class _RecordingDateGroup {
  const _RecordingDateGroup({required this.date, required this.items});

  final DateTime? date;
  final List<RecordingLibraryItem> items;
}

class _RecordingFilterSelection {
  const _RecordingFilterSelection({
    required this.filter,
    required this.statuses,
    required this.sort,
  });

  final _RecordingLibraryFilter filter;
  final Set<_RecordingStatusGroup> statuses;
  final _RecordingLibrarySort sort;
}

class _EmptyRecordingLibrary extends StatelessWidget {
  const _EmptyRecordingLibrary({
    required this.onAddCreator,
    required this.onRecordNow,
  });

  final VoidCallback onAddCreator;
  final VoidCallback onRecordNow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsSpacing.xxl * 2),
      child: Column(
        children: <Widget>[
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(SsRadii.xl),
            ),
            child: Icon(
              Icons.video_library_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: SsSpacing.lg),
          Text(
            context.l10n.emptyRecordingsTitle,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SsSpacing.sm),
          Text(
            context.l10n.emptyRecordingsBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SsSpacing.xl),
          SsPrimaryButton(
            label: context.l10n.recordingEmptyAddCreatorAction,
            icon: Icons.add_rounded,
            onPressed: onAddCreator,
          ),
          const SizedBox(height: SsSpacing.sm),
          SsSecondaryButton(
            label: context.l10n.recordingEmptyRecordNowAction,
            onPressed: onRecordNow,
          ),
        ],
      ),
    );
  }
}

class _RecordingResultsEmpty extends StatelessWidget {
  const _RecordingResultsEmpty({
    required this.searching,
    required this.filtered,
    required this.onClearSearch,
    required this.onClearFilters,
  });

  final bool searching;
  final bool filtered;
  final VoidCallback onClearSearch;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsSpacing.xxl * 2),
      child: Column(
        children: <Widget>[
          Icon(
            searching ? Icons.search_off_rounded : Icons.filter_alt_off_rounded,
            size: 52,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: SsSpacing.lg),
          Text(
            searching
                ? context.l10n.recordingSearchEmptyTitle
                : context.l10n.recordingFilteredEmptyTitle,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SsSpacing.sm),
          Text(
            searching
                ? context.l10n.recordingSearchEmptyBody
                : context.l10n.recordingFilteredEmptyBody,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SsSpacing.lg),
          SsSecondaryButton(
            label: searching
                ? context.l10n.recordingSearchClearAction
                : context.l10n.recordingClearFiltersAction,
            onPressed: searching ? onClearSearch : onClearFilters,
          ),
          if (!searching && !filtered) const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _RecordingDateHeader extends StatelessWidget {
  const _RecordingDateHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: SsSpacing.md),
        Expanded(child: Divider(color: color.withValues(alpha: .32))),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.value, required this.onChanged});

  final _RecordingLibraryView value;
  final ValueChanged<_RecordingLibraryView> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_RecordingLibraryView>(
      showSelectedIcon: false,
      segments: <ButtonSegment<_RecordingLibraryView>>[
        ButtonSegment<_RecordingLibraryView>(
          value: _RecordingLibraryView.content,
          icon: const Icon(Icons.view_agenda_outlined),
          tooltip: context.l10n.recordingContentViewLabel,
        ),
        ButtonSegment<_RecordingLibraryView>(
          value: _RecordingLibraryView.list,
          icon: const Icon(Icons.view_list_rounded),
          tooltip: context.l10n.recordingListViewLabel,
        ),
      ],
      selected: <_RecordingLibraryView>{value},
      onSelectionChanged: (Set<_RecordingLibraryView> selection) {
        onChanged(selection.first);
      },
    );
  }
}

class _SwipeActionsCard extends StatefulWidget {
  const _SwipeActionsCard({
    required this.item,
    required this.showThumbnail,
    required this.busy,
    required this.onOpen,
    required this.onPlay,
    required this.onShare,
    required this.onDelete,
    super.key,
  });

  final RecordingLibraryItem item;
  final bool showThumbnail;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  State<_SwipeActionsCard> createState() => _SwipeActionsCardState();
}

class _SwipeActionsCardState extends State<_SwipeActionsCard> {
  static const double _actionWidth = 68;
  static const double _openOffset = _actionWidth * 3;
  double _offset = 0;

  void _close() => setState(() => _offset = 0);

  void _dragUpdate(DragUpdateDetails details) {
    setState(() {
      _offset = (_offset + details.delta.dx).clamp(-_openOffset, 0);
    });
  }

  void _dragEnd(DragEndDetails details) {
    final double projected =
        _offset + details.velocity.pixelsPerSecond.dx * .08;
    setState(() => _offset = projected < -56 ? -_openOffset : 0);
  }

  void _run(VoidCallback action) {
    _close();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final RecordingLibraryItem item = widget.item;

    return ClipRRect(
      borderRadius: SsRadii.card,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ColoredBox(
              color: colors.surfaceContainerHighest,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _QuickAction(
                      width: _actionWidth,
                      icon: Icons.play_arrow_rounded,
                      label: context.l10n.playRecordingAction,
                      color: colors.primary,
                      enabled: item.canPlay && !widget.busy,
                      onPressed: () => _run(widget.onPlay),
                    ),
                    _QuickAction(
                      width: _actionWidth,
                      icon: Icons.ios_share_rounded,
                      label: context.l10n.shareRecordingAction,
                      color: context.semanticColors.cloud,
                      enabled: item.canShare && !widget.busy,
                      onPressed: () => _run(widget.onShare),
                    ),
                    _QuickAction(
                      width: _actionWidth,
                      icon: Icons.delete_outline_rounded,
                      label: context.l10n.deleteRecordingAction,
                      color: colors.error,
                      enabled: item.canDelete && !widget.busy,
                      onPressed: () => _run(widget.onDelete),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _dragUpdate,
              onHorizontalDragEnd: _dragEnd,
              child: Material(
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: SsRadii.card,
                  side: BorderSide(color: colors.outline),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _offset == 0 ? widget.onOpen : _close,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SsSpacing.md,
                      vertical: SsSpacing.sm,
                    ),
                    child: widget.showThumbnail
                        ? _ContentRow(item: item, busy: widget.busy)
                        : _CompactRow(item: item, busy: widget.busy),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentRow extends StatelessWidget {
  const _ContentRow({required this.item, required this.busy});

  final RecordingLibraryItem item;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 96,
          height: 64,
          child: RecordingThumbnail(
            recordingId: item.id,
            storage: item.storage,
            filePath: item.filePath,
            enabled: item.canPlay,
          ),
        ),
        const SizedBox(width: SsSpacing.md),
        Expanded(
          child: _ItemDetails(item: item, busy: busy),
        ),
      ],
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.item, required this.busy});

  final RecordingLibraryItem item;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          Icons.video_file_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: SsSpacing.sm),
        Expanded(
          child: _ItemDetails(item: item, busy: busy, compact: true),
        ),
      ],
    );
  }
}

class _ItemDetails extends StatelessWidget {
  const _ItemDetails({
    required this.item,
    required this.busy,
    this.compact = false,
  });

  final RecordingLibraryItem item;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool local = item.storage == RecordingLibraryStorage.local;
    final bool missingCloudArtifact =
        item.issue == RecordingLibraryIssue.missingCloudArtifact;
    final Color onVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                item.creatorDisplayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (busy)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: SsSpacing.xs),
        Text(
          <String>[
            if (item.startedAt != null)
              recordingTimestamp(context, item.startedAt),
            formatDuration(item.durationSeconds),
            formatBytes(item.sizeBytes),
          ].join(' · '),
          maxLines: compact ? 2 : 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: compact ? onVariant : null),
        ),
        const SizedBox(height: SsSpacing.xs),
        Wrap(
          spacing: SsSpacing.xs,
          runSpacing: SsSpacing.xs,
          children: <Widget>[
            SsStatusChip(
              label: missingCloudArtifact
                  ? context.l10n.recordingArtifactMissingStatus
                  : recordingStatusLabel(context.l10n, item.status),
              tone: missingCloudArtifact
                  ? SsStatusTone.error
                  : recordingStatusTone(item.status),
              icon:
                  !missingCloudArtifact &&
                      item.status == RecordingStatus.completed
                  ? Icons.check_rounded
                  : null,
            ),
            SsStatusChip(
              label: local ? context.l10n.localLabel : context.l10n.cloudLabel,
              tone: local ? SsStatusTone.local : SsStatusTone.cloud,
              icon: local ? Icons.smartphone_rounded : Icons.cloud_rounded,
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.width,
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final double width;
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: enabled ? color : color.withValues(alpha: .28),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, color: Colors.white),
                const SizedBox(height: SsSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingsSkeleton extends StatelessWidget {
  const _RecordingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(height: 56, radius: SsRadii.md),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 40, radius: SsRadii.md),
        SizedBox(height: SsSpacing.lg),
        SsSkeleton(height: 106, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 106, radius: SsRadii.lg),
      ],
    );
  }
}
