import '../../../../core/mock/mock_repository_base.dart';
import '../../domain/models/credit_models.dart';
import '../../domain/repositories/credits_repository.dart';

final class MockCreditsRepository extends MockRepositoryBase
    implements CreditsRepository {
  const MockCreditsRepository(super.behavior);

  @override
  Future<CreditsOverview> getOverview() {
    return respond<CreditsOverview>(
      success: () => CreditsOverview(
        balance: const CreditBalance(
          posted: 7.4,
          reserved: 2.6,
          available: 4.8,
        ),
        usage: const CreditUsageSummary(
          recordingHours: 12.6,
          recordingCount: 4,
          recordingCost: 2.4,
        ),
        transactions: <CreditTransaction>[
          CreditTransaction(
            id: 'txn_004',
            amountCredits: -1.8,
            occurredAt: DateTime.utc(2026, 9, 30, 13, 35),
            recordingId: 'rec_002',
          ),
          CreditTransaction(
            id: 'txn_003',
            amountCredits: -0.6,
            occurredAt: DateTime.utc(2026, 9, 29, 8, 42),
            recordingId: 'rec_003',
          ),
          CreditTransaction(
            id: 'txn_002',
            amountCredits: 10,
            occurredAt: DateTime.utc(2026, 9, 28, 15, 5),
          ),
          CreditTransaction(
            id: 'txn_001',
            amountCredits: -0.2,
            occurredAt: DateTime.utc(2026, 9, 27, 10, 20),
            recordingId: 'rec_010',
          ),
        ],
      ),
      empty: () => const CreditsOverview(
        balance: CreditBalance(posted: 0, reserved: 0, available: 0),
        usage: CreditUsageSummary(
          recordingHours: 0,
          recordingCount: 0,
          recordingCost: 0,
        ),
        transactions: <CreditTransaction>[],
      ),
    );
  }
}
