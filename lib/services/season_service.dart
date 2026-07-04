import 'package:junko_bodie/models/season_ranking.dart';
import 'package:junko_bodie/services/api_service.dart';

/// Service for retrieving season rankings and metadata.
class SeasonService {
  final ApiService _api = ApiService();

  /// Fetch season ranking standings for the current year.
  Future<SeasonRanking> getSeasonRankings() async {
    final json = await _api.get('/api/season/rankings');
    return SeasonRanking.fromJson(json);
  }
}
