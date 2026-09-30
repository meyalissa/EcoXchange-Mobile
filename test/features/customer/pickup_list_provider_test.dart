// EcoXchange Mobile — PickupListProvider tests (Phase 4C.2 §21): filter
// behaviour and server-driven pagination.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pagination.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_summary.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/pickup_list_provider.dart';

class _RecordingPickupRepository extends CustomerPickupRepository {
  _RecordingPickupRepository() : super(ApiClient());

  final List<({String? status, String? month, int page})> calls = [];

  @override
  Future<({List<PickupSummary> pickups, Pagination pagination})> getPickups({String? status, String? month, int page = 1}) async {
    calls.add((status: status, month: month, page: page));

    final pickup = PickupSummary.fromJson({
      'id': page,
      'reference': 'PK-$page',
      'status': status ?? 'pending',
      'pickup_date': null,
      'pickup_time': null,
      'estimated_weight_kg': null,
      'actual_weight_kg': null,
      'estimated_reward': null,
      'actual_reward': null,
      'centre': null,
      'items': [],
      'assigned_rider': null,
      'created_at': null,
    });

    return (
      pickups: [pickup],
      pagination: Pagination.fromJson({'current_page': page, 'last_page': 3, 'per_page': 15, 'total': 45}),
    );
  }
}

void main() {
  group('PickupListProvider', () {
    test('setStatusFilter sends only the real API-supported status enum value', () async {
      final repo = _RecordingPickupRepository();
      final provider = PickupListProvider(repo);

      await provider.load();
      await provider.setStatusFilter('completed');

      expect(repo.calls.last.status, 'completed');
      expect(provider.pickups.single.status, 'completed');
    });

    test('setStatusFilter(null) clears the filter ("All")', () async {
      final repo = _RecordingPickupRepository();
      final provider = PickupListProvider(repo);

      await provider.setStatusFilter('assigned');
      await provider.setStatusFilter(null);

      expect(repo.calls.last.status, isNull);
    });

    test('loadMore requests the next real page and appends without re-fetching everything', () async {
      final repo = _RecordingPickupRepository();
      final provider = PickupListProvider(repo);

      await provider.load(); // page 1
      await provider.loadMore(); // page 2

      expect(repo.calls.map((c) => c.page), [1, 2]);
      expect(provider.pickups, hasLength(2));
      expect(provider.hasMore, isTrue); // last_page=3, currentPage=2
    });

    test('loadMore does nothing once the real API reports no next page', () async {
      final repo = _RecordingPickupRepository();
      final provider = PickupListProvider(repo);

      await provider.load();
      await provider.loadMore(); // page 2
      await provider.loadMore(); // page 3 — pagination now says last_page=3, so this should be the last real fetch
      await provider.loadMore(); // should be a no-op — hasMore is false

      expect(repo.calls.length, 3);
    });
  });
}
