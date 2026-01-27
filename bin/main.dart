import 'dart:io';
import 'package:args/args.dart';
import 'package:github_trend_summary/github_trend_summary.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('lang',
        abbr: 'l',
        help: 'Target programming languages (comma separated, e.g. dart,typescript,all)',
        defaultsTo: 'all')
    ..addOption('topic',
        abbr: 't',
        help: 'Target topics (comma separated, e.g. ai,llm,flutter)')
    ..addOption('min-stars',
        help: 'Minimum star count (defaults to 50 for "all", 10 for specific language/topic)')
    ..addOption('max-stars',
        help: 'Maximum star count to exclude giant projects (e.g. 50000)')
    ..addFlag('new-only',
        help: 'Fetch only repositories created within the last 7 days',
        negatable: false)
    ..addOption('github-token', help: 'GitHub Personal Access Token')
    ..addOption('gemini-key', help: 'Gemini API Key', mandatory: true)
    ..addOption('output', abbr: 'o', help: 'Output markdown file path')
    ..addOption('rss', help: 'Output RSS file path')
    ..addOption('html', help: 'Output HTML file path')
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

  final languages = (results['lang'] as String).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  final topics = (results['topic'] as String?)?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() ?? [];
  final githubToken = results['github-token'] as String?;
  final geminiKey = results['gemini-key'] as String;
  final outputPath = results['output'] as String?;
  final rssPath = results['rss'] as String?;
  final htmlPath = results['html'] as String?;
  final minStarsStr = results['min-stars'] as String?;
  final minStars = minStarsStr != null ? int.tryParse(minStarsStr) : null;
  final maxStarsStr = results['max-stars'] as String?;
  final maxStars = maxStarsStr != null ? int.tryParse(maxStarsStr) : null;
  final newOnly = results['new-only'] as bool;

  final fetcher = GitHubFetcher(apiToken: githubToken);
  final analyzer = GeminiAnalyzer(apiKey: geminiKey);
  final allSummaries = <JapaneseSummary>[];

  // Fetch and Analyze for each language
  for (final lang in languages) {
    print('🔍 Fetching trending $lang repositories...');
    final fetchResult = await fetcher.fetchTrending(
      lang,
      minStars: minStars,
      maxStars: maxStars,
      newOnly: newOnly,
      isTopic: false,
    );
    await _processFetchResult(fetchResult, analyzer, allSummaries);
  }

  // Fetch and Analyze for each topic
  for (final topic in topics) {
    print('🔍 Fetching trending topic:$topic repositories...');
    final fetchResult = await fetcher.fetchTrending(
      topic,
      minStars: minStars,
      maxStars: maxStars,
      newOnly: newOnly,
      isTopic: true,
    );
    await _processFetchResult(fetchResult, analyzer, allSummaries);
  }

  if (allSummaries.isEmpty) {
    print('❌ No summaries were generated. Exiting.');
    exit(1);
  }

  final publishers = <Publisher>[
    ConsolePublisher(),
    if (outputPath != null) MarkdownFilePublisher(outputPath: outputPath),
    if (rssPath != null) RssPublisher(outputPath: rssPath),
    if (htmlPath != null) HtmlPublisher(outputPath: htmlPath),
  ];

  print('\n📢 Publishing results...');
  for (final publisher in publishers) {
    final publishResult = await publisher.publish(allSummaries);
    if (publishResult is Failure) {
      print('❌ Failed to publish with ${publisher.runtimeType}: ${(publishResult as Failure).error}');
      exit(1);
    }
  }

  print('✅ Done!');
}

Future<void> _processFetchResult(
  Result<List<Repository>, Exception> fetchResult,
  TrendAnalyzer analyzer,
  List<JapaneseSummary> allSummaries,
) async {
  final List<Repository> repositories;
  switch (fetchResult) {
    case Success(value: final r):
      repositories = r;
    case Failure(error: final e):
      print('❌ Failed to fetch: $e');
      return;
  }

  print('🤖 Analyzing ${repositories.length} repositories...');
  for (final repo in repositories) {
    // すでに取得済みのリポジトリ（他言語/トピックと被る場合）はスキップ
    if (allSummaries.any((s) => s.repository.url == repo.url)) {
      continue;
    }
    
    print('  - Analyzing ${repo.owner}/${repo.name}...');
    final analyzeResult = await analyzer.analyze(repo);
    // 連投による 429 を防ぐために少し待つ
    await Future.delayed(const Duration(milliseconds: 500));
    switch (analyzeResult) {
      case Success(value: final s):
        allSummaries.add(s);
      case Failure(error: final e):
        print('    ⚠️ Failed to analyze ${repo.name}: $e');
    }
  }
}
