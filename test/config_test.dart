import 'package:test/test.dart';
import 'package:github_trend_summary/core/config.dart';

void main() {
  group('AppConfig Validation Tests', () {
    test('should accept valid config', () {
      expect(() => AppConfig(
        languages: ['dart'],
        topics: [],
        minStars: 10,
        newOnly: true,
      ), returnsNormally);
    });

    test('should throw error when minStars is negative', () {
      expect(() => AppConfig(
        languages: ['dart'],
        topics: [],
        minStars: -1,
        newOnly: true,
      ), throwsArgumentError);
    });

    test('should throw error when maxStars is less than minStars', () {
      expect(() => AppConfig(
        languages: ['dart'],
        topics: [],
        minStars: 100,
        maxStars: 50,
        newOnly: true,
      ), throwsArgumentError);
    });

    test('should throw error when both languages and topics are empty', () {
      expect(() => AppConfig(
        languages: [],
        topics: [],
        minStars: 10,
        newOnly: true,
      ), throwsArgumentError);
    });
  });
}
