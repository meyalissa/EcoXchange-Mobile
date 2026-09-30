import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../data/models/reward_transaction.dart';
import '../providers/reward_provider.dart';

/// EcoXchange Mobile — Rewards (Phase 4C.2 §11, restyled Phase 4C.3 to
/// match `rewards-dashboard.html`). Shows the real RM `reward_balance`
/// and the real transaction ledger only. NO points system, NO "1 RM = 100
/// points" conversion, NO membership level/"Gold" badge, NO Withdraw
/// button (there is no redemption endpoint), NO Lifetime total (that
/// would require summing every page of transactions ever made, which
/// this screen never fully loads) — see CustomerRewardRepository/
/// RewardTransactionModel. The one derived figure here, "This Month", is
/// computed client-side purely from transactions already fetched for
/// display — never a separate invented number.
class RewardScreen extends StatefulWidget {
  const RewardScreen({super.key});

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<RewardProvider>().load());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<RewardProvider>().loadMore();
    }
  }

  /// Sums real credit transactions dated within the current calendar
  /// month, from whatever transactions are already loaded on this screen
  /// — never a server-side aggregate that doesn't exist, and never a
  /// silent full-history fetch just to compute this one figure.
  double _thisMonthTotal(List<RewardTransactionModel> transactions) {
    final now = DateTime.now();
    var total = 0.0;
    for (final tx in transactions) {
      if (!tx.isCredit || tx.transactedAt == null) continue;
      final date = DateTime.tryParse(tx.transactedAt!);
      if (date != null && date.year == now.year && date.month == now.month) {
        total += tx.amount;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RewardProvider>();

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: AsyncStateView<double>(
        isLoading: provider.isLoading,
        error: provider.error,
        data: provider.balance,
        onRetry: provider.load,
        builder: (context, balance) => ListView(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              gradient: AppColors.rewardsHeroGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rewards Hub', style: AppTheme.displayFont(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadii.r20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('WALLET BALANCE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('RM ${balance.toStringAsFixed(2)}', style: AppTheme.displayFont(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 12),
                        Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('THIS MONTH', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            Text('RM ${_thisMonthTotal(provider.transactions).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Transactions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.n800)),
            ),
            const SizedBox(height: 12),
            if (provider.transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.n100, borderRadius: BorderRadius.circular(AppRadii.r12)),
                  child: const Text('No reward transactions yet.', style: TextStyle(color: AppColors.n500, fontSize: 13)),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: AppColors.n0, borderRadius: BorderRadius.circular(AppRadii.r16), boxShadow: AppShadows.sh1),
                child: Column(
                  children: [
                    for (final tx in provider.transactions) ...[
                      if (tx != provider.transactions.first) const Divider(height: 1, color: AppColors.n100),
                      _TransactionTile(transaction: tx),
                    ],
                  ],
                ),
              ),
            if (provider.hasMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final RewardTransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final sign = transaction.isCredit ? '+' : '-';
    final amountColor = transaction.isCredit ? AppColors.green600 : AppColors.red;
    final iconBg = transaction.isCredit ? AppColors.green50 : AppColors.redLight;
    final icon = switch (transaction.type) {
      'earn' => Icons.local_shipping_outlined,
      'withdraw' => Icons.account_balance_wallet_outlined,
      'refund' => Icons.replay,
      'bonus' => Icons.card_giftcard_outlined,
      'penalty' => Icons.remove_circle_outline,
      _ => Icons.receipt_long_outlined,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(AppRadii.r12)),
            child: Icon(icon, size: 18, color: transaction.isCredit ? AppColors.green600 : AppColors.red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_typeLabel(transaction.type), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.n800)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (transaction.pickupId != null) 'Pickup #PK-${transaction.pickupId}',
                    if (transaction.note != null && transaction.note!.isNotEmpty) transaction.note!,
                    if (transaction.transactedAt != null) transaction.transactedAt!.split('T').first,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11, color: AppColors.n500),
                ),
              ],
            ),
          ),
          Text('$sign RM ${transaction.amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: amountColor)),
        ],
      ),
    );
  }

  /// Presentation label only — the underlying value is always the real
  /// server `type` token (earn/withdraw/refund/bonus/penalty).
  String _typeLabel(String type) {
    return switch (type) {
      'earn' => 'Reward Earned',
      'withdraw' => 'Withdrawal',
      'refund' => 'Refund',
      'bonus' => 'Bonus',
      'penalty' => 'Penalty',
      _ => type,
    };
  }
}
