import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/mock/mock_providers.dart';
import '../../recordings/domain/models/recording_summary.dart';
import '../../recordings/presentation/controllers/recording_providers.dart';
import '../data/mock_credit_ledger_repository.dart';
import '../data/mock_credits_repository.dart';
import '../domain/credit_balance.dart';
import '../domain/credit_ledger.dart';

// Production overrides these with the Api* repositories at bootstrap.
final Provider<CreditsRepository> creditsRepositoryProvider =
    Provider<CreditsRepository>(
      (ref) => MockCreditsRepository(ref.watch(mockBehaviorProvider)),
    );

final Provider<CreditLedgerRepository> creditLedgerRepositoryProvider =
    Provider<CreditLedgerRepository>(
      (ref) => MockCreditLedgerRepository(ref.watch(mockBehaviorProvider)),
    );

final Provider<RewardsRepository> rewardsRepositoryProvider =
    Provider<RewardsRepository>(
      (ref) => MockCreditLedgerRepository(ref.watch(mockBehaviorProvider)),
    );

/// `GET /v1/credits/balance`.
final FutureProvider<CreditBalance> creditBalanceProvider =
    FutureProvider<CreditBalance>(
      (ref) => ref.watch(creditsRepositoryProvider).getBalance(),
    );

/// How far back Usage history reads the ledger (the chart's window).
const int usageHistoryDays = 14;

/// Ledger entries of the last [usageHistoryDays] days, newest first (at most
/// a few pages, so a heavy account doesn't page forever).
final FutureProvider<List<CreditTransaction>> creditTransactionsProvider =
    FutureProvider<List<CreditTransaction>>((ref) async {
      final CreditLedgerRepository repository = ref.watch(
        creditLedgerRepositoryProvider,
      );
      final DateTime cutoff = ref
          .watch(creditsClockProvider)()
          .subtract(const Duration(days: usageHistoryDays));
      final List<CreditTransaction> items = <CreditTransaction>[];
      String? cursor;
      for (int page = 0; page < 5; page++) {
        final CreditTransactionPage result = await repository.listTransactions(
          cursor: cursor,
        );
        items.addAll(result.items);
        cursor = result.nextCursor;
        if (cursor == null ||
            result.items.isEmpty ||
            result.items.last.createdAt.isBefore(cutoff)) {
          break;
        }
      }
      return List<CreditTransaction>.unmodifiable(items);
    });

/// `GET /v1/billing/payment-orders`, Google Play purchases only.
final FutureProvider<List<PaymentOrder>> playPurchasesProvider =
    FutureProvider<List<PaymentOrder>>((ref) async {
      final List<PaymentOrder> orders = await ref
          .watch(creditLedgerRepositoryProvider)
          .listPaymentOrders();
      return orders
          .where((PaymentOrder order) => order.provider == 'google_play')
          .toList(growable: false);
    });

/// Recordings by id, to name the channel on a ledger charge. Best effort:
/// Usage history still lists the entries when this fails.
final FutureProvider<Map<String, RecordingSummary>> ledgerRecordingsProvider =
    FutureProvider<Map<String, RecordingSummary>>((ref) async {
      try {
        final RecordingPage page = await ref
            .watch(recordingRepositoryProvider)
            .listRecordingPage(limit: 100);
        return <String, RecordingSummary>{
          for (final RecordingSummary item in page.items) item.id: item,
        };
      } on Object {
        return const <String, RecordingSummary>{};
      }
    });

final Provider<DateTime Function()> creditsClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

/// The "Personalized ads" choice on Ad privacy choices (off by default).
/// Off sends non-personalized ad requests; UMP consent still applies.
abstract interface class AdPreferencesStore {
  Future<bool> loadPersonalized();

  Future<void> savePersonalized(bool value);
}

final class MemoryAdPreferencesStore implements AdPreferencesStore {
  bool _value = false;

  @override
  Future<bool> loadPersonalized() async => _value;

  @override
  Future<void> savePersonalized(bool value) async => _value = value;
}

final class SharedPreferencesAdPreferencesStore implements AdPreferencesStore {
  static const String _key = 'savestream.ads.personalized';

  @override
  Future<bool> loadPersonalized() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> savePersonalized(bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, value);
    } on Object {
      // Kept for this run only.
    }
  }
}

final Provider<AdPreferencesStore> adPreferencesStoreProvider =
    Provider<AdPreferencesStore>((ref) => MemoryAdPreferencesStore());

final AsyncNotifierProvider<PersonalizedAdsController, bool>
personalizedAdsProvider =
    AsyncNotifierProvider<PersonalizedAdsController, bool>(
      PersonalizedAdsController.new,
    );

class PersonalizedAdsController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.watch(adPreferencesStoreProvider).loadPersonalized();

  Future<void> set(bool value) async {
    state = AsyncData<bool>(value);
    await ref.read(adPreferencesStoreProvider).savePersonalized(value);
  }
}
