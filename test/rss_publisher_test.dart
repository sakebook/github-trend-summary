import 'dart:io';
import 'package:test/test.dart';
import 'package:github_trend_summary/github_trend_summary.dart';

void main() {
  group('RssPublisher Tests', () {
    const testPath = 'test_output.xml';

    tearDown(() {
      final file = File(testPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    test('should generate a valid RSS 2.0 file', () async {
      final publisher = RssPublisher(outputPath: testPath);
      final summaries = [
        JapaneseSummary(
          repository: (
            name: 'test-repo',
            owner: 'test-owner',
            description: 'Test Description',
            url: 'https://github.com/test/repo',
            stars: 100,
            language: 'Dart',
          ),
          summary: 'テスト概要',
          background: 'テスト背景',
          techStack: ['Dart', 'Flutter'],
          whyHot: 'テスト注目ポイント',
        ),
      ];

      final result = await publisher.publish(summaries);

      expect(result is Success, isTrue);
      final file = File(testPath);
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('<?xml version="1.0" encoding="UTF-8" ?>'));
      expect(content, contains('<rss version="2.0"'));
      expect(content, contains('<title><![CDATA[[Dart] test-owner/test-repo]]></title>'));
      expect(content, contains('<link>https://github.com/test/repo</link>'));
      expect(content, contains('テスト概要'));
    });

    test('should sanitize CDATA closing sequence', () async {
      final publisher = RssPublisher(outputPath: testPath);
      final summaries = [
        JapaneseSummary(
          repository: (
            name: 'test-repo',
            owner: 'test-owner',
            description: 'Test Description',
            url: 'https://github.com/test/repo',
            stars: 123,
            language: 'TypeScript',
          ),
          summary: 'End sequence ]]> test',
          background: 'bg',
          techStack: ['dart'],
          whyHot: 'hot',
        ),
      ];

      await publisher.publish(summaries);

      final content = File(testPath).readAsStringSync();
      expect(content, contains('End sequence ]]]]><![CDATA[> test'));
    });
  });
}
