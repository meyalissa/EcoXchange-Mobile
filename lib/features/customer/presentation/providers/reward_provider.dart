import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/pagination.dart';
import '../../data/models/reward_transaction.dart';
import '../../data/repositories/customer_reward_repository.dart';

/// EcoXchange Mobile — Rewards screen state: real RM balance + real
/// transaction ledger, server-driven pagination. No points/conversion
/// logic exists anywhere in this class — see CustomerRewardRepository.
class RewardProvider extends ChangeNotifier {
  RewardProvider(this._repository);

  final CustomerRewardRepository _repository;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  ApiException? _error;
  double? _balance;
  List<RewardTransactionModel> _transactions = const [];
  Pagination? _pagination;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  ApiException? get error => _error;
  double? get balance => _balance;
  List<RewardTransactionModel> get transactions => _transactions;
  bool get hasMore => _pagination?.hasNextPage ?? false;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repository.getRewards(page: 1);
      _balance = result.balance;
      _transactions = result.transactions;
      _pagination = result.pagination;
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = (_pagination?.currentPage ?? 1) + 1;
      final result = await _repository.getRewards(page: nextPage);
      _balance = result.balance;
      _transactions = [..._transactions, ...result.transactions];
      _pagination = result.pagination;
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();
}
