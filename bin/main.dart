import 'dart:io';
import 'package:args/args.dart';
import 'package:github_trend_summary/github_trend_summary.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('lang',
        abbr: 'l',
        help: 'Target programming language (e.g. dart, typescript, all)',
        defaultsTo: 'all')
    ..addOption('min-stars',
        help: 'Minimum star count (defaults to 50 for "all", 10 for specific language)')
    ..addOption('max-stars',
        help: 'Maximum star count to exclude giant projects (e.g. 50000)')
    ..addFlag('new-only',
        help: 'Fetch only repositories created within the last 7 days',
        negatable: false)
    ..addOption('github-token', help: 'GitHub Personal Access Token')
    ..addOption('gemini-key', help: 'Gemini API Key', mandatory: true)
    ..addOption('output', abbr: 'o', help: 'Output markdown file path')
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show usage information');

  ArgResults results;
  try {
    results = parser.parse(arguments);
  } catch (e) {
    print('Error parsing arguments: $e');
    print(parser.usage);
    exit(1);
  }

  if (results['help'] as bool) {
    print('GitHub Trending Intelligence CLI');
    print(parser.usage);
    return;
  }

  final language = results['lang'] as String;
  final githubToken = results['github-token'] as String?;
  final geminiKey = results['gemini-key'] as String;
  final outputPath = results['output'] as String?;
  final minStarsStr = results['min-stars'] as String?;
  final minStars = minStarsStr != null ? int.tryParse(minStarsStr) : null;
  final maxStarsStr = results['max-stars'] as String?;
  final maxStars = maxStarsStr != null ? int.tryParse(maxStarsStr) : null;
  final newOnly = results['new-only'] as bool;

  print('🔍 Fetching trending $language repositories from GitHub...');
  final fetcher = GitHubFetcher(apiToken: githubToken);
  final fetchResult = await fetcher.fetchTrending(
    language,
    minStars: minStars,
    maxStars: maxStars,
    newOnly: newOnly,
  );

  final List<Repository> repositories;
  switch (fetchResult) {
    case Success(value: final r):
      repositories = r;
    case Failure(error: final e):
      print('❌ Failed to fetch repositories: $e');
      exit(1);
  }

  print('🤖 Analyzing ${repositories.length} repositories with Gemini...');
  final analyzer = GeminiAnalyzer(apiKey: geminiKey);
  final summaries = <JapaneseSummary>[];

  for (final repo in repositories) {
    print('  - Analyzing ${repo.owner}/${repo.name}...');
    final analyzeResult = await analyzer.analyze(repo);
    switch (analyzeResult) {
      case Success(value: final s):
        summaries.add(s);
      case Failure(error: final e):
        print('    ⚠️ Failed to analyze ${repo.name}: $e');
    }
  }

  if (summaries.isEmpty) {
    print('❌ No summaries were generated. Exiting.');
    exit(1);
  }

  final publishers = <Publisher>[
    ConsolePublisher(),
    if (outputPath != null) MarkdownFilePublisher(outputPath: outputPath),
  ];

  print('\n📢 Publishing results...');
  for (final publisher in publishers) {
    final publishResult = await publisher.publish(summaries);
    if (publishResult is Failure) {
      print('❌ Failed to publish with ${publisher.runtimeType}: ${(publishResult as Failure).error}');
      exit(1);
    }
  }

  print('✅ Done!');
}
