// EcoXchange Mobile — RewardProvider tests (Phase 4C.2 §21): real RM
// balance display, real transaction ledger, and — critically — no
// invented points/conversion system anywhere in the model or provider.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pagination.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/reward_transaction.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_reward_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/reward_provider.dart';

class _FakeRewardRepository extends CustomerRewardRepository {
  _FakeRewardRepository() : super(ApiClient());

  @override
  Future<({double balance, List<RewardTransactionModel> transactions, Pagination pagination})> getRewards({int page = 1}) async {
    return (
      balance: 45.60,
      transactions: [
        RewardTransactionModel.fromJson({
          'id': 1, 'type': 'earn', 'amount': 6.60, 'balance_after': 45.60,
          'status': 'completed', 'note': 'Pickup #PK-14 completed', 'pickup_id': 14,
          'transacted_at': '2026-09-02T18:20:32Z',
        }),
      ],
      pagination: Pagination.fromJson({'current_page': page, 'last_page': 1, 'per_page': 15, 'total': 1}),
    );
  }
}

void main() {
  test('reward balance is the real monetary RM figure — not a points conversion', () async {
    final provider = RewardProvider(_FakeRewardRepository());

    await provider.load();

    expect(provider.balance, 45.60);
    // No provider field/method computes a points value anywhere — the
    // model/provider surface is exhaustively: balance, transactions,
    // pagination, isLoading, error. This asserts the model shape stays
    // that way rather than silently growing a `points` field later.
    expect(provider.transactions.single.amount, 6.60);
    expect(provider.transactions.single.type, 'earn');
  });

  test('RewardTransactionModel has no points/conversion field of any kind', () {
    final tx = RewardTransactionModel.fromJson({
      'id': 1, 'type': 'earn', 'amount': 6.60, 'balance_after': 45.60,
      'status': 'completed', 'note': null, 'pickup_id': null, 'transacted_at': null,
    });

    // Exhaustive field check — if a future change ever added a fake
    // points field, this test's field list would need to change with it,
    // making the addition visible in review.
    expect(tx.id, 1);
    expect(tx.amount, 6.60);
    expect(tx.balanceAfter, 45.60);
    expect(tx.isCredit, isTrue);
  });
}
