import '../../../../core/api/api_client.dart';
import '../models/pagination.dart';
import '../models/reward_transaction.dart';

/// EcoXchange Mobile — GET /api/v1/customer/rewards. Returns the real RM
/// `reward_balance` and the real transaction ledger — see RewardController's
/// docblock confirming there is no points system anywhere in the backend.
class CustomerRewardRepository {
  CustomerRewardRepository(this._api);

  final ApiClient _api;

  Future<({double balance, List<RewardTransactionModel> transactions, Pagination pagination})> getRewards({int page = 1}) async {
    final data = await _api.get('/customer/rewards', query: {'page': page});

    final transactions =
        (data['transactions'] as List<dynamic>).map((e) => RewardTransactionModel.fromJson(e as Map<String, dynamic>)).toList();
    final pagination = Pagination.fromJson(data['pagination'] as Map<String, dynamic>);

    return (balance: (data['reward_balance'] as num).toDouble(), transactions: transactions, pagination: pagination);
  }
}
