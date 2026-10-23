import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../data/models/reward_transaction.dart';
import '../providers/dashboard_provider.dart';
import '../providers/reward_provider.dart';

/// EcoXchange Mobile — Rewards (Phase 4C.2 §11, restyled Phase 4C.3 to
/// match `rewards-dashboard.html`). Shows the real RM `reward_balance`
/// and the real transaction ledger only. NO points system, NO "1 RM = 100
/// points" conversion, NO membership level/"Gold" badge, NO Withdraw
/// button (there is no redemption endpoint) — see CustomerRewardRepository/
/// RewardTransactionModel. "Lifetime" is the server's own
/// `total_rewards_earned` (GET /customer/dashboard). "This Month" is
/// computed client-side purely from transactions already fetched for
/// display — never a separate invented number. The All/Earned/Bonus chips
/// filter the loaded ledger by its real `type` (no withdrawals exist).
class RewardScreen extends StatefulWidget {
  const RewardScreen({super.key});

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  final _scrollController = ScrollController();

  /// Client-side filter over the loaded ledger: null = all, else a real
  /// server `type` token. Only `earn` and `bonus` exist in the data today.
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RewardProvider>().load();
      final dashboard = context.read<DashboardProvider>();
      if (dashboard.data == null && !dashboard.isLoading) dashboard.load();
    });
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
    final lifetime = context.watch<DashboardProvider>().data?.totalRewardsEarned;
    final shown = _typeFilter == null ? provider.transactions : provider.transactions.where((t) => t.type == _typeFilter).toList();

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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Wallet & Rewards', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Rewards Hub', style: AppTheme.displayFont(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    key: const Key('rewards-wallet'),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadii.r20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('WALLET BALANCE', style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          'RM ${balance.toStringAsFixed(2)}',
                          style: AppTheme.displayFont(fontSize: 29, fontWeight: FontWeight.w900, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Flexible(child: _WalletFigure(label: 'THIS MONTH', value: 'RM ${_thisMonthTotal(provider.transactions).toStringAsFixed(2)}')),
                            const SizedBox(width: 20),
                            if (lifetime != null) Flexible(child: _WalletFigure(label: 'LIFETIME', value: 'RM ${lifetime.toStringAsFixed(2)}')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // The heading keeps its own natural (unshrunk) width and a
              // hard one-line guarantee; the chip group is the one thing
              // given a bounded width (via Expanded) so IT is the side
              // that wraps onto a second row at narrow widths — the
              // heading can never be squeezed or pushed onto two lines.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Transactions',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.displayFont(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.n800),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (label, type) in const [('All', null), ('Earned', 'earn'), ('Bonus', 'bonus')])
                          ChoiceChip(
                            key: Key('rewards-filter-${type ?? 'all'}'),
                            label: Text(label),
                            selected: _typeFilter == type,
                            onSelected: (_) => setState(() => _typeFilter = type),
                            selectedColor: AppColors.green500,
                            labelStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _typeFilter == type ? Colors.white : AppColors.n700),
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.n100, borderRadius: BorderRadius.circular(AppRadii.r12)),
                  child: Text(
                    provider.transactions.isEmpty ? 'No reward transactions yet.' : 'No transactions of this type loaded.',
                    style: const TextStyle(color: AppColors.n500, fontSize: 13),
                  ),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: AppColors.n0, borderRadius: BorderRadius.circular(AppRadii.r20), boxShadow: AppShadows.sh1),
                child: Column(
                  children: [
                    for (final tx in shown) ...[
                      if (tx != shown.first) const Divider(height: 1, color: AppColors.n100),
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

class _WalletFigure extends StatelessWidget {
  const _WalletFigure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700))),
        const SizedBox(height: 2),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900))),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(AppRadii.r12)),
            child: Icon(icon, size: 16, color: transaction.isCredit ? AppColors.green600 : AppColors.red),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_typeLabel(transaction.type), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.n800)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (transaction.pickupId != null) 'Pickup #PK-${transaction.pickupId}',
                    if (transaction.note != null && transaction.note!.isNotEmpty) transaction.note!,
                    if (transaction.transactedAt != null) transaction.transactedAt!.split('T').first,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.n500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('$sign RM ${transaction.amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: amountColor)),
            ),
          ),
        ],
      ),
    );
  }

  /// Presentation label only — the underlying value is always the real
  /// server `type` token (earn/withdraw/refund/bonus/penalty).
  String _typeLabel(String type) {
    return switch (type) {
      'earn' => 'Pickup Completed',
      'withdraw' => 'Withdrawal',
      'refund' => 'Refund',
      'bonus' => 'Bonus',
      'penalty' => 'Penalty',
      _ => type,
    };
  }
}
