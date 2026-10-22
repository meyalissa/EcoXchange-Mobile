// EcoXchange Mobile — CommunityLeaderboardProvider tests.
//
// Repository is faked by subclassing and overriding its one public
// method — asserts the provider passes the right view/period through and
// never re-sorts/re-ranks what the fake "server" already returned.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/community_leaderboard.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/community_impact_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/community_leaderboard_provider.dart';

class _RecordedCall {
  const _RecordedCall({required this.view, required this.period});
  final String view;
  final String period;
}

class _FakeCommunityImpactRepository extends CommunityImpactRepository {
  _FakeCommunityImpactRepository({this.result, this.errorToThrow}) : super(ApiClient());

  final CommunityLeaderboardResult? result;
  final ApiException? errorToThrow;
  final List<_RecordedCall> calls = [];

  @override
  Future<CommunityLeaderboardResult> getLeaderboard({String view = 'area', String period = 'all_time'}) async {
    calls.add(_RecordedCall(view: view, period: period));
    if (errorToThrow != null) throw errorToThrow!;
    return result!;
  }
}

CommunityLeaderboardResult _resultJson({
  String view = 'area',
  String period = 'all_time',
  String metric = 'total_weight',
  bool includesDemoData = false,
  List<Map<String, dynamic>> rankings = const [
    {'rank': 1, 'location': 'Shah Alam, Selangor', 'total_weight_kg': 57.0, 'pickups': 6, 'participants': 6, 'has_demo_data': false},
  ],
}) {
  return CommunityLeaderboardResult.fromJson({
    'view': view,
    'period': period,
    'metric': metric,
    'suppression_threshold': 5,
    'includes_demo_data': includesDemoData,
    'rankings': rankings,
  });
}

void main() {
  group('CommunityLeaderboardProvider', () {
    test('load() populates real API-backed rankings', () async {
      final provider = CommunityLeaderboardProvider(_FakeCommunityImpactRepository(result: _resultJson()));

      await provider.load();

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.data!.rankings, hasLength(1));
      expect(provider.data!.rankings.first.location, 'Shah Alam, Selangor');
      expect(provider.data!.rankings.first.rank, 1);
    });

    test('empty rankings (no qualifying data) is an honest empty list, not an error', () async {
      final provider = CommunityLeaderboardProvider(_FakeCommunityImpactRepository(result: _resultJson(rankings: const [])));

      await provider.load();

      expect(provider.error, isNull);
      expect(provider.data!.rankings, isEmpty);
    });

    test('setView() reloads with the new view', () async {
      final repo = _FakeCommunityImpactRepository(result: _resultJson());
      final provider = CommunityLeaderboardProvider(repo);
      await provider.load();

      await provider.setView('participation');

      expect(provider.view, 'participation');
      expect(repo.calls.last.view, 'participation');
    });

    test('setPeriod() reloads with the new period', () async {
      final repo = _FakeCommunityImpactRepository(result: _resultJson());
      final provider = CommunityLeaderboardProvider(repo);
      await provider.load();

      await provider.setPeriod('this_week');

      expect(provider.period, 'this_week');
      expect(repo.calls.last.period, 'this_week');
    });

    test('demo-data flag passes through untouched for transparency', () async {
      final provider = CommunityLeaderboardProvider(_FakeCommunityImpactRepository(result: _resultJson(includesDemoData: true)));

      await provider.load();

      expect(provider.data!.includesDemoData, isTrue);
    });

    test('a failed request surfaces the real ApiException, not fake data', () async {
      final provider = CommunityLeaderboardProvider(
        _FakeCommunityImpactRepository(errorToThrow: const NetworkException('Could not connect.')),
      );

      await provider.load();

      expect(provider.isLoading, isFalse);
      expect(provider.data, isNull);
      expect(provider.error, isA<NetworkException>());
    });
  });
}
