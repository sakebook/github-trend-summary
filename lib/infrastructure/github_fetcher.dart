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
      String language) async {
    try {
      final query = 'language:$language sort:stars-updated';
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
