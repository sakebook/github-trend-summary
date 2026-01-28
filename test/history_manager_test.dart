import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:github_trend_summary/core/history_manager.dart';
import 'dart:io';

void main() {
  group('HistoryManager Tests', () {
    test('should extract URLs from local file', () async {
      final tempFile = File('test_history.md');
      tempFile.writeAsStringSync('Check this: https://github.com/owner/repo1 and https://github.com/owner/repo2.');
      
      final manager = HistoryManager();
      final urls = await manager.extractUrls('test_history.md');
      
      expect(urls, contains('https://github.com/owner/repo1'));
      expect(urls, contains('https://github.com/owner/repo2'));
      expect(urls.length, 2);
      
      tempFile.deleteSync();
    });

    test('should extract URLs from remote URL', () async {
      final client = MockClient((request) async {
        return http.Response('RSS Content: https://github.com/remote/repo', 200);
      });
      
      final manager = HistoryManager(client: client);
      final urls = await manager.extractUrls('https://example.com/rss.xml');
      
      expect(urls, contains('https://github.com/remote/repo'));
      expect(urls.length, 1);
    });

    test('should handle 404 or errors gracefully', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });
      
      final manager = HistoryManager(client: client);
      final urls = await manager.extractUrls('https://example.com/missing.xml');
      
      expect(urls, isEmpty);
    });

    test('should handle non-existent local file gracefully', () async {
      final manager = HistoryManager();
      final urls = await manager.extractUrls('non_existent_file.txt');
      
      expect(urls, isEmpty);
    });
  });
}
