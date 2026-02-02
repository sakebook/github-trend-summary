import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/interfaces.dart';
import '../core/models.dart';
import '../core/result.dart';
import '../core/logger.dart';

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
      final lookbackDays = newOnly ? 14 : 3;
      final lookbackDate = DateTime.now().subtract(Duration(days: lookbackDays));
      final dateStr = lookbackDate.toIso8601String().split('T')[0];
      final dateFilter = newOnly ? 'created:>=$dateStr' : 'pushed:>=$dateStr';

      // 言語指定またはトピック指定を query に含める
      String filterPart = '';
      if (isTopic) {
        filterPart = 'topic:$target ';
      } else {
        final isAll = target.toLowerCase() == 'all';
        filterPart = isAll ? '' : 'language:$target ';
      }

      // 動的な下限設定: 全言語なら50、特定言語/トピックなら20 (Rising Stars向けに調整)
      final effectiveMinStars = minStars ?? (target.toLowerCase() == 'all' && !isTopic ? 50 : 20);
      
      // スター数の上限設定: 殿堂入り巨人を避けるためデフォルトで 10,000 を上限とする
      final effectiveMaxStars = maxStars ?? 10000;
      
      final starsRange = 'stars:$effectiveMinStars..$effectiveMaxStars';

      // newOnly なら作成日(created)、そうでなければ更新日(pushed)で絞り込む
      final query = '$filterPart' '$dateFilter $starsRange fork:false';

      final url = Uri.https('api.github.com', '/search/repositories', {
        'q': query,
        'sort': 'stars',
        'order': 'desc',
        'per_page': '20',
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
          readmeContent: null, // 初期値はnull、後でfetchReadmeで埋める
        );
      }).toList();

      return Success(repos);
    } catch (e) {
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }

  Future<String?> fetchReadme(Repository repo) async {
    try {
      final url =
          Uri.https('api.github.com', '/repos/${repo.owner}/${repo.name}/readme');
      
      final headers = {
        'Accept': 'application/vnd.github+json',
        if (apiToken != null && apiToken!.isNotEmpty)
          'Authorization': 'token $apiToken',
      };

      final response = await _client.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'] as String?;
        if (content != null) {
          // GitHub API returns Base64 encoded content with newlines
          final cleaned = content.replaceAll('\n', '');
          final decoded = utf8.decode(base64.decode(cleaned));
          return _extractKeySections(decoded);
        }
      } else if (response.statusCode == 404) {
        Logger.warning('README not found for ${repo.owner}/${repo.name}');
      } else {
        Logger.warning('Failed to fetch README for ${repo.owner}/${repo.name}: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      Logger.error('Error fetching README for ${repo.owner}/${repo.name}: $e');
      return null;
    }
  }

  /// READMEの中から重要なセクションを優先的に抽出する
  String _extractKeySections(String readme) {
    const maxChars = 15000;
    if (readme.length <= maxChars) return readme;

    final lines = readme.split('\n');
    final sectionHeaders = [
      'features',
      'key features',
      'what is',
      'introduction',
      'getting started',
      'usage',
      'why',
      'motivation',
      'architecture',
    ];

    final Map<String, List<String>> sections = {};
    String currentSection = 'intro';
    sections[currentSection] = [];

    for (final line in lines) {
      final trimmed = line.trim().toLowerCase();
      bool foundHeader = false;
      if (trimmed.startsWith('#')) {
        for (final header in sectionHeaders) {
          if (trimmed.contains(header)) {
            currentSection = header;
            sections[currentSection] = [line];
            foundHeader = true;
            break;
          }
        }
      }
      if (!foundHeader) {
        sections[currentSection]!.add(line);
      }
    }

    final buffer = StringBuffer();
    // Introduction (または冒頭) を最初に入れる
    buffer.writeln(sections['intro']?.join('\n') ?? '');

    // その他の重要セクションを追加
    for (final header in sectionHeaders) {
      if (header == 'intro') continue;
      if (sections.containsKey(header)) {
        buffer.writeln('\n' + sections[header]!.join('\n'));
      }
      if (buffer.length > maxChars) break;
    }

    final result = buffer.toString();
    return result.length > maxChars ? result.substring(0, maxChars) : result;
  }
}
