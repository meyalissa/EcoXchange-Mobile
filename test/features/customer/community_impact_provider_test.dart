// EcoXchange Mobile — CommunityImpactProvider tests.
//
// The repository is faked by subclassing the real repository and
// overriding its one public method — no HTTP/Dio call ever happens here.
// Asserts the provider passes the right period/state/area query params
// through on every filter change, and never invents a figure the fake
// "server" didn't return (suppressed → null fields pass through as-is).

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/community_impact.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/community_impact_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/community_impact_provider.dart';

class _RecordedCall {
  const _RecordedCall({required this.period, required this.state, required this.area});
  final String period;
  final String? state;
  final String? area;
}

class _FakeCommunityImpactRepository extends CommunityImpactRepository {
  _FakeCommunityImpactRepository({this.result, this.errorToThrow}) : super(ApiClient());

  final CommunityImpactSummary? result;
  final ApiException? errorToThrow;
  final List<_RecordedCall> calls = [];

  @override
  Future<CommunityImpactSummary> getImpact({String period = 'all_time', String? state, String? area}) async {
    calls.add(_RecordedCall(period: period, state: state, area: area));
    if (errorToThrow != null) throw errorToThrow!;
    return result!;
  }
}

CommunityImpactSummary _summaryJson({
  String period = 'all_time',
  String? state,
  String? area,
  bool suppressed = false,
  int? completedPickups = 10,
  double? totalWeightKg = 50.0,
  int? participatingCustomers = 6,
  List<String> availableStates = const ['Selangor'],
  List<String> availableAreas = const ['Shah Alam'],
}) {
  return CommunityImpactSummary.fromJson({
    'period': period,
    'state': state,
    'area': area,
    'location_label': area ?? state ?? 'Malaysia-wide',
    'available_states': availableStates,
    'available_areas': availableAreas,
    'suppressed': suppressed,
    'suppression_threshold': 5,
    'completed_pickups': suppressed ? null : completedPickups,
    'total_weight_kg': suppressed ? null : totalWeightKg,
    'participating_customers': suppressed ? null : participatingCustomers,
    'trend': {'labels': ['Jan 2026'], 'data': [50.0]},
    'area_comparison': [
      {'city': 'Shah Alam', 'pickups': 10, 'total_weight_kg': 50.0},
    ],
  });
}

void main() {
  group('CommunityImpactProvider', () {
    test('load() populates real API-backed state', () async {
      final provider = CommunityImpactProvider(_FakeCommunityImpactRepository(result: _summaryJson()));

      await provider.load();

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.data!.completedPickups, 10);
      expect(provider.data!.totalWeightKg, 50.0);
      expect(provider.data!.participatingCustomers, 6);
    });

    test('suppressed scope surfaces null figures, never a guessed value', () async {
      final provider = CommunityImpactProvider(_FakeCommunityImpactRepository(result: _summaryJson(suppressed: true)));

      await provider.load();

      expect(provider.data!.suppressed, isTrue);
      expect(provider.data!.completedPickups, isNull);
      expect(provider.data!.totalWeightKg, isNull);
      expect(provider.data!.participatingCustomers, isNull);
    });

    test('setPeriod() reloads with the new period', () async {
      final repo = _FakeCommunityImpactRepository(result: _summaryJson());
      final provider = CommunityImpactProvider(repo);
      await provider.load();

      await provider.setPeriod('this_month');

      expect(provider.period, 'this_month');
      expect(repo.calls.last.period, 'this_month');
    });

    test('setState() reloads with the new state and clears any selected area', () async {
      final repo = _FakeCommunityImpactRepository(result: _summaryJson());
      final provider = CommunityImpactProvider(repo);
      await provider.load();
      await provider.setArea('Shah Alam');

      await provider.setState('Selangor');

      expect(provider.state, 'Selangor');
      expect(provider.area, isNull);
      expect(repo.calls.last.state, 'Selangor');
      expect(repo.calls.last.area, isNull);
    });

    test('setArea() reloads with the new area while keeping the current state', () async {
      final repo = _FakeCommunityImpactRepository(result: _summaryJson());
      final provider = CommunityImpactProvider(repo);
      await provider.load();
      await provider.setState('Selangor');

      await provider.setArea('Shah Alam');

      expect(repo.calls.last.state, 'Selangor');
      expect(repo.calls.last.area, 'Shah Alam');
    });

    test('a failed request surfaces the real ApiException, not fake data', () async {
      final provider = CommunityImpactProvider(
        _FakeCommunityImpactRepository(errorToThrow: const NetworkException('Could not connect.')),
      );

      await provider.load();

      expect(provider.isLoading, isFalse);
      expect(provider.data, isNull);
      expect(provider.error, isA<NetworkException>());
    });
  });
}
