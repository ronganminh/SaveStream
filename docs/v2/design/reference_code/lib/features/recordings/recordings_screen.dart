import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums.dart';
import '../../core/mock_data.dart';
import '../../core/models.dart';
import '../../theme/ss_theme.dart';
import '../../widgets/widgets.dart';

/// L01 — Bản ghi · Local + Cloud, nhóm theo ngày, banner giữa 2 nhóm (Free).
class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  int _filter = 0;

  bool _has(Recording r, Engine e) =>
      r.copies == CopyLocation.both || (e == Engine.local ? r.copies == CopyLocation.localOnly : r.copies == CopyLocation.cloudOnly);

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final all = mockRecordings;
    final localN = all.where((r) => _has(r, Engine.local)).length;
    final cloudN = all.where((r) => _has(r, Engine.cloud)).length;
    final list = switch (_filter) {
      1 => all.where((r) => _has(r, Engine.local)).toList(),
      2 => all.where((r) => _has(r, Engine.cloud)).toList(),
      _ => all,
    };
    final groups = <String, List<Recording>>{};
    for (final r in list) {
      groups.putIfAbsent(_dayLabel(r.startedAt), () => []).add(r);
    }
    final keys = groups.keys.toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SsAppBar(title: 'Bản ghi', subtitle: '$localN Local · $cloudN Cloud', showNotifications: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(SsSpace.screenH, 0, SsSpace.screenH, SsSpace.md),
              child: TextField(
                readOnly: true,
                onTap: () => context.push('/recordings/search'),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Tìm recording'),
              ),
            ),
            SsFilterChips(
              items: [
                SsFilterChipItem('Tất cả', count: all.length),
                SsFilterChipItem('Local', icon: Icons.smartphone_rounded, count: localN),
                SsFilterChipItem('Cloud', icon: Icons.cloud_rounded, count: cloudN),
              ],
              selected: _filter,
              onSelected: (i) => setState(() => _filter = i),
            ),
          ]),
        ),
        if (list.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: SsEmptyState(
                  icon: Icons.video_library_rounded, title: 'Chưa có recording nào', body: 'Bản ghi Local và Cloud sẽ hiện ở đây.'),
            ),
          ),
        for (var g = 0; g < keys.length; g++) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(SsSpace.screenH, SsSpace.xl, SsSpace.screenH, SsSpace.xs),
              child: Text(keys[g], style: context.tt.labelMedium!.copyWith(color: context.cs.onSurfaceVariant)),
            ),
          ),
          SliverList.builder(
            itemCount: groups[keys[g]]!.length,
            itemBuilder: (c, i) {
              final r = groups[keys[g]]![i];
              return SsRecordingTile(
                recording: r,
                showDivider: i < groups[keys[g]]!.length - 1,
                onTap: () => context.push('/recordings/${r.id}'),
              );
            },
          ),
          if (g == 0 && keys.length > 1)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: SsSpace.screenH, vertical: SsSpace.md),
                child: SsBannerAd(placement: SsAdPlacement.libraryBetweenGroups),
              ),
            ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: SsSpace.xxl)),
      ]),
    );
  }
}
