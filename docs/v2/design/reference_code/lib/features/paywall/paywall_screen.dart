import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums.dart';
import '../../theme/ss_theme.dart';
import '../../widgets/widgets.dart';

/// M03 — Pro paywall, Monthly/Yearly. Giá PHẢI đọc từ storefront (in_app_purchase ProductDetails.price).
/// Chuỗi dưới đây chỉ là fallback hiển thị trong demo.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.context});
  final PaywallContext context;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  BillingPeriod _period = BillingPeriod.yearly;
  PurchaseState _state = PurchaseState.idle;

  (String, String) get _headline => switch (widget.context) {
        PaywallContext.autoRecord => ('Auto-record trên cloud', 'Pro tự record khi creator LIVE, kể cả khi điện thoại tắt.'),
        PaywallContext.watchlistFull => ('Theo dõi tới 20 creator', 'Watch List Free tối đa 3 creator.'),
        PaywallContext.iosBackground => ('Record không cần mở app', 'Cloud record trên server, điện thoại không cần online.'),
        PaywallContext.quotaExhausted => ('Hết phút Free hôm nay', 'Pro có 30 giờ cloud mỗi kỳ.'),
        PaywallContext.removeAds => ('Không quảng cáo', 'Pro gỡ toàn bộ quảng cáo.'),
      };

  Future<void> _buy() async {
    setState(() => _state = PurchaseState.storeSheet);
    // TODO: InAppPurchase.instance.buyNonConsumable(...) → verify với backend → entitlement.
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _state = PurchaseState.verifying);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _state = PurchaseState.success);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final h = SsSpace.sheetH(context);
    final (title, sub) = _headline;
    final busy = _state == PurchaseState.storeSheet || _state == PurchaseState.verifying;

    if (_state == PurchaseState.success) {
      return SsFullScreenState(
        icon: Icons.workspace_premium_rounded,
        title: 'Bạn đã là Pro',
        body: 'Auto-record cloud, 30 giờ mỗi kỳ, không quảng cáo.',
        primary: SsButton(label: 'Xong', onPressed: () => context.pop()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const SsAppBar(title: '', variant: SsAppBarVariant.modal),
          Expanded(
            child: ListView(padding: EdgeInsets.symmetric(horizontal: h), children: [
              const SsPlanBadge(plan: Plan.pro),
              const SizedBox(height: SsSpace.md),
              Text(title, style: context.tt.headlineMedium),
              const SizedBox(height: SsSpace.sm),
              Text(sub, style: context.tt.bodyLarge!.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: SsSpace.xxl),
              for (final f in const [
                (Icons.cloud_rounded, 'Auto-record trên cloud · 3 cùng lúc'),
                (Icons.schedule_rounded, '30 giờ cloud mỗi kỳ'),
                (Icons.visibility_rounded, 'Theo dõi tới 20 creator'),
                (Icons.block_rounded, 'Không quảng cáo'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Icon(f.$1, color: cs.primary, size: 22),
                    const SizedBox(width: SsSpace.md),
                    Expanded(child: Text(f.$2, style: context.tt.bodyLarge)),
                  ]),
                ),
              const SizedBox(height: SsSpace.xxl),
              SsPlanOptionCard(
                title: 'Hằng năm',
                subtitle: '\$3.33/tháng, thanh toán theo năm',
                price: '\$39.99',
                badge: 'Tiết kiệm 33%',
                selected: _period == BillingPeriod.yearly,
                onTap: () => setState(() => _period = BillingPeriod.yearly),
              ),
              const SizedBox(height: SsSpace.sm),
              SsPlanOptionCard(
                title: 'Hằng tháng',
                price: '\$4.99',
                selected: _period == BillingPeriod.monthly,
                onTap: () => setState(() => _period = BillingPeriod.monthly),
              ),
              if (_state == PurchaseState.failed || _state == PurchaseState.pending) ...[
                const SizedBox(height: SsSpace.lg),
                SsInlineAlert(
                  tone: _state == PurchaseState.failed ? SsAlertTone.error : SsAlertTone.warning,
                  title: _state == PurchaseState.failed ? 'Thanh toán không thành công' : 'Đang chờ xác nhận thanh toán',
                ),
              ],
              const SizedBox(height: SsSpace.xxl),
            ]),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(h, SsSpace.sm, h, SsSpace.lg),
            child: Column(children: [
              SsButton(
                label: _state == PurchaseState.verifying ? 'Đang xác minh…' : 'Tiếp tục',
                loading: busy,
                onPressed: _buy,
              ),
              const SizedBox(height: SsSpace.xs),
              Wrap(alignment: WrapAlignment.center, children: [
                TextButton(onPressed: () {}, child: const Text('Khôi phục giao dịch')),
                TextButton(onPressed: () => context.push('/settings/legal'), child: const Text('Điều khoản')),
              ]),
              Text('Tự gia hạn. Huỷ bất kỳ lúc nào trong cài đặt store.',
                  textAlign: TextAlign.center, style: context.tt.labelSmall!.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
    );
  }
}
