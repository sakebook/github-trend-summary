import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../core/interfaces.dart';
import '../core/models.dart';
import '../core/result.dart';

class RssPublisher implements Publisher {
  final String outputPath;
  final String? historyUrl;
  final http.Client _client;

  RssPublisher({
    required this.outputPath,
    this.historyUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _sanitizeCdata(String text) {
    return text.replaceAll(']]>', ']]]]><![CDATA[>');
  }

  @override
  Future<Result<void, Exception>> publish(List<JapaneseSummary> summaries) async {
    try {
      final now = DateTime.now().toUtc();
      final items = <String>[];
      final newUrls = summaries.map((s) => s.repository.url).toSet();

      // 1. 今回の新しいアイテムを作成
      for (final s in summaries) {
        items.add(_buildItemXml(s, now));
      }

      // 2. 既存のRSSがある場合は取得してマージ
      if (historyUrl != null) {
        final existingItems = await _fetchAndFilterExistingItems(now, excludeUrls: newUrls);
        items.addAll(existingItems);
      }

      // 3. 全体構造の構築
      final buffer = StringBuffer();
      buffer.writeln('<?xml version="1.0" encoding="UTF-8" ?>');
      buffer.writeln('<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">');
      buffer.writeln('<channel>');
      buffer.writeln('  <title>GitHub Trending Intelligence</title>');
      buffer.writeln('  <link>https://github.com/trending</link>');
      buffer.writeln('  <description>Daily curated GitHub trends with Gemini analysis.</description>');
      buffer.writeln('  <language>ja</language>');
      buffer.writeln('  <lastBuildDate>${_toRfc822(now)}</lastBuildDate>');
      
      for (final item in items) {
        buffer.writeln(item);
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

  String _buildItemXml(JapaneseSummary s, DateTime date) {
    final repo = s.repository;
    final label = repo.language != null ? '[${repo.language}] ' : '';
    final buffer = StringBuffer();
    buffer.writeln('  <item>');
    buffer.writeln('    <title><![CDATA[${_sanitizeCdata("$label${repo.owner}/${repo.name}")}]]></title>');
    buffer.writeln('    <link>${_escapeXml(repo.url)}</link>');
    buffer.writeln('    <guid isPermaLink="true">${_escapeXml(repo.url)}</guid>');
    buffer.writeln('    <pubDate>${_toRfc822(date)}</pubDate>');
    buffer.writeln('    <description><![CDATA[');
    buffer.writeln('      <h3>概要</h3><p>${_sanitizeCdata(s.summary)}</p>');
    buffer.writeln('      <h3>背景</h3><p>${_sanitizeCdata(s.background)}</p>');
    buffer.writeln('      <h3>注目ポイント</h3><p>${_sanitizeCdata(s.whyHot)}</p>');
    buffer.writeln('      <h3>技術スタック</h3><p>${_sanitizeCdata(s.techStack.join(", "))}</p>');
    buffer.writeln('    ]]></description>');
    buffer.writeln('  </item>');
    return buffer.toString();
  }

  Future<List<String>> _fetchAndFilterExistingItems(DateTime now, {Set<String>? excludeUrls}) async {
    try {
      final response = await _client.get(Uri.parse(historyUrl!));
      if (response.statusCode != 200) return [];

      // Content-Type に charset が明示されている場合はそれを使い、
      // そうでない場合はデフォルトの ISO-8859-1 (Latin-1) ではなく UTF-8 を使う
      final contentType = response.headers['content-type'];
      final content = (contentType != null && contentType.contains('charset='))
          ? response.body
          : utf8.decode(response.bodyBytes);

      final document = XmlDocument.parse(content);
      final elements = document.findAllElements('item');
      final filteredItems = <String>[];

      for (final element in elements) {
        // 1. 重複チェック (guid または link)
        final guid = element.findElements('guid').firstOrNull?.innerText;
        final link = element.findElements('link').firstOrNull?.innerText;
        if (excludeUrls != null && (excludeUrls.contains(guid) || excludeUrls.contains(link))) {
          continue; // すでに今回の新着に含まれているのでスキップ
        }

        // 2. 期限チェック
        final pubDateStr = element.findElements('pubDate').firstOrNull?.innerText;
        if (pubDateStr != null) {
          try {
            final pubDate = _parseRfc822(pubDateStr);
            // 14日以上前のものは除外
            if (now.difference(pubDate).inDays < 14) {
              filteredItems.add('  ${element.toXmlString()}');
            }
          } catch (_) {
            // パース失敗時は安全のため残す
            filteredItems.add('  ${element.toXmlString()}');
          }
        } else {
          // pubDateがない場合も安全のため残す (PRフィードバック対応)
          filteredItems.add('  ${element.toXmlString()}');
        }
      }
      return filteredItems;
    } catch (e) {
      print('  ⚠️ Could not merge history from $historyUrl: $e');
      return [];
    }
  }

  DateTime _parseRfc822(String rfc822) {
    final parts = rfc822.split(' ');
    if (parts.length < 5) throw FormatException('Invalid RFC822 date');

    final day = int.parse(parts[1]);
    final months = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12};
    final month = months[parts[2]] ?? 1;
    final year = int.parse(parts[3]);
    final timeParts = parts[4].split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final second = int.parse(timeParts[2]);

    return DateTime.utc(year, month, day, hour, minute, second);
  }

  String _toRfc822(DateTime dt) {
    final utc = dt.toUtc();
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final dayName = days[utc.weekday % 7];
    final monthName = months[utc.month - 1];
    final date = utc.day.toString().padLeft(2, '0');
    final year = utc.year;
    final hour = utc.hour.toString().padLeft(2, '0');
    final min = utc.minute.toString().padLeft(2, '0');
    final sec = utc.second.toString().padLeft(2, '0');
    
    return '$dayName, $date $monthName $year $hour:$min:$sec +0000';
  }
}
