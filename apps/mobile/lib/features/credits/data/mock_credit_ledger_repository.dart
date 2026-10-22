import '../../../core/mock/mock_repository_base.dart';
import '../domain/credit_ledger.dart';

/// Ledger and rewards for mock builds (no network).
final class MockCreditLedgerRepository extends MockRepositoryBase
    implements CreditLedgerRepository, RewardsRepository {
  const MockCreditLedgerRepository(super.behavior);

  @override
  Future<CreditTransactionPage> listTransactions({
    String? cursor,
    int limit = 50,
  }) {
    return respond<CreditTransactionPage>(
      success: () => CreditTransactionPage(
        items: <CreditTransaction>[
          CreditTransaction(
            id: 'tx_reward',
            type: CreditTransactionType.grant,
            amount: 5,
            balanceAfter: 15,
            referenceType: 'reward',
            createdAt: DateTime.utc(2026, 10, 21, 9),
          ),
          CreditTransaction(
            id: 'tx_trial',
            type: CreditTransactionType.grant,
            amount: 10,
            balanceAfter: 10,
            referenceType: 'signup_bonus',
            createdAt: DateTime.utc(2026, 10, 2, 9),
          ),
        ],
      ),
      empty: () => const CreditTransactionPage(items: <CreditTransaction>[]),
    );
  }

  @override
  Future<List<PaymentOrder>> listPaymentOrders() {
    return respond<List<PaymentOrder>>(
      success: () => const <PaymentOrder>[],
      empty: () => const <PaymentOrder>[],
    );
  }

  @override
  Future<RewardIntent> createCloudMinutesReward({required String deviceId}) {
    return respond<RewardIntent>(
      success: () => RewardIntent(
        rewardId: 'rwd_mock',
        ssvUserId: 'usr_mock',
        ssvCustomData: 'rwd_mock',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      empty: () => throw StateError('Rewarded ads are not available.'),
    );
  }

  @override
  Future<RewardStatus> getRewardStatus(String rewardId) {
    return respond<RewardStatus>(
      success: () => RewardStatus.valid,
      empty: () => RewardStatus.pending,
    );
  }
}
