import 'models.dart';
import 'result.dart';

abstract interface class RepositoryFetcher {
  Future<Result<List<Repository>, Exception>> fetchTrending(String language);
}

abstract interface class TrendAnalyzer {
  Future<Result<JapaneseSummary, Exception>> analyze(Repository repository);
}

abstract interface class Publisher {
  Future<Result<void, Exception>> publish(List<JapaneseSummary> summaries);
}
