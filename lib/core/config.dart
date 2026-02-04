import 'dart:io';
import 'package:yaml/yaml.dart';

/// アプリケーションの設定を保持するクラス。
/// [config.yaml] からの読み込みや、デフォルト値の提供を行う。
class AppConfig {
  /// 対象とするプログラミング言語のリスト（例: ['dart', 'typescript', 'all']）
  final List<String> languages;

  /// 注目するトピックのリスト（例: ['ai', 'llm', 'mcp']）
  final List<String> topics;

  /// 収集対象とする最小スター数
  final int minStars;

  /// 収集対象とする最大スター数（オプション）
  final int? maxStars;

  /// 過去14日以内に作成されたリポジトリのみを対象とするかどうか
  final bool newOnly;

  /// 使用するGeminiモデルの名称
  final String geminiModel;

  /// 解析から除外するリポジトリのリスト（形式: "owner/name"）
  final List<String> excludeRepos;

  AppConfig({
    required this.languages,
    required this.topics,
    required this.minStars,
    this.maxStars,
    required this.newOnly,
    this.geminiModel = 'gemini-3-flash-preview',
    this.excludeRepos = const [],
  }) {
    _validate();
  }

  void _validate() {
    if (minStars < 0) {
      throw ArgumentError('minStars must be non-negative');
    }
    if (maxStars != null && maxStars! <= minStars) {
      throw ArgumentError('maxStars must be greater than minStars');
    }
    if (languages.isEmpty && topics.isEmpty) {
      throw ArgumentError('Either languages or topics must be specified');
    }
  }

  factory AppConfig.fromYaml(String yamlString) {
    final yaml = loadYaml(yamlString) as YamlMap;
    
    return AppConfig(
      languages: _toStringList(yaml['languages'] ?? ['all']),
      topics: _toStringList(yaml['topics'] ?? []),
      minStars: yaml['minStars'] ?? 10,
      maxStars: yaml['maxStars'],
      newOnly: yaml['newOnly'] ?? true,
      geminiModel: yaml['geminiModel'] ?? 'gemini-3-flash-preview',
      excludeRepos: _toStringList(yaml['excludeRepos'] ?? []),
    );
  }

  static Future<AppConfig> load(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return AppConfig(
        languages: ['all'],
        topics: ['ai', 'llm', 'mcp', 'rag', 'agents'],
        minStars: 10,
        newOnly: true,
      );
    }
    final content = await file.readAsString();
    return AppConfig.fromYaml(content);
  }

  static List<String> _toStringList(dynamic value) {
    if (value is YamlList) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}
