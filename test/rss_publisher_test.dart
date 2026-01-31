import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:github_trend_summary/github_trend_summary.dart';
import 'dart:io';

void main() {
  group('RssPublisher Merging Tests', () {
    const outputPath = 'test_output/rss_merge.xml';

    tearDown(() {
      final file = File(outputPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    test('should merge new items with existing ones and filter old ones', () async {
      final now = DateTime.now().toUtc();
      final oldDate = now.subtract(const Duration(days: 10));
      final veryOldDate = now.subtract(const Duration(days: 20));

      final existingRss = '''
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
  <item>
    <title>Old Repo</title>
    <link>https://github.com/old/repo</link>
    <pubDate>${_toRfc822(oldDate)}</pubDate>
  </item>
  <item>
    <title>Very Old Repo</title>
    <link>https://github.com/veryold/repo</link>
    <pubDate>${_toRfc822(veryOldDate)}</pubDate>
  </item>
</channel>
</rss>
''';

      final client = MockClient((request) async {
        return http.Response(existingRss, 200);
      });

      final publisher = RssPublisher(
        outputPath: outputPath,
        historyUrl: 'https://example.com/rss.xml',
        client: client,
      );

      final newSummary = JapaneseSummary(
        repository: (
          name: 'new-repo',
          owner: 'new-owner',
          url: 'https://github.com/new/repo',
          stars: 100,
          description: 'New Description',
          language: 'Dart',
          readmeContent: null
        ),
        summary: 'New Summary',
        useCase: 'New Background',
        keyFeatures: ['Feature 1'],
        maturity: 'Stable',
        techStack: ['Dart'],
        rivalComparison: 'New Why',
      );

      await publisher.publish([newSummary]);

      final outputContent = File(outputPath).readAsStringSync();
      
      expect(outputContent, contains('https://github.com/new/repo'));
      expect(outputContent, contains('https://github.com/old/repo'));
      expect(outputContent, isNot(contains('https://github.com/veryold/repo')));
    });

    test('should deduplicate when a new item is already in existing RSS', () async {
      final now = DateTime.now().toUtc();
      
      final existingRss = '''
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
  <item>
    <title>Existing Repo</title>
    <link>https://github.com/existing/repo</link>
    <pubDate>${_toRfc822(now)}</pubDate>
  </item>
</channel>
</rss>
''';

      final client = MockClient((request) async {
        return http.Response(existingRss, 200);
      });

      final publisher = RssPublisher(
        outputPath: outputPath,
        historyUrl: 'https://example.com/rss.xml',
        client: client,
      );

      final newSummary = JapaneseSummary(
        repository: (
          name: 'existing-repo',
          owner: 'existing-owner',
          url: 'https://github.com/existing/repo',
          stars: 100,
          description: 'New Description',
          language: 'Dart',
          readmeContent: null
        ),
        summary: 'New Summary',
        useCase: 'New Background',
        keyFeatures: ['Feature 1'],
        maturity: 'Stable',
        techStack: ['Dart'],
        rivalComparison: 'New Why',
      );

      await publisher.publish([newSummary]);

      final outputContent = File(outputPath).readAsStringSync();
      
      // Each item contains the URL twice (link and guid)
      final matches = RegExp('https://github.com/existing/repo').allMatches(outputContent);
      expect(matches.length, 2, reason: 'URL should appear exactly twice (link and guid of the NEW item)');
      expect(outputContent, contains('New Summary'), reason: 'New summary should be present');
      expect(outputContent, isNot(contains('Existing Repo')), reason: 'Old item title should be removed');
    });

    test('should preserve items without pubDate', () async {
      final now = DateTime.now().toUtc();
      
      final existingRss = '''
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
  <item>
    <title>No Date Repo</title>
    <link>https://github.com/nodate/repo</link>
  </item>
</channel>
</rss>
''';

      final client = MockClient((request) async {
        return http.Response(existingRss, 200);
      });

      final publisher = RssPublisher(
        outputPath: outputPath,
        historyUrl: 'https://example.com/rss.xml',
        client: client,
      );

      await publisher.publish([]);

      final outputContent = File(outputPath).readAsStringSync();
      expect(outputContent, contains('https://github.com/nodate/repo'));
    });

    test('should preserve Japanese characters during merge', () async {
      final now = DateTime.now().toUtc();
      const japaneseText = '注目ポイント';
      
      final existingRss = '''
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
  <item>
    <title>$japaneseText</title>
    <link>https://github.com/japanese/repo</link>
    <pubDate>${_toRfc822(now)}</pubDate>
  </item>
</channel>
</rss>
''';

      final client = MockClient((request) async {
        // http.Response.body assumes ISO-8859-1 if no charset is in Content-Type.
        // We simulate the actual bytes being UTF-8 encoded.
        return http.Response.bytes(
          utf8.encode(existingRss),
          200,
          headers: {'content-type': 'application/xml'}, // No charset specified
        );
      });

      final publisher = RssPublisher(
        outputPath: outputPath,
        historyUrl: 'https://example.com/rss.xml',
        client: client,
      );

      await publisher.publish([]);

      final outputContent = File(outputPath).readAsStringSync();
      expect(outputContent, contains(japaneseText));
    });

    test('should trust explicit non-UTF-8 charset from headers', () async {
      final now = DateTime.now().toUtc();
      // ISO-8859-1 (Latin-1) text. "©" is 0xA9 in Latin-1.
      const latinText = 'Copyright © 2026';
      
      final existingRss = '''
<?xml version="1.0" encoding="ISO-8859-1" ?>
<rss version="2.0">
<channel>
  <item>
    <title>$latinText</title>
    <link>https://github.com/latin/repo</link>
    <pubDate>${_toRfc822(now)}</pubDate>
  </item>
</channel>
</rss>
''';

      final client = MockClient((request) async {
        return http.Response.bytes(
          latin1.encode(existingRss),
          200,
          headers: {'content-type': 'application/xml; charset=iso-8859-1'},
        );
      });

      final publisher = RssPublisher(
        outputPath: outputPath,
        historyUrl: 'https://example.com/rss.xml',
        client: client,
      );

      await publisher.publish([]);

      final outputContent = File(outputPath).readAsStringSync();
      // Since File.readAsStringSync defaults to UTF-8, 
      // the output (which we write as default UTF-8) should contain the decoded "©".
      expect(outputContent, contains(latinText));
    });

    test('should handle uppercase Charset in Content-Type header', () async {
      final now = DateTime.now().toUtc();
      const latinText = 'Uppercase Charset © 2026';
      
      final existingRss = '''
<?xml version="1.0" encoding="ISO-8859-1" ?>
<rss version="2.0">
<channel>
  <item>
    <title>$latinText</title>
    <link>https://github.com/uppercase/repo</link>
    <pubDate>${_toRfc822(now)}</pubDate>
  </item>
</channel>
</rss>
''';

      final client = MockClient((request) async {
        return http.Response.bytes(
          latin1.encode(existingRss),
          200,
          headers: {'content-type': 'application/xml; Charset=ISO-8859-1'},
        );
      });

      final publisher = RssPublisher(
        outputPath: outputPath,
        historyUrl: 'https://example.com/rss.xml',
        client: client,
      );

      await publisher.publish([]);

      final outputContent = File(outputPath).readAsStringSync();
      expect(outputContent, contains(latinText));
    });
  });
}

String _toRfc822(DateTime dt) {
  final utc = dt.toUtc();
  final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${days[utc.weekday % 7]}, ${utc.day.toString().padLeft(2, '0')} ${months[utc.month - 1]} ${utc.year} ${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}:${utc.second.toString().padLeft(2, '0')} +0000';
}
