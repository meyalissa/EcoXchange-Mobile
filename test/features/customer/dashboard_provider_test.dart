// EcoXchange Mobile — DashboardProvider tests (Phase 4C.2 §21).
//
// Repositories are faked by subclassing the real repository and overriding
// its one public method — no HTTP/Dio call ever happens in these tests.
// This is test-only mocking of the repository layer (explicitly allowed by
// the brief); nothing here is a production mock-data path.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/dashboard_data.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_dashboard_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/dashboard_provider.dart';

class _FakeDashboardRepository extends CustomerDashboardRepository {
  _FakeDashboardRepository({this.result, this.errorToThrow}) : super(ApiClient());

  final DashboardData? result;
  final ApiException? errorToThrow;

  @override
  Future<DashboardData> getDashboard() async {
    if (errorToThrow != null) throw errorToThrow!;
    return result!;
  }
}

DashboardData _dashboardJson({
  int totalPickups = 5,
  int completedPickups = 2,
  int pendingPickups = 1,
  Map<String, dynamic>? activePickup,
  List<Map<String, dynamic>> recentPickups = const [],
}) {
  return DashboardData.fromJson({
    'total_pickups': totalPickups,
    'completed_pickups': completedPickups,
    'pending_pickups': pendingPickups,
    'total_weight_kg': 12.5,
    'total_rewards_earned': 30.0,
    'active_pickup': activePickup,
    'recent_pickups': recentPickups,
  });
}

Map<String, dynamic> _pickupSummaryJson({int id = 1, String status = 'assigned'}) {
  return {
    'id': id,
    'reference': 'PK-$id',
    'status': status,
    'pickup_date': '2026-09-10',
    'pickup_time': '09:00 AM',
    'estimated_weight_kg': 5.0,
    'actual_weight_kg': null,
    'estimated_reward': 10.0,
    'actual_reward': null,
    'centre': {'name': 'EcoRecycle Shah Alam'},
    'items': [],
    'assigned_rider': null,
    'created_at': '2026-09-01T00:00:00Z',
  };
}

void main() {
  group('DashboardProvider', () {
    test('load() populates real API-backed state', () async {
      final data = _dashboardJson(
        activePickup: _pickupSummaryJson(id: 42),
        recentPickups: [_pickupSummaryJson(id: 1), _pickupSummaryJson(id: 2, status: 'completed')],
      );
      final provider = DashboardProvider(_FakeDashboardRepository(result: data));

      await provider.load();

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.data!.totalPickups, 5);
      expect(provider.data!.activePickup!.id, 42);
      expect(provider.data!.recentPickups, hasLength(2));
    });

    test('honest empty state when there is no active pickup or recent pickups', () async {
      final data = _dashboardJson(activePickup: null, recentPickups: const []);
      final provider = DashboardProvider(_FakeDashboardRepository(result: data));

      await provider.load();

      expect(provider.data!.activePickup, isNull);
      expect(provider.data!.recentPickups, isEmpty);
    });

    test('a failed request surfaces the real ApiException, not fake data', () async {
      final provider = DashboardProvider(
        _FakeDashboardRepository(errorToThrow: const NetworkException('Could not connect.')),
      );

      await provider.load();

      expect(provider.isLoading, isFalse);
      expect(provider.data, isNull);
      expect(provider.error, isA<NetworkException>());
    });
  });
}
