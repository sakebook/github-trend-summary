import 'dart:io';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

// We will test the logic by creating a temporary RSS file and running the script logic (or invoking it via process)
// Invoking via Process is better for integration testing the CLI args.

void main() {
  group('RSS Cleanup Script Tests', () {
    late Directory tempDir;
    late File rssFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rss_cleanup_test');
      rssFile = File('${tempDir.path}/test_rss.xml');
      final content = '''
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
  <item>
    <title>Item 1 (Old)</title>
    <pubDate>Wed, 28 Jan 2026 23:59:59 +0000</pubDate> 
  </item>
  <item>
    <title>Item 2 (Target Date Start)</title>
    <pubDate>Thu, 29 Jan 2026 00:00:00 +0000</pubDate>
  </item>
  <item>
    <title>Item 3 (Target Date Mid)</title>
    <pubDate>Thu, 29 Jan 2026 12:00:00 +0000</pubDate>
  </item>
  <item>
    <title>Item 4 (Next Day)</title>
    <pubDate>Fri, 30 Jan 2026 00:00:01 +0000</pubDate>
  </item>
</channel>
</rss>
''';
      await rssFile.writeAsString(content);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('Removes items strictly BEFORE 2026-01-29', () async {
      // 2026-01-29 means 2026-01-29 00:00:00 UTC.
      // Item 1 (Jan 28 23:59:59) should be removed.
      // Item 2 (Jan 29 00:00:00) should remain.
      
      final result = await Process.run('dart', [
        'bin/cleanup_rss.dart',
        '--target', rssFile.path,
        '--before', '2026-01-29'
      ]);

      expect(result.exitCode, 0);
      
      final content = await rssFile.readAsString();
      final doc = XmlDocument.parse(content);
      final titles = doc.findAllElements('title').map((e) => e.innerText).toList();

      expect(titles, contains('Item 2 (Target Date Start)'));
      expect(titles, contains('Item 3 (Target Date Mid)'));
      expect(titles, contains('Item 4 (Next Day)'));
      expect(titles, isNot(contains('Item 1 (Old)')));
    });

    test('Removes items ON 2026-01-29', () async {
      // Should remove Item 2 and Item 3.
      
      final result = await Process.run('dart', [
        'bin/cleanup_rss.dart',
        '--target', rssFile.path,
        '--date', '2026-01-29'
      ]);

      expect(result.exitCode, 0, reason: result.stderr);
      
      final content = await rssFile.readAsString();
      final doc = XmlDocument.parse(content);
      final titles = doc.findAllElements('title').map((e) => e.innerText).toList();

      expect(titles, contains('Item 1 (Old)'));
      expect(titles, contains('Item 4 (Next Day)'));
      expect(titles, isNot(contains('Item 2 (Target Date Start)')));
      expect(titles, isNot(contains('Item 3 (Target Date Mid)')));
    });
  });
}
