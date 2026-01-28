import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/interfaces.dart';
import '../core/models.dart';
import '../core/result.dart';

class GitHubFetcher implements RepositoryFetcher {
  final String? apiToken;
  final http.Client _client;

  GitHubFetcher({this.apiToken, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<Result<List<Repository>, Exception>> fetchTrending(
    String target, {
    int? minStars,
    int? maxStars,
    bool newOnly = false,
    bool isTopic = false,
  }) async {
    try {
      final lookbackDate = DateTime.now().subtract(const Duration(days: 7));
      final dateStr = lookbackDate.toIso8601String().split('T')[0];

      // 言語指定またはトピック指定を query に含める
      String filterPart = '';
      if (isTopic) {
        filterPart = 'topic:$target ';
      } else {
        final isAll = target.toLowerCase() == 'all';
        filterPart = isAll ? '' : 'language:$target ';
      }

      // 動的なデフォルト: 全言語なら100、特定言語/トピックなら50
      final effectiveMinStars = minStars ?? (target.toLowerCase() == 'all' && !isTopic ? 100 : 50);
      
      // スター数の範囲指定
      final starsRange = maxStars != null 
          ? 'stars:$effectiveMinStars..$maxStars' 
          : 'stars:>=$effectiveMinStars';

      // newOnlyなら作成日(created)、そうでなければ更新日(pushed)で絞り込む
      final dateFilter = newOnly ? 'created' : 'pushed';
      
      final query = '$filterPart$dateFilter:>=$dateStr $starsRange fork:false';

      final url = Uri.https('api.github.com', '/search/repositories', {
        'q': query,
        'sort': 'stars',
        'order': 'desc',
        'per_page': '10',
      });

      final headers = {
        'Accept': 'application/vnd.github+json',
        if (apiToken != null && apiToken!.isNotEmpty)
          'Authorization': 'token $apiToken',
      };

      final response = await _client.get(url, headers: headers);

      if (response.statusCode != 200) {
        return Failure(Exception(
            'GitHub API error: ${response.statusCode} ${response.body}'));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;

      final repos = items.map((item) {
        final map = item as Map<String, dynamic>;
        return (
          name: map['name'] as String,
          owner: (map['owner'] as Map<String, dynamic>)['login'] as String,
          description: map['description'] as String?,
          url: map['html_url'] as String,
          stars: map['stargazers_count'] as int,
          language: map['language'] as String?,
        );
      }).toList();

      return Success(repos);
    } catch (e) {
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }
}
