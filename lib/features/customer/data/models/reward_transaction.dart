/// EcoXchange Mobile — one reward ledger entry, shaped EXACTLY like
/// `App\Http\Resources\Customer\RewardTransactionResource` (confirmed by
/// inspection). Monetary (RM) only — there is no points system anywhere in
/// this backend, so none exists here either (see reward_screen.dart).
class RewardTransactionModel {
  const RewardTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.status,
    required this.note,
    required this.pickupId,
    required this.transactedAt,
  });

  factory RewardTransactionModel.fromJson(Map<String, dynamic> json) {
    return RewardTransactionModel(
      id: json['id'] as int,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      balanceAfter: (json['balance_after'] as num).toDouble(),
      status: json['status'] as String?,
      note: json['note'] as String?,
      pickupId: json['pickup_id'] as int?,
      transactedAt: json['transacted_at'] as String?,
    );
  }

  final int id;
  final String type;
  final double amount;
  final double balanceAfter;
  final String? status;
  final String? note;
  final int? pickupId;
  final String? transactedAt;

  /// Real transaction type token from the server (earn/withdraw/refund/
  /// bonus/penalty — see RewardTransaction model) — only used here to
  /// choose a display icon/sign, never reinterpreted as a different value.
  bool get isCredit => type == 'earn' || type == 'refund' || type == 'bonus';
}
