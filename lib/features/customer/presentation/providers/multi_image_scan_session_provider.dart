import 'package:flutter/foundation.dart';

import '../../data/models/item.dart';
import 'pickup_booking_provider.dart';

/// EcoXchange Mobile — one completed scan ROUND's real outcome (Part C).
///
/// A "round" is one photo taken all the way through the EXISTING, unchanged
/// `AIScanProvider`/`ScanClassifyScreen` pipeline (single-object classify,
/// the beta multi-object-in-one-photo detector, or manual item choice —
/// whichever the user used for that photo) to a confirmed selection. This
/// class only carries what that pipeline already produced — the real
/// `scan_log_id` from `POST /customer/pickup/image`, the real uploaded
/// image URL, and the real confirmed item/quantity line(s) — never anything
/// computed or guessed here.
@immutable
class ScanRoundResult {
  const ScanRoundResult({required this.scanLogId, required this.imageUrl, required this.quantities});

  final int scanLogId;
  final String? imageUrl;
  final List<PrefillItemQuantity> quantities;
}

/// EcoXchange Mobile — Part C: multiple photos in one scan session.
///
/// Each photo still goes through the EXISTING single-image scan screen
/// unchanged (one real upload + one real classify/detect per photo, with
/// its own confirm-or-correct step) — this provider only ACCUMULATES the
/// real [ScanRoundResult] each round produces, so a single-image scan is
/// literally the case where this list holds exactly one round: there is no
/// separate "single image" code path to keep in sync.
///
/// [combinedQuantities] sums quantities for the SAME confirmed item across
/// different rounds (e.g. two separate photos both confirmed as "Plastic
/// Bottle" become quantity 2) — never inventing a quantity beyond what each
/// round's own real confirmation already established.
class MultiImageScanSessionProvider extends ChangeNotifier {
  /// Mirrors `PickupPreparationController::store()`'s own
  /// `scan_log_ids` `max:10` validation rule — enforced here too so the
  /// user hits a clear limit in the UI instead of a 422 at submission.
  static const maxRounds = 10;

  final List<ScanRoundResult> _rounds = [];

  List<ScanRoundResult> get rounds => List.unmodifiable(_rounds);
  bool get isEmpty => _rounds.isEmpty;
  bool get isFull => _rounds.length >= maxRounds;
  int get roundCount => _rounds.length;

  /// Each round's `scan_log_id` is a fresh, server-assigned id from that
  /// photo's own upload — two GENUINE rounds can never share one, so a
  /// repeat is always an accidental duplicate (e.g. a double tap on
  /// "Continue"/"Yes, that's right" firing the confirm handler twice before
  /// the screen pops) and is silently ignored rather than double-counted.
  void addRound(ScanRoundResult round) {
    if (isFull) return;
    if (_rounds.any((r) => r.scanLogId == round.scanLogId)) return;
    _rounds.add(round);
    notifyListeners();
  }

  void removeRoundAt(int index) {
    if (index < 0 || index >= _rounds.length) return;
    _rounds.removeAt(index);
    notifyListeners();
  }

  List<int> get scanLogIds => _rounds.map((r) => r.scanLogId).toList();

  /// The first round's image, shown as the booking flow's single photo
  /// preview — a reasonable representative thumbnail; every round's own id
  /// still reaches the server via [scanLogIds].
  String? get representativeImageUrl => _rounds.isEmpty ? null : _rounds.first.imageUrl;

  List<PrefillItemQuantity> get combinedQuantities {
    final totals = <int, int>{};
    final models = <int, ItemModel>{};
    for (final round in _rounds) {
      for (final line in round.quantities) {
        totals[line.item.id] = (totals[line.item.id] ?? 0) + line.quantity;
        models[line.item.id] = line.item;
      }
    }
    return [for (final id in totals.keys) PrefillItemQuantity(item: models[id]!, quantity: totals[id]!)];
  }

  int get totalCombinedQuantity => combinedQuantities.fold(0, (sum, l) => sum + l.quantity);
}
