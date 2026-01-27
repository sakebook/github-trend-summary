import 'dart:io';
import '../core/interfaces.dart';
import '../core/models.dart';
import '../core/result.dart';

class RssPublisher implements Publisher {
  final String outputPath;

  RssPublisher({required this.outputPath});

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  @override
  Future<Result<void, Exception>> publish(List<JapaneseSummary> summaries) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('<?xml version="1.0" encoding="UTF-8" ?>');
      buffer.writeln('<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">');
      buffer.writeln('<channel>');
      buffer.writeln('  <title>GitHub Trending Intelligence</title>');
      buffer.writeln('  <link>https://github.com/trending</link>');
      buffer.writeln('  <description>Daily curated GitHub trends with Gemini analysis.</description>');
      buffer.writeln('  <language>ja</language>');
      buffer.writeln('  <lastBuildDate>${_toRfc822(DateTime.now())}</lastBuildDate>');

      for (final s in summaries) {
        final repo = s.repository;
        final label = repo.language != null ? '[${repo.language}] ' : '';
        
        buffer.writeln('  <item>');
        buffer.writeln('    <title><![CDATA[$label${repo.owner}/${repo.name}]]></title>');
        buffer.writeln('    <link>${_escapeXml(repo.url)}</link>');
        buffer.writeln('    <guid isPermaLink="true">${_escapeXml(repo.url)}</guid>');
        buffer.writeln('    <pubDate>${_toRfc822(DateTime.now())}</pubDate>'); // 本来は取得日
        buffer.writeln('    <description><![CDATA[');
        buffer.writeln('      <h3>概要</h3><p>${s.summary}</p>');
        buffer.writeln('      <h3>背景</h3><p>${s.background}</p>');
        buffer.writeln('      <h3>注目ポイント</h3><p>${s.whyHot}</p>');
        buffer.writeln('      <h3>技術スタック</h3><p>${s.techStack.join(", ")}</p>');
        buffer.writeln('    ]]></description>');
        buffer.writeln('  </item>');
      }

      buffer.writeln('</channel>');
      buffer.writeln('</rss>');

      final file = File(outputPath);
      final parent = file.parent;
      if (!parent.existsSync()) {
        await parent.create(recursive: true);
      }
      await file.writeAsString(buffer.toString());
      return Success(null);
    } catch (e) {
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }

  String _toRfc822(DateTime dt) {
    // Convert to UTC to ensure +0000 is accurate
    final utc = dt.toUtc();
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final day = days[utc.weekday % 7];
    final month = months[utc.month - 1];
    final date = utc.day.toString().padLeft(2, '0');
    final year = utc.year;
    final hour = utc.hour.toString().padLeft(2, '0');
    final min = utc.minute.toString().padLeft(2, '0');
    final sec = utc.second.toString().padLeft(2, '0');
    
    return '$day, $date $month $year $hour:$min:$sec +0000';
  }
}
