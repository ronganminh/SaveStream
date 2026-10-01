import '../../../../core/mock/mock_repository_base.dart';
import '../../domain/models/credit_models.dart';
import '../../domain/repositories/credits_repository.dart';

final class MockCreditsRepository extends MockRepositoryBase
    implements CreditsRepository {
  const MockCreditsRepository(super.behavior);

  static const CreditBalance _balance = CreditBalance(
    posted: 12,
    reserved: 3,
    available: 9,
  );

  @override
  Future<CreditBalance> getBalance() {
    return respond<CreditBalance>(
      success: () => _balance,
      empty: () => const CreditBalance(posted: 0, reserved: 0, available: 0),
    );
  }

  @override
  Future<CreditsOverview> getOverview() {
    return respond<CreditsOverview>(
      success: () => CreditsOverview(
        balance: _balance,
        pricing: const PricingSnapshot(
          version: 'mock-v1',
          creditUnit: 'credit',
          rules: <Map<String, Object?>>[
            <String, Object?>{'label': 'Mock recording pricing'},
          ],
        ),
        reservations: <CreditReservation>[
          CreditReservation(
            id: 'reservation_001',
            recordingId: 'rec_001',
            reserved: 3,
            settled: 0,
            released: 0,
            status: CreditReservationStatus.active,
            createdAt: DateTime.utc(2026, 9, 30, 13, 30),
          ),
        ],
        transactions: <CreditTransaction>[
          CreditTransaction(
            id: 'txn_004',
            type: CreditTransactionType.charge,
            amount: -2,
            balanceAfter: 12,
            referenceType: 'recording',
            referenceId: 'rec_002',
            occurredAt: DateTime.utc(2026, 9, 30, 13, 35),
          ),
          CreditTransaction(
            id: 'txn_003',
            type: CreditTransactionType.release,
            amount: 0,
            balanceAfter: 14,
            referenceType: 'recording',
            referenceId: 'rec_003',
            occurredAt: DateTime.utc(2026, 9, 29, 8, 42),
          ),
          CreditTransaction(
            id: 'txn_002',
            type: CreditTransactionType.grant,
            amount: 10,
            balanceAfter: 14,
            referenceType: 'payment_order',
            referenceId: 'order_paid',
            occurredAt: DateTime.utc(2026, 9, 28, 15, 5),
          ),
        ],
      ),
      empty: () => const CreditsOverview(
        balance: CreditBalance(posted: 0, reserved: 0, available: 0),
        transactions: <CreditTransaction>[],
        reservations: <CreditReservation>[],
      ),
    );
  }
}
