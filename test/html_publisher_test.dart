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
            readmeContent: null,
            metadataContent: null,
          ),
          summary: 'テスト概要',
          useCase: 'テスト活用シーン',
          keyFeatures: ['機能1', '機能2'],
          maturity: 'Experimental',
          techStack: ['React', 'Node.js'],
          rivalComparison: 'テスト競合比較',
          implementationFlavor: 'テスト実装のこだわり',
        ),
      ];

      final result = await publisher.publish(summaries);

      expect(result is Success, isTrue);
      final file = File(testPath);
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('<!DOCTYPE html>'));
      expect(content, contains('<html lang="ja">'));
      expect(content, contains('class="repo-name"'));
      expect(content, contains('test-repo'));
      expect(content, contains('⭐ 123'));
      expect(content, contains('<span class="tech-tag">React</span>'));
    });

    test('should escape HTML special characters', () async {
      final Repository repo = (
        name: '<b>script</b>',
        owner: 'owner',
        description: '<script>alert(1)</script>',
        stars: 100,
        url: 'https://github.com/owner/repo',
        language: 'Dart',
        readmeContent: null,
        metadataContent: null,
      );

      final summary = JapaneseSummary(
        repository: repo,
        summary: 'summary & "quote"',
        useCase: 'useCase < >',
        keyFeatures: ['<feature>'],
        maturity: 'maturity &',
        techStack: ['<tag>'],
        rivalComparison: 'rivalComparison &',
        implementationFlavor: 'flavor &',
      );

      final tempDir = Directory.systemTemp.createTempSync();
      final tempPath = '${tempDir.path}/index.html';
      final publisher = HtmlPublisher(outputPath: tempPath);

      await publisher.publish([summary]);

      final html = File(tempPath).readAsStringSync();
      // Verify escaped content
      expect(html, contains('&lt;b&gt;script&lt;/b&gt;'));
      expect(html, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));
      expect(html, contains('summary &amp; &quot;quote&quot;'));
      expect(html, contains('useCase &lt; &gt;'));
      expect(html, contains('maturity &amp;'));
      expect(html, contains('&lt;tag&gt;'));
      // Verify NOT containing raw scripts
      expect(html, isNot(contains('<script>')));
      tempDir.deleteSync(recursive: true); // Clean up the temporary directory
    });
  });
}
