import 'package:flutter/material.dart';

import '../theme/ss_theme.dart';

enum SsSkeletonShape { line, block, circle, recordingRow, creatorTile, quotaCard }

class SsSkeleton extends StatefulWidget {
  const SsSkeleton({super.key, this.shape = SsSkeletonShape.line, this.width, this.height});
  final SsSkeletonShape shape;
  final double? width, height;

  @override
  State<SsSkeleton> createState() => _SsSkeletonState();
}

class _SsSkeletonState extends State<SsSkeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _box(double? w, double h, {double r = SsRadius.sm, bool circle = false}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: context.cs.surfaceContainerHighest,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(r),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final child = switch (w.shape) {
      SsSkeletonShape.line => _box(w.width ?? double.infinity, w.height ?? 14, r: 4),
      SsSkeletonShape.block => _box(w.width ?? double.infinity, w.height ?? 96, r: SsRadius.card),
      SsSkeletonShape.circle => _box(w.width ?? 44, w.width ?? 44, circle: true),
      SsSkeletonShape.quotaCard => _box(double.infinity, w.height ?? 148, r: SsRadius.card),
      SsSkeletonShape.recordingRow || SsSkeletonShape.creatorTile => Padding(
          padding: const EdgeInsets.symmetric(vertical: SsSpace.md),
          child: Row(children: [
            w.shape == SsSkeletonShape.creatorTile ? _box(44, 44, circle: true) : _box(64, 40),
            const SizedBox(width: SsSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _box(160, 14, r: 4),
                const SizedBox(height: SsSpace.sm),
                _box(100, 12, r: 4),
              ]),
            ),
          ]),
        ),
    };
    return ExcludeSemantics(
      child: FadeTransition(opacity: Tween(begin: .55, end: 1.0).animate(_c), child: child),
    );
  }
}
