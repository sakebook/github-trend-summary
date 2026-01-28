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
        help: 'Fetch only repositories created within the last 14 days',
        negatable: false)
    ..addOption('github-token', help: 'GitHub Personal Access Token')
    ..addOption('gemini-key', help: 'Gemini API Key', mandatory: true)
    ..addOption('output', abbr: 'o', help: 'Output markdown file path')
    ..addOption('rss', help: 'Output RSS file path')
    ..addOption('html', help: 'Output HTML file path')
    ..addOption('history-url', help: 'URL to the existing RSS feed to avoid duplicates')
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
  final historyUrl = results['history-url'] as String?;

  final fetcher = GitHubFetcher(apiToken: githubToken);
  final analyzer = GeminiAnalyzer(apiKey: geminiKey);
  final allSummaries = <JapaneseSummary>[];

  // 既読リポジトリの読み込み
  final historyManager = HistoryManager();
  final seenUrls = <String>{};
  if (outputPath != null) {
    seenUrls.addAll(await historyManager.extractUrls(outputPath));
  }
  if (htmlPath != null) {
    seenUrls.addAll(await historyManager.extractUrls(htmlPath));
  }
  if (historyUrl != null) {
    seenUrls.addAll(await historyManager.extractUrls(historyUrl));
  }

  if (seenUrls.isNotEmpty) {
    print('📚 Loaded ${seenUrls.length} previously reported repositories.');
  }

  // Fetch and Analyze for each language
  if (languages.isEmpty && topics.isEmpty) {
    languages.add('all');
  }

  for (final lang in languages) {
    print('🔍 Fetching trending $lang repositories...');
    final fetchResult = await fetcher.fetchTrending(
      lang,
      minStars: minStars,
      maxStars: maxStars,
      newOnly: newOnly,
      isTopic: false,
    );
    await _processFetchResult(fetchResult, analyzer, allSummaries, seenUrls);
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
    await _processFetchResult(fetchResult, analyzer, allSummaries, seenUrls);
  }

  if (allSummaries.isEmpty) {
    print('❌ No summaries were generated. Exiting.');
    exit(1);
  }

  final publishers = <Publisher>[
    ConsolePublisher(),
    if (outputPath != null) MarkdownFilePublisher(outputPath: outputPath),
    if (rssPath != null) RssPublisher(outputPath: rssPath, historyUrl: historyUrl),
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
  Set<String> seenUrls,
) async {
  final List<Repository> fetchedRepositories;
  switch (fetchResult) {
    case Success(value: final r):
      fetchedRepositories = r;
    case Failure(error: final e):
      print('❌ Failed to fetch: $e');
      return;
  }

  // 1. 今回の実行ですでに取得済みのものを除外
  // 2. 過去のレポートに掲載済みのものを除外（既読スキップ）
  final unreadRepositories = fetchedRepositories
      .where((repo) =>
          !allSummaries.any((s) => s.repository.url == repo.url) &&
          !seenUrls.contains(repo.url))
      .toList();

  // 未読が足りない場合は、既読リポジトリから今回の実行で未取得のものを補填する
  final List<Repository> repositoriesToAnalyze;
  if (unreadRepositories.length >= 5) {
    unreadRepositories.shuffle();
    repositoriesToAnalyze = unreadRepositories.take(5).toList();
    print('  - Found ${unreadRepositories.length} unread repositories. Picking 5 for analysis.');
  } else {
    final needed = 5 - unreadRepositories.length;
    final fallbackCandidates = fetchedRepositories
        .where((repo) => !allSummaries.any((s) => s.repository.url == repo.url) &&
                         !unreadRepositories.any((u) => u.url == repo.url))
        .toList();
    fallbackCandidates.shuffle();

    repositoriesToAnalyze = [
      ...unreadRepositories,
      ...fallbackCandidates.take(needed),
    ];
    print('  - Only ${unreadRepositories.length} unread. Supplementing with ${repositoriesToAnalyze.length - unreadRepositories.length} historical ones.');
  }

  if (repositoriesToAnalyze.isEmpty) {
    print('  - No new repositories to analyze.');
    return;
  }

  print('🤖 Analyzing ${repositoriesToAnalyze.length} repositories in batches...');
  const batchSize = 3;
  for (var i = 0; i < repositoriesToAnalyze.length; i += batchSize) {
    final end = (i + batchSize < repositoriesToAnalyze.length)
        ? i + batchSize
        : repositoriesToAnalyze.length;
    final batch = repositoriesToAnalyze.sublist(i, end);

    print(
        '  - Analyzing batch ${i ~/ batchSize + 1} (${batch.length} repositories)...');
    final analyzeResult = await analyzer.analyzeBatch(batch);

    // バッチ間のレート制限回避 (もっと長く)
    await Future.delayed(const Duration(milliseconds: 3000));

    switch (analyzeResult) {
      case Success(value: final summaries):
        allSummaries.addAll(summaries);
        for (final s in summaries) {
          print('    ✅ Analyzed ${s.repository.owner}/${s.repository.name}');
        }
      case Failure(error: final e):
        print('    ⚠️ Batch analysis failed: $e');
    }
  }
}
