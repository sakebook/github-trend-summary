import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/interfaces.dart';
import '../core/models.dart';
import '../core/result.dart';
import '../core/logger.dart';

class GeminiAnalyzer implements TrendAnalyzer {
  final String apiKey;
  final String model;
  final http.Client _client;

  GeminiAnalyzer({
    required this.apiKey,
    this.model = 'gemini-3-flash-preview',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<Result<JapaneseSummary, Exception>> analyze(
      Repository repository) async {
    const maxRetries = 3;
    int retryCount = 0;

    while (true) {
      try {
        final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');


        final readmeContext = repository.readmeContent != null
            ? 'README.mdの内容:\n${repository.readmeContent!.length > 15000 ? repository.readmeContent!.substring(0, 15000) + "...(truncated)" : repository.readmeContent}'
            : 'README.md: 取得できませんでした。';

        final prompt = '''
以下のGitHubリポジトリを深く分析し、熟練のシニアエンジニアに向けて日本語で技術解説してください。
READMEの内容（提供されている場合）を最優先の情報源とし、ファクトに基づいたレポートを作成してください。

リポジトリ: ${repository.owner}/${repository.name}
URL: ${repository.url}
説明: ${repository.description ?? '説明なし'}
$readmeContext

出力フォーマット（JSONのみ）:
{
  "summary": "プロジェクトの機能的本質を突いた、簡潔かつ正確な要約（50文字程度）",
  "techStack": ["主要言語", "推測されるフレームワーク", "ライブラリ", "アーキテクチャ名"],
  "useCase": "【具体的な適用シーン】このツールが最も輝く具体的な開発シチュエーション（例：「大規模なマイクロサービスのログ集約」「個人のポートフォリオサイト構築」など具体的に）",
  "rivalComparison": "【競合との差別化】既存の有名ツール（具体的名称を挙げること）と比較した際の明確な違いや、このプロジェクトが持つ独自の技術的エッジ",
  "keyFeatures": [
    "機能1: 具体的な機能説明",
    "機能2: 具体的な機能説明",
    "機能3: 具体的な機能説明"
  ],
  "maturity": "下記の中から最も適切なものを1つ選択: 'Experimental (実験的)', 'Active Development (開発中)', 'Stable (安定版)', 'Production Ready (本番導入可)', 'Legacy (レガシー)'"
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
          final isTransient = response.statusCode == 429 ||
              (response.statusCode >= 500 && response.statusCode < 600);

          if (isTransient && retryCount < maxRetries) {
            retryCount++;
            final delaySeconds = 2 * retryCount;
            Logger.warning('Transient error (${response.statusCode}). Retrying in $delaySeconds seconds... ($retryCount/$maxRetries)');
            await Future.delayed(Duration(seconds: delaySeconds));
            continue;
          }
          return Failure(Exception(
              'Gemini API error: ${response.statusCode} - ${response.body}'));
        }

        final dynamic decodedResponse = jsonDecode(response.body);
        final content = decodedResponse['candidates'][0]['content']['parts'][0]['text'];
        final jsonText = _cleanJson(content);
        final dynamic decodedJson = jsonDecode(jsonText);
        final Map<String, dynamic> data;
        
        if (decodedJson is Map<String, dynamic>) {
          data = decodedJson;
        } else if (decodedJson is List && decodedJson.isNotEmpty && decodedJson.first is Map<String, dynamic>) {
           // Handle case where Gemini returns a list wrapping the object
           data = decodedJson.first as Map<String, dynamic>;
        } else {
             throw Exception('Unexpected JSON format: $jsonText');
        }

        final techStackData = data['techStack'];
        final List<String> techStack = (techStackData is List)
            ? techStackData.map((e) => e.toString()).toList()
            : [];
        
        final keyFeaturesData = data['keyFeatures'];
        final List<String> keyFeatures = (keyFeaturesData is List)
            ? keyFeaturesData.map((e) => e.toString()).toList()
            : [];

        return Success(JapaneseSummary(
          repository: repository,
          summary: data['summary']?.toString() ?? 'No summary',
          techStack: techStack,
          useCase: data['useCase']?.toString() ?? 'No use case provided',
          rivalComparison:
              data['rivalComparison']?.toString() ?? 'No comparison provided',
          keyFeatures: keyFeatures,
          maturity: data['maturity']?.toString() ?? 'Unknown',
        ));
      } on SocketException catch (e) {
        if (retryCount < maxRetries) {
          retryCount++;
          final delaySeconds = 2 * retryCount;
          Logger.warning('Network error: $e. Retrying in $delaySeconds seconds... ($retryCount/$maxRetries)');
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        }
        return Failure(e);
      } catch (e) {
        return Failure(e is Exception ? e : Exception(e.toString()));
      }
    }
  }

  @override
  Future<Result<List<JapaneseSummary>, Exception>> analyzeBatch(
      List<Repository> repositories) async {
    final results = <JapaneseSummary>[];
    for (final repo in repositories) {
      final result = await analyze(repo);
      switch (result) {
        case Success(value: final summary):
          results.add(summary);
        case Failure(error: final e):
          Logger.error('Failed to analyze ${repo.owner}/${repo.name}: $e');
      }
      // 個別分析の間隔を少し空ける（レート制限対応）
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    return Success(results);
  }

  String _cleanJson(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      final lines = cleaned.split('\n');
      if (lines.length > 2) {
        cleaned = lines.getRange(1, lines.length - 1).join('\n');
      }
    }
    return cleaned.trim();
  }
}
