import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:github_trend_summary/github_trend_summary.dart';

void main() {
  group('GeminiAnalyzer Batch Tests', () {
    test('should analyze repositories in batch', () async {
      final mockClient = MockClient((request) async {
        final responseBody = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode([
                      {
                        'background': 'bg 1',
                        'techStack': ['dart'],
                        'whyHot': 'hot 1',
                        'summary': 'summary 1',
                      },
                      {
                        'background': 'bg 2',
                        'techStack': ['typescript'],
                        'whyHot': 'hot 2',
                        'summary': 'summary 2',
                      }
                    ])
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
          language: 'Dart'
        ),
        (
          name: 'repo2',
          owner: 'owner2',
          description: 'desc2',
          stars: 20,
          url: 'url2',
          language: 'TypeScript'
        ),
      ];

      final result = await analyzer.analyzeBatch(repos);

      expect(result is Success, isTrue);
      final summaries = (result as Success<List<JapaneseSummary>, Exception>).value;
      expect(summaries.length, 2);
      expect(summaries[0].repository.name, 'repo1');
      expect(summaries[0].summary, 'summary 1');
      expect(summaries[1].repository.name, 'repo2');
      expect(summaries[1].summary, 'summary 2');
    });

    test('should handle empty batch', () async {
      final analyzer = GeminiAnalyzer(apiKey: 'fake-key');
      final result = await analyzer.analyzeBatch([]);
      expect(result is Success, isTrue);
      expect((result as Success).value, isEmpty);
    });

    test('should retry on 429', () async {
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
                    'text': jsonEncode([
                      {
                        'background': 'bg 1',
                        'techStack': ['dart'],
                        'whyHot': 'hot 1',
                        'summary': 'summary 1',
                      }
                    ])
                  }
                ]
              }
            }
          ]
        };
        return http.Response(jsonEncode(responseBody), 200);
      });

      // Use a shorter delay for testing if possible, but currently it's hardcoded.
      // We can just wait for it.
      final analyzer = GeminiAnalyzer(apiKey: 'fake-key', client: mockClient);
      final repos = [
        (
          name: 'repo1',
          owner: 'owner1',
          description: 'desc1',
          stars: 10,
          url: 'url1',
          language: 'Dart'
        ),
      ];

      final result = await analyzer.analyzeBatch(repos);

      expect(result is Success, isTrue);
      expect(requestCount, 2);
    });
  });
}
