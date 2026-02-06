import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:github_trend_summary/github_trend_summary.dart';

void main() {
  group('GitHubFetcher Query Tests', () {
    test('should build correct query for a language', () async {
      var capturedUri = Uri();
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({'items': []}), 200);
      });

      final fetcher = GitHubFetcher(client: client);
      await fetcher.fetchTrending('dart');

      final q = capturedUri.queryParameters['q']!;
      expect(q, contains('pushed:>='));
      expect(q, contains('language:dart'));
      expect(q, contains('stars:20..10000'));
      expect(q, contains('fork:false'));
    });

    test('should build correct query for a topic', () async {
      var capturedUri = Uri();
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({'items': []}), 200);
      });

      final fetcher = GitHubFetcher(client: client);
      await fetcher.fetchTrending('ai', isTopic: true);

      final q = capturedUri.queryParameters['q']!;
      expect(q, contains('topic:ai'));
      expect(q, contains('pushed:>='));
      expect(q, contains('stars:20..10000'));
    });

    test('should build correct query for "all" language', () async {
      var capturedUri = Uri();
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({'items': []}), 200);
      });

      final fetcher = GitHubFetcher(client: client);
      await fetcher.fetchTrending('all');

      final q = capturedUri.queryParameters['q']!;
      expect(q, isNot(contains('language:')));
      expect(q, contains('pushed:>='));
      expect(q, contains('stars:50..10000'));
    });

    test('should build correct query for new-only', () async {
      var capturedUri = Uri();
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({'items': []}), 200);
      });

      final fetcher = GitHubFetcher(client: client);
      await fetcher.fetchTrending('dart', newOnly: true);

      final q = capturedUri.queryParameters['q']!;
      expect(q, contains('created:>='));
    });
  });

  group('GitHubFetcher Metadata Tests', () {
    test('should fetch correct metadata file for Dart', () async {
      var capturedUri = Uri();
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({'content': base64Encode(utf8.encode('name: test_project'))}), 200);
      });

      final fetcher = GitHubFetcher(client: client);
      final repo = (
        name: 'test',
        owner: 'owner',
        url: 'url',
        stars: 1,
        language: 'Dart',
        description: null,
        readmeContent: null,
        metadataContent: null,
      );

      await fetcher.fetchMetadata(repo);

      expect(capturedUri.path, contains('pubspec.yaml'));
    });

    test('should fetch correct metadata file for TypeScript', () async {
      var capturedUri = Uri();
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({'content': base64Encode(utf8.encode('{"name": "test"}'))}), 200);
      });

      final fetcher = GitHubFetcher(client: client);
      final repo = (
        name: 'test',
        owner: 'owner',
        url: 'url',
        stars: 1,
        language: 'TypeScript',
        description: null,
        readmeContent: null,
        metadataContent: null,
      );

      await fetcher.fetchMetadata(repo);

      expect(capturedUri.path, contains('package.json'));
    });

    test('should return null for unknown language metadata', () async {
      final fetcher = GitHubFetcher();
      final repo = (
        name: 'test',
        owner: 'owner',
        url: 'url',
        stars: 1,
        language: 'UnknownLang',
        description: null,
        readmeContent: null,
        metadataContent: null,
      );

      final result = await fetcher.fetchMetadata(repo);
      expect(result, isNull);
    });
  });
}
