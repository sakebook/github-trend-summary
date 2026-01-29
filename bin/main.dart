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

  // 自動的に履歴URLを構築 (GitHub Actions環境の場合)
  String? historyUrl;
  final repo = Platform.environment['GITHUB_REPOSITORY'];
  final owner = Platform.environment['GITHUB_REPOSITORY_OWNER'];
  if (repo != null && owner != null && repo.contains('/')) {
    final repoName = repo.split('/')[1];
    historyUrl = 'https://$owner.github.io/$repoName/rss.xml';
    print('🤖 Automatically detected history URL: $historyUrl');
  }

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

  final candidatePool = <Repository>[];

  for (final lang in languages) {
    print('🔍 Fetching trending $lang repositories...');
    final fetchResult = await fetcher.fetchTrending(
      lang,
      minStars: minStars,
      maxStars: maxStars,
      newOnly: newOnly,
      isTopic: false,
    );
    if (fetchResult is Success<List<Repository>, Exception>) {
      candidatePool.addAll(fetchResult.value);
    } else if (fetchResult is Failure<List<Repository>, Exception>) {
      print('  ⚠️ Failed to fetch $lang: ${fetchResult.error}');
    }
  }

  for (final topic in topics) {
    print('🔍 Fetching trending topic:$topic repositories...');
    final fetchResult = await fetcher.fetchTrending(
      topic,
      minStars: minStars,
      maxStars: maxStars,
      newOnly: newOnly,
      isTopic: true,
    );
    if (fetchResult is Success<List<Repository>, Exception>) {
      candidatePool.addAll(fetchResult.value);
    } else if (fetchResult is Failure<List<Repository>, Exception>) {
      print('  ⚠️ Failed to fetch topic:$topic: ${fetchResult.error}');
    }
  }

  // グローバルサンプリング (合計5件)
  final repositoriesToAnalyze = _sampleRepositories(candidatePool, seenUrls);

  if (repositoriesToAnalyze.isEmpty) {
    print('❌ No repositories to analyze. Exiting.');
    exit(1);
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

    // バッチ間のレート制限回避
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

List<Repository> _sampleRepositories(List<Repository> pool, Set<String> seenUrls) {
  // 1. 重複除去 (URLベース)
  final uniquePool = <String, Repository>{};
  for (final repo in pool) {
    uniquePool[repo.url] = repo;
  }
  final candidates = uniquePool.values.toList();

  // 2. 未読と既読に分ける
  final unread = candidates.where((r) => !seenUrls.contains(r.url)).toList();
  final seen = candidates.where((r) => seenUrls.contains(r.url)).toList();

  print('\n🎯 Discovery Sampling:');
  print('  - Candidates pool: ${candidates.length} (Unread: ${unread.length}, Seen: ${seen.length})');

  final List<Repository> finalSelection = [];

  // 3. 未読から最大5件をランダム選出 (Discovery)
  if (unread.isNotEmpty) {
    unread.shuffle();
    final selection = unread.take(5).toList();
    finalSelection.addAll(selection);
    print('  ✨ Picking ${selection.length} unread repositories for discovery.');
    for (final r in selection) {
      print('    - [New] ${r.owner}/${r.name} (${r.stars} stars)');
    }
  }

  // 4. 不足分を既読（ Returning Stars ）から補填 (スター数順)
  if (finalSelection.length < 5 && seen.isNotEmpty) {
    final needed = 5 - finalSelection.length;
    // スター数が多い順にソート
    final sortedSeen = seen.toList()..sort((a, b) => b.stars.compareTo(a.stars));
    final pick = sortedSeen.take(needed).toList();
    finalSelection.addAll(pick);
    
    print('  - Supplementing with $needed returning stars (sorted by popularity):');
    for (final r in pick) {
      print('    - [Returning Star] ${r.owner}/${r.name} (${r.stars} stars)');
    }
  }

  return finalSelection;
}
