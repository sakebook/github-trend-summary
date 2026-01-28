import 'dart:io';
import 'package:http/http.dart' as http;

class HistoryManager {
  final http.Client _client;

  HistoryManager({http.Client? client}) : _client = client ?? http.Client();

  /// Extract GitHub repository URLs from a markdown, HTML, or RSS content.
  /// [source] can be a local file path or a URL starting with 'http'.
  Future<Set<String>> extractUrls(String source) async {
    String content = '';

    try {
      if (source.startsWith('http')) {
        final response = await _client.get(Uri.parse(source));
        if (response.statusCode == 200) {
          content = response.body;
        }
      } else {
        final file = File(source);
        if (file.existsSync()) {
          content = file.readAsStringSync();
        }
      }
    } catch (e) {
      // If history cannot be loaded, just return empty set and proceed
      print('  ⚠️ Could not load history from $source: $e');
      return {};
    }

    if (content.isEmpty) return {};

    // Match GitHub repository URLs like https://github.com/owner/repo
    // Uses a pattern that handles single-character names and prevents matching a trailing period
    final regex = RegExp(r'https://github\.com/[\w-]+/[\w-][\w.-]*(?<![.])');
    final matches = regex.allMatches(content);

    return matches.map((m) => m.group(0)!).toSet();
  }
}
