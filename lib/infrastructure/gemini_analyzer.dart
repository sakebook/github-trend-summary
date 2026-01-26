import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/interfaces.dart';
import '../core/models.dart';
import '../core/result.dart';

class GeminiAnalyzer implements TrendAnalyzer {
  final String apiKey;
  final String model;
  final http.Client _client;

  GeminiAnalyzer({
    required this.apiKey,
    this.model = 'gemini-2.0-flash',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<Result<JapaneseSummary, Exception>> analyze(
      Repository repository) async {
    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

      final prompt = '''
以下のGitHubリポジトリの情報を、開発者目線で詳細に分析し、日本語で要約してください。
リポジトリ名: ${repository.owner}/${repository.name}
説明: ${repository.description ?? '説明なし'}
URL: ${repository.url}

出力は必ず以下のJSON形式のみで返してください。
{
  "background": "このリポジトリが解決しようとしている課題や開発の背景",
  "techStack": ["主要言語", "フレームワーク", "注目すべきライブラリ"],
  "whyHot": "スター数の急増や開発活発度から推測される、エンジニアが注目すべき理由",
  "summary": "このプロジェクトの本質を一言で表すと何ですか？"
}
''';

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
        }
      };

      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        return Failure(Exception(
            'Gemini API error: ${response.statusCode} - ${response.body}'));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>;
      if (candidates.isEmpty) {
        return Failure(Exception('No candidates returned from Gemini'));
      }

      final content = candidates.first['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List<dynamic>;
      if (parts.isEmpty) {
        return Failure(Exception('No parts returned from Gemini'));
      }

      final text = parts.first['text'] as String;
      final Map<String, dynamic> responseJson = jsonDecode(text);

      return Success(JapaneseSummary(
        repository: repository,
        summary: responseJson['summary'] as String? ?? 'No summary',
        background: responseJson['background'] as String? ?? 'No background',
        techStack: List<String>.from(responseJson['techStack'] as List? ?? []),
        whyHot: responseJson['whyHot'] as String? ?? 'No reason provided',
      ));
    } catch (e) {
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }
}
