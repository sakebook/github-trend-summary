import 'dart:convert';
import 'dart:io';
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
    final result = await analyzeBatch([repository]);
    switch (result) {
      case Success(value: final list):
        return Success(list.first);
      case Failure(error: final error):
        return Failure(error);
    }
  }

  @override
  Future<Result<List<JapaneseSummary>, Exception>> analyzeBatch(
      List<Repository> repositories) async {
    if (repositories.isEmpty) return Success([]);

    const maxRetries = 3;
    int retryCount = 0;

    while (true) {
      try {
        final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

        final repoListText = repositories.asMap().entries.map((e) {
          final i = e.key + 1;
          final r = e.value;
          return '$i. ${r.owner}/${r.name}: ${r.description ?? '説明なし'} (${r.url})';
        }).join('\n');

        final prompt = '''
以下の複数のGitHubリポジトリを分析し、開発者向けに日本語で技術解説してください。
バッチ処理（複数同時）であっても、一度に1つずつ処理する場合と同等、あるいはそれ以上の「情報の密度」と「専門家としての洞察」を持って出力してください。

分析のガイドライン：
- **background**: 単なる説明の繰り返しではなく、そのリポジトリが解決しようとしている現代的な課題や、動作の内部的な仕組みを深く読み取ってください。Descriptionが短い場合でも、名称やURLから技術的コンテキストを推測し、専門家としてそのプロジェクトの「存在意義」を解説してください。
- **techStack**: DescriptionやURLから特定できる、または合理的に推測できる技術（言語、フレームワーク、ライブラリ）を可能な限り具体的に列挙してください。
- **whyHot**: 技術者の知的好奇心を刺激する核心部分や、既存の代替手段に対する優位性、将来的な発展性を鋭く指摘してください。「〜に役立つ」といった平凡な結論で終わらせず、そのプロジェクトが持つ独自の「エッジ」を具体的に言語化してください。
- **summary**: プロジェクトの機能的本質を、技術者が即座に理解できる簡潔かつ正確な表現で記述してください。

リポジトリリスト:
$repoListText

出力フォーマット（JSON配列のみ）:
[
  {
    "background": "技術的な背景・解決課題・詳細な仕組みの解説（250文字程度まで）",
    "techStack": ["主要言語", "具体的なライブラリや技術キーワード"],
    "whyHot": "技術的な独自性・注目すべき核心部分（250文字程度まで）",
    "summary": "機能的本質を突いた正確な説明"
  },
  ...
]
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
            print(
                '    ⚠️ Transient error (${response.statusCode}). Retrying in $delaySeconds seconds... ($retryCount/$maxRetries)');
            await Future.delayed(Duration(seconds: delaySeconds));
            continue;
          }
          return Failure(Exception(
              'Gemini API error: ${response.statusCode} - ${response.body}'));
        }

        final dynamic decodedResponse = jsonDecode(response.body);
        if (decodedResponse is! Map) {
          return Failure(Exception(
              'Root response is not a Map. Type: ${decodedResponse.runtimeType}'));
        }
        final data = Map<String, dynamic>.from(decodedResponse);

        final candidates = data['candidates'];
        if (candidates is! List || candidates.isEmpty) {
          return Failure(Exception('No candidates found or not a list'));
        }

        final candidate = candidates.first;
        if (candidate is! Map) {
          return Failure(Exception('Candidate is not a Map'));
        }

        final content = candidate['content'];
        if (content is! Map) {
          return Failure(Exception('Content is not a Map'));
        }

        final parts = content['parts'];
        if (parts is! List || parts.isEmpty) {
          return Failure(Exception('Parts is not a List or empty'));
        }

        final part = parts.first;
        if (part is! Map) {
          return Failure(Exception('Part is not a Map'));
        }

        final text = part['text'];
        if (text is! String) {
          return Failure(Exception('Text part is not a String'));
        }

        final dynamic decoded = jsonDecode(_cleanJson(text));
        if (decoded is! List) {
          return Failure(Exception(
              'Expected JSON array from Gemini batch request, but got: ${decoded.runtimeType}'));
        }

        final List<JapaneseSummary> resultSummaries = [];
        for (var i = 0; i < decoded.length; i++) {
          if (i >= repositories.length) break; // 念のため

          final item = decoded[i];
          if (item is! Map) continue;

          final responseJson = Map<String, dynamic>.from(item);
          final techStackData = responseJson['techStack'];
          final List<String> techStack = (techStackData is List)
              ? techStackData.map((e) => e.toString()).toList()
              : [];

          resultSummaries.add(JapaneseSummary(
            repository: repositories[i],
            summary: responseJson['summary']?.toString() ?? 'No summary',
            background:
                responseJson['background']?.toString() ?? 'No background',
            techStack: techStack,
            whyHot: responseJson['whyHot']?.toString() ?? 'No reason provided',
          ));
        }

        return Success(resultSummaries);
      } on SocketException catch (e) {
        if (retryCount < maxRetries) {
          retryCount++;
          final delaySeconds = 2 * retryCount;
          print(
              '    ⚠️ Network error: $e. Retrying in $delaySeconds seconds... ($retryCount/$maxRetries)');
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        }
        return Failure(e);
      } catch (e) {
        return Failure(e is Exception ? e : Exception(e.toString()));
      }
    }
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
