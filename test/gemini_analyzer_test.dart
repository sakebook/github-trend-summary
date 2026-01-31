import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:github_trend_summary/github_trend_summary.dart';

void main() {
  group('GeminiAnalyzer Tests', () {
    test('should analyze repository individually', () async {
      final mockClient = MockClient((request) async {
        final responseBody = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'summary': 'Summary 1',
                      'techStack': ['Dart'],
                      'useCase': 'Use Case 1',
                      'rivalComparison': 'Comparison 1',
                      'keyFeatures': ['Feature A', 'Feature B'],
                      'maturity': 'Stable'
                    })
                  }
                ]
              }
            }
          ]
        };
        return http.Response(jsonEncode(responseBody), 200);
      });

      final analyzer = GeminiAnalyzer(apiKey: 'fake-key', client: mockClient);
      final repo = (
          name: 'repo1',
          owner: 'owner1',
          description: 'desc1',
          stars: 10,
          url: 'url1',
          language: 'Dart',
          readmeContent: 'README Content'
        );

      final result = await analyzer.analyze(repo);

      expect(result, isA<Success<JapaneseSummary, Exception>>());
      final summary = (result as Success<JapaneseSummary, Exception>).value;
      
      expect(summary.repository.name, 'repo1');
      expect(summary.summary, 'Summary 1');
      expect(summary.useCase, 'Use Case 1');
      expect(summary.rivalComparison, 'Comparison 1');
      expect(summary.keyFeatures, contains('Feature A'));
      expect(summary.maturity, 'Stable');
    });

    test('should analyze batch by calling analyze individually', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        final responseBody = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'summary': 'Summary $requestCount',
                      'techStack': ['Dart'],
                      'useCase': 'Use Case $requestCount',
                      'rivalComparison': 'Comparison $requestCount',
                      'keyFeatures': ['Feature $requestCount'],
                      'maturity': 'Experimental'
                    })
                  }
                ]
              }
            }
          ]
        };
        return http.Response(jsonEncode(responseBody), 200);
      });

      final analyzer = GeminiAnalyzer(apiKey: 'fake-key', client: mockClient);
      final repos = [
        (
          name: 'repo1',
          owner: 'owner1',
          description: 'desc1',
          stars: 10,
          url: 'url1',
          language: 'Dart',
          readmeContent: null
        ),
        (
          name: 'repo2',
          owner: 'owner2',
          description: 'desc2',
          stars: 20,
          url: 'url2',
          language: 'TypeScript',
          readmeContent: null
        ),
      ];

      final result = await analyzer.analyzeBatch(repos);

      expect(result, isA<Success<List<JapaneseSummary>, Exception>>());
      final summaries = (result as Success<List<JapaneseSummary>, Exception>).value;
      
      expect(summaries.length, 2);
      expect(requestCount, 2);
      
      expect(summaries[0].summary, 'Summary 1');
      expect(summaries[1].summary, 'Summary 2');
    });

    test('should retry on 429 transient error', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response('Rate limit exceeded', 429);
        }
        final responseBody = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'summary': 'Retry Success',
                      'techStack': ['Dart'],
                      'useCase': 'Retry Use Case',
                      'rivalComparison': 'Retry Comparison',
                      'keyFeatures': ['Retry Feature'],
                      'maturity': 'Retry Maturity'
                    })
                  }
                ]
              }
            }
          ]
        };
        return http.Response(jsonEncode(responseBody), 200);
      });

      final analyzer = GeminiAnalyzer(apiKey: 'fake-key', client: mockClient);
      final repo = (
          name: 'repo1',
          owner: 'owner1',
          description: 'desc1',
          stars: 10,
          url: 'url1',
          language: 'Dart',
          readmeContent: null
        );

      final result = await analyzer.analyze(repo);

      expect(result, isA<Success<JapaneseSummary, Exception>>());
      final summary = (result as Success<JapaneseSummary, Exception>).value;
      expect(summary.summary, 'Retry Success');
      expect(requestCount, 2);
    });
  });
}
