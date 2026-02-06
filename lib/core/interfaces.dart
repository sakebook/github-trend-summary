import 'models.dart';
import 'result.dart';

/// GitHubからトレンドリポジトリを取得するためのインターフェース。
abstract interface class RepositoryFetcher {
  /// 指定された [target]（言語またはトピック）に基づいてトレンドリポジトリを取得する。
  Future<Result<List<Repository>, Exception>> fetchTrending(
    String target, {
    int? minStars,
    int? maxStars,
    bool newOnly = false,
    bool isTopic = false,
  });

  /// リポジトリのREADMEを取得する。
  Future<String?> fetchReadme(Repository repository);

  /// リポジトリの技術構成ファイル（メタデータ）を取得する。
  Future<String?> fetchMetadata(Repository repository);
}

/// リポジトリの内容を解析してサマリーを生成するためのインターフェース。
abstract interface class TrendAnalyzer {
  /// 単一のリポジトリを解析する。
  Future<Result<JapaneseSummary, Exception>> analyze(Repository repository);

  /// 複数のリポジトリを一括で解析する。
  Future<Result<List<JapaneseSummary>, Exception>> analyzeBatch(List<Repository> repositories);
}

/// 解析結果を外部（ファイル、コンソール、APIなど）に出力するためのインターフェース。
abstract interface class Publisher {
  /// 解析結果のリストを公開する。
  Future<Result<void, Exception>> publish(List<JapaneseSummary> summaries);
}
