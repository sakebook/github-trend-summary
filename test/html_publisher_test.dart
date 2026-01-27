import 'dart:io';
import 'package:test/test.dart';
import 'package:github_trend_summary/github_trend_summary.dart';

void main() {
  group('HtmlPublisher Tests', () {
    const testPath = 'test_output.html';

    tearDown(() {
      final file = File(testPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    test('should generate a valid HTML file', () async {
      final publisher = HtmlPublisher(outputPath: testPath);
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
          summary: 'テスト概要',
          background: 'テスト背景',
          techStack: ['React', 'Node.js'],
          whyHot: 'テスト注目ポイント',
        ),
      ];

      final result = await publisher.publish(summaries);

      expect(result is Success, isTrue);
      final file = File(testPath);
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('<!DOCTYPE html>'));
      expect(content, contains('<html lang="ja">'));
      expect(content, contains('test-owner / test-repo'));
      expect(content, contains('★ 123'));
      expect(content, contains('<span class="tech-tag">React</span>'));
    });
  });
}
