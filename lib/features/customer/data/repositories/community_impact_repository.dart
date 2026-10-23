import '../../../../core/api/api_client.dart';
import '../models/community_impact.dart';
import '../models/community_leaderboard.dart';
import '../models/personal_impact.dart';

/// EcoXchange Mobile — GET /api/v1/customer/community-impact(/leaderboard).
/// Pure fetch + parse; no calculation happens here — every figure is
/// already computed server-side by CommunityImpactService (the same
/// service the web Community Impact/Leaderboard pages use).
class CommunityImpactRepository {
  CommunityImpactRepository(this._api);

  final ApiClient _api;

  Future<CommunityImpactSummary> getImpact({String period = 'all_time', String? state, String? area}) async {
    final data = await _api.get('/customer/community-impact', query: {
      'period': period,
      if (state != null) 'state': state,
      if (area != null) 'area': area,
    });
    return CommunityImpactSummary.fromJson(data);
  }

  Future<CommunityLeaderboardResult> getLeaderboard({String view = 'area', String period = 'all_time'}) async {
    final data = await _api.get('/customer/community-impact/leaderboard', query: {
      'view': view,
      'period': period,
    });
    return CommunityLeaderboardResult.fromJson(data);
  }

  /// One customer's own impact — always `$request->user()->id` server-side
  /// via the auth token, never a parameter here, so there is no way to
  /// request another customer's figures through this method.
  Future<PersonalImpactSummary> getPersonalImpact({String period = 'this_month'}) async {
    final data = await _api.get('/customer/community-impact/personal', query: {'period': period});
    return PersonalImpactSummary.fromJson(data);
  }
}
