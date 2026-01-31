import 'dart:io';
import 'package:args/args.dart';
import 'package:xml/xml.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('target', defaultsTo: 'public/rss.xml', help: 'Path to the input RSS file')
    ..addOption('before', help: 'Remove items published strictly BEFORE this date (YYYY-MM-DD)')
    ..addOption('date', help: 'Remove items published ON this date (YYYY-MM-DD)')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage information');

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      print('Usage: dart bin/cleanup_rss.dart [options]');
      print(parser.usage);
      exit(0);
    }

    final targetPath = results['target'] as String;
    final file = File(targetPath);
    if (!file.existsSync()) {
      print('Error: Target file not found: $targetPath');
      exit(1);
    }

    final document = XmlDocument.parse(file.readAsStringSync());
    final channel = document.findAllElements('channel').first;
    final items = channel.findElements('item').toList();
    
    DateTime? beforeDate;
    if (results['before'] != null) {
      String dateStr = results['before'] as String;
      if (!dateStr.endsWith('Z')) dateStr += 'T00:00:00Z';
      beforeDate = DateTime.parse(dateStr).toUtc();
    }

    DateTime? targetDate;
    if (results['date'] != null) {
      String dateStr = results['date'] as String;
      if (!dateStr.endsWith('Z')) dateStr += 'T00:00:00Z';
      targetDate = DateTime.parse(dateStr).toUtc();
    }

    if (beforeDate == null && targetDate == null) {
      print('Error: You must specify either --before or --date');
      print(parser.usage);
      exit(1);
    }

    int removedCount = 0;
    // Iterate in reverse to safely remove
    for (final item in items) {
      final pubDateElement = item.findElements('pubDate').firstOrNull;
      if (pubDateElement == null) continue;

      try {
        final pubDateStr = pubDateElement.innerText;
        final pubDate = _parseRfc822(pubDateStr).toUtc();
        
        bool shouldRemove = false;

        if (beforeDate != null) {
           // strictly before: pubDate < beforeDate
           if (pubDate.isBefore(beforeDate)) {
             shouldRemove = true;
           }
        }

        if (targetDate != null) {
          // On exact date: same year, month, day
          if (pubDate.year == targetDate.year && 
              pubDate.month == targetDate.month && 
              pubDate.day == targetDate.day) {
            shouldRemove = true;
          }
        }

        if (shouldRemove) {
          // Remove from parent
          item.parent?.children.remove(item);
          removedCount++;
        }
      } catch (e) {
        print('Warning: Failed to parse date for item "${item.findElements('title').firstOrNull?.innerText}": $e');
      }
    }

    if (removedCount > 0) {
      file.writeAsStringSync(document.toXmlString(pretty: true)); // Re-save
      print('Successfully removed $removedCount items.');
    } else {
      print('No items matched the criteria.');
    }

  } catch (e) {
    print('Error: $e');
    print(parser.usage);
    exit(1);
  }
}

DateTime _parseRfc822(String rfc822) {
  // Simplified parsing logic reused from rss_publisher.dart concept
  // RFC822 format: Wed, 28 Jan 2026 00:33:27 +0000
  final parts = rfc822.split(' ');
  // Basic validation/fallback could be added here
  
  // Use HttDate parser or manual mapping. 
  // Since we are in a script, let's duplicate the robust parsing logic or use HttpDate if available (dart:io has HttpDate but it expects slightly different format sometimes).
  // Let's stick to the manual logic from rss_publisher for consistency.
  
  final day = int.parse(parts[1]);
  final months = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12};
  final month = months[parts[2]] ?? 1;
  final year = int.parse(parts[3]);
  final timeParts = parts[4].split(':');
  final hour = int.parse(timeParts[0]);
  final minute = int.parse(timeParts[1]);
  final second = int.parse(timeParts[2]);

  // Adjust for offset if necessary, but assuming +0000 as per generator
  return DateTime.utc(year, month, day, hour, minute, second);
}
