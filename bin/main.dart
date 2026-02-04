import 'dart:io';
import 'package:args/args.dart';
import 'package:github_trend_summary/github_trend_summary.dart';
import 'package:github_trend_summary/core/logger.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
  ..addOption('config',
        abbr: 'c',
        help: 'Path to config.yaml',
        defaultsTo: 'config.yaml')
    ..addOption('lang',
        abbr: 'l',
        help: 'Target programming languages (comma separated, e.g. dart,typescript,all)')
    ..addOption('topic',
        abbr: 't',
        help: 'Target topics (comma separated, e.g. ai,llm,flutter)')
    ..addOption('min-stars',
        help: 'Minimum star count (defaults to 50 for "all", 10 for specific language/topic)')
    ..addOption('max-stars',
        help: 'Maximum star count to exclude giant projects (e.g. 50000)')
    ..addFlag('new-only',
        help: 'Fetch only repositories created within the last 14 days')
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
    Logger.error('Error parsing arguments: $e');
    print(parser.usage);
    exit(1);
  }

  if (results['help'] as bool) {
    print('GitHub Trending Intelligence CLI');
    print(parser.usage);
    return;
  }

  // Load config
  final configPath = results['config'] as String;
  final config = await AppConfig.load(configPath);

  // CLI overrides
  final languages = results['lang'] != null 
      ? (results['lang'] as String).split(',').map((e) => e.trim()).toList() 
      : config.languages;
  final topics = results['topic'] != null 
      ? (results['topic'] as String).split(',').map((e) => e.trim()).toList() 
      : config.topics;
  
  final githubToken = results['github-token'] as String?;
  final geminiKey = results['gemini-key'] as String;
  final outputPath = results['output'] as String?;
  final rssPath = results['rss'] as String?;
  final htmlPath = results['html'] as String?;
  
  final minStars = results['min-stars'] != null 
      ? int.tryParse(results['min-stars'] as String) 
      : config.minStars;
  final maxStars = results['max-stars'] != null 
      ? int.tryParse(results['max-stars'] as String) 
      : config.maxStars;
  final newOnly = results.wasParsed('new-only') 
      ? results['new-only'] as bool 
      : config.newOnly;

  // 自動的に履歴URLを構築 (GitHub Actions環境の場合)
  String? historyUrl;
  final repo = Platform.environment['GITHUB_REPOSITORY'];
  final owner = Platform.environment['GITHUB_REPOSITORY_OWNER'];
  if (repo != null && owner != null && repo.contains('/')) {
    final repoName = repo.split('/')[1];
    historyUrl = 'https://$owner.github.io/$repoName/rss.xml';
    Logger.info('Automatically detected history URL: $historyUrl');
  }

  final fetcher = GitHubFetcher(apiToken: githubToken);
  final analyzer = GeminiAnalyzer(apiKey: geminiKey, model: config.geminiModel);
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
    Logger.info('Loaded ${seenUrls.length} previously reported repositories.');
  }

  // Fetch and Analyze for each language
  if (languages.isEmpty && topics.isEmpty) {
    languages.add('all');
  }

  final candidatePool = <Repository>[];

  for (final lang in languages) {
    Logger.info('Fetching trending $lang repositories...');
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
      Logger.warning('Failed to fetch $lang: ${fetchResult.error}');
    }
  }

  for (final topic in topics) {
    Logger.info('Fetching trending topic:$topic repositories...');
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
      Logger.warning('Failed to fetch topic:$topic: ${fetchResult.error}');
    }
  }

  // グローバルサンプリング (合計5件)
  final repositoriesToAnalyze = _sampleRepositories(candidatePool, seenUrls, excludeRepos: config.excludeRepos);

  if (repositoriesToAnalyze.isEmpty) {
    Logger.warning('No repositories to analyze. Exiting.');
    exit(1);
  }

  Logger.info('Analyzing ${repositoriesToAnalyze.length} repositories individually...');
  
  for (final repo in repositoriesToAnalyze) {
    Logger.info('Analyzing ${repo.owner}/${repo.name}...');
    
    // Analyze前にREADMEを取得して埋める
    final readmeContent = await fetcher.fetchReadme(repo);
    final repoWithReadme = (
      name: repo.name,
      owner: repo.owner,
      description: repo.description,
      url: repo.url,
      stars: repo.stars,
      language: repo.language,
      readmeContent: readmeContent,
    );

    final analyzeResult = await analyzer.analyze(repoWithReadme);

    switch (analyzeResult) {
      case Success(value: final summary):
        allSummaries.add(summary);
        Logger.info('Analyzed ${summary.repository.owner}/${summary.repository.name}');
      case Failure(error: final e):
        Logger.error('Failed to analyze ${repo.owner}/${repo.name}: $e');
    }
    
    // APIレート制限への配慮（念のため）
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  if (allSummaries.isEmpty) {
    Logger.error('No summaries were generated. Exiting.');
    exit(1);
  }

  final publishers = <Publisher>[
    ConsolePublisher(),
    if (outputPath != null) MarkdownFilePublisher(outputPath: outputPath),
    if (rssPath != null) RssPublisher(outputPath: rssPath, historyUrl: historyUrl),
    if (htmlPath != null) HtmlPublisher(outputPath: htmlPath),
  ];

  Logger.info('Publishing results...');
  for (final publisher in publishers) {
    final publishResult = await publisher.publish(allSummaries);
    if (publishResult is Failure) {
      Logger.error('Failed to publish with ${publisher.runtimeType}: ${(publishResult as Failure).error}');
      exit(1);
    }
  }

  Logger.info('Done!');
}

