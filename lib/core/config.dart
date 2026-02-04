import 'dart:io';
import 'package:yaml/yaml.dart';

class AppConfig {
  final List<String> languages;
  final List<String> topics;
  final int minStars;
  final int? maxStars;
  final bool newOnly;
  final String geminiModel;
  final List<String> excludeRepos;

  AppConfig({
    required this.languages,
    required this.topics,
    required this.minStars,
    this.maxStars,
    required this.newOnly,
    this.geminiModel = 'gemini-3-flash-preview',
    this.excludeRepos = const [],
  });

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
