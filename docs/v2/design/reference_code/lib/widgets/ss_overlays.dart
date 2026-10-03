import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../core/models.dart';
import '../theme/ss_theme.dart';
import 'ss_button.dart';

Future<T?> showSsBottomSheet<T>(BuildContext context,
    {required String title, String? body, Widget? content, List<Widget> actions = const [], bool isDismissible = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    useSafeArea: true,
    builder: (c) {
      final h = SsSpace.sheetH(c);
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(h, 0, h, h),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: c.tt.titleLarge),
          if (body != null) ...[
            const SizedBox(height: SsSpace.sm),
            Text(body, style: c.tt.bodyLarge!.copyWith(color: c.cs.onSurfaceVariant)),
          ],
          if (content != null) ...[const SizedBox(height: SsSpace.lg), content],
          if (actions.isNotEmpty) const SizedBox(height: SsSpace.xxl),
          for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(height: SsSpace.sm), actions[i]],
        ]),
      );
    },
  );
}

Future<T?> showSsDialog<T>(BuildContext context,
    {required String title, String? body, Widget? content, IconData? icon, bool destructive = false, required List<Widget> actions}) {
  return showDialog<T>(
    context: context,
    barrierColor: context.ss.scrim,
    builder: (c) => Dialog(
      backgroundColor: c.cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SsRadius.dialog)),
      insetPadding: const EdgeInsets.symmetric(horizontal: SsSpace.xxl, vertical: SsSpace.xxl),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SsSpace.xxl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 32, color: destructive ? c.ss.recording : c.cs.primary),
            const SizedBox(height: SsSpace.md),
          ],
          Text(title, style: c.tt.titleLarge),
          if (body != null) ...[
            const SizedBox(height: SsSpace.sm),
            Text(body, style: c.tt.bodyMedium!.copyWith(color: c.cs.onSurfaceVariant)),
          ],
          if (content != null) ...[const SizedBox(height: SsSpace.lg), content],
          const SizedBox(height: SsSpace.xxl),
          for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(height: SsSpace.sm), actions[i]],
        ]),
      ),
    ),
  );
}

/// L13 — dialog xoá theo vị trí bản sao. Trả về phần cần xoá, null = huỷ.
Future<CopyLocation?> showSsDeleteDialog(BuildContext context, Recording r) {
  switch (r.copies) {
    case CopyLocation.localOnly:
      return showSsDialog<CopyLocation>(context,
          icon: Icons.delete_rounded,
          destructive: true,
          title: 'Xoá bản ghi trên máy?',
          body: 'File sẽ bị xoá khỏi điện thoại này. Không thể khôi phục.',
          actions: [
            SsButton(label: 'Xoá khỏi máy', variant: SsButtonVariant.destructive, onPressed: () => Navigator.pop(context, CopyLocation.localOnly)),
            SsButton(label: 'Huỷ', variant: SsButtonVariant.tertiary, onPressed: () => Navigator.pop(context)),
          ]);
    case CopyLocation.cloudOnly:
      return showSsDialog<CopyLocation>(context,
          icon: Icons.cloud_off_rounded,
          destructive: true,
          title: 'Xoá bản ghi trên cloud?',
          body: 'Bản ghi sẽ bị xoá khỏi cloud trên mọi thiết bị. Không thể khôi phục.',
          actions: [
            SsButton(label: 'Xoá khỏi cloud', variant: SsButtonVariant.destructive, onPressed: () => Navigator.pop(context, CopyLocation.cloudOnly)),
            SsButton(label: 'Huỷ', variant: SsButtonVariant.tertiary, onPressed: () => Navigator.pop(context)),
          ]);
    case CopyLocation.both:
      var pick = CopyLocation.localOnly;
      return showSsDialog<CopyLocation>(context,
          icon: Icons.delete_rounded,
          destructive: true,
          title: 'Xoá bản ghi',
          body: 'Bản ghi có trên máy này và trên cloud. Chọn bản cần xoá.',
          content: StatefulBuilder(
            builder: (c, set) => Column(children: [
              for (final o in const [
                (CopyLocation.localOnly, 'Chỉ trên máy', 'Vẫn xem được từ cloud'),
                (CopyLocation.cloudOnly, 'Chỉ trên cloud', 'Vẫn giữ file trên máy'),
                (CopyLocation.both, 'Cả hai', 'Xoá hoàn toàn'),
              ])
                _ChoiceRow(title: o.$2, subtitle: o.$3, selected: pick == o.$1, onTap: () => set(() => pick = o.$1)),
            ]),
          ),
          actions: [
            SsButton(label: 'Xoá', variant: SsButtonVariant.destructive, onPressed: () => Navigator.pop(context, pick)),
            SsButton(label: 'Huỷ', variant: SsButtonVariant.tertiary, onPressed: () => Navigator.pop(context)),
          ]);
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SsRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SsSpace.sm),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: SsSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: context.tt.titleSmall),
                Text(subtitle, style: context.tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

enum SsToastDuration { short4s, withAction6s }

void showSsToast(BuildContext context, String message, {IconData? icon, String? actionLabel, VoidCallback? onAction}) {
  final ss = context.ss;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: Duration(seconds: actionLabel != null ? 6 : 4),
      content: Row(children: [
        if (icon != null) ...[Icon(icon, color: ss.onPlayer, size: 20), const SizedBox(width: SsSpace.sm)],
        Expanded(child: Text(message)),
      ]),
      action: actionLabel != null ? SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}) : null,
    ));
}