List<Repository> _sampleRepositories(List<Repository> pool, Set<String> seenUrls, {List<String> excludeRepos = const []}) {
  // 1. 重複除去 (URLベース) および 除外設定の適用
  final uniquePool = <String, Repository>{};
  final excludeSet = excludeRepos.map((e) => e.toLowerCase()).toSet();

  for (final repo in pool) {
    final fullName = '${repo.owner}/${repo.name}'.toLowerCase();
    if (excludeSet.contains(fullName)) {
      continue;
    }
    uniquePool[repo.url] = repo;
  }
  final candidates = uniquePool.values.toList();

  // 2. 未読と既読に分ける
  final unread = candidates.where((r) => !seenUrls.contains(r.url)).toList();
  final seen = candidates.where((r) => seenUrls.contains(r.url)).toList();

  print('\n🎯 Discovery Sampling (Natural Density):');
  print('  - Candidates pool: ${candidates.length} (Unread: ${unread.length}, Seen: ${seen.length})');

  final List<Repository> finalSelection = [];

  // 3. 未読から最大5件を「ランダム」に選出 (Discovery)
  // 理由: カテゴリごとの母数に比例した自然な重み付けになるため
  if (unread.isNotEmpty) {
    unread.shuffle();
    final selection = unread.take(5).toList();
    finalSelection.addAll(selection);
    print('  ✨ Picking ${selection.length} unread repositories for discovery (Random).');
    for (final r in selection) {
      print('    - [New] ${r.owner}/${r.name} (${r.stars} stars)');
    }
  }

  // 4. 不足分を既読（ Returning Stars ）から補填 (スター数＝勢い順)
  if (finalSelection.length < 5 && seen.isNotEmpty) {
    final needed = 5 - finalSelection.length;
    // 現在のスター数が多い順にソート (勢いのあるものを優先)
    final sortedSeen = seen.toList()..sort((a, b) => b.stars.compareTo(a.stars));
    final pick = sortedSeen.take(needed).toList();
    finalSelection.addAll(pick);
    
    print('  - Supplementing with ${pick.length} returning stars (Sorted by Current Stars):');
    for (final r in pick) {
      print('    - [Returning Star] ${r.owner}/${r.name} (${r.stars} stars)');
    }
  }

  return finalSelection;
}
