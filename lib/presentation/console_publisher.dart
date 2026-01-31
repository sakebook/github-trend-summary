import '../core/interfaces.dart';
import '../core/models.dart';
import '../core/result.dart';

class ConsolePublisher implements Publisher {
  @override
  Future<Result<void, Exception>> publish(
      List<JapaneseSummary> summaries) async {
    try {
      print('=== GitHub Trending Summary (${DateTime.now()}) ===\n');

      for (final summary in summaries) {
        final repo = summary.repository;
        print('🚀 ${repo.owner}/${repo.name} (⭐ ${repo.stars})');
        print('🔗 ${repo.url}');
        print('📝 ${summary.summary}');
        print('\n【活用シーン】\n${summary.useCase}');
        print('\n【技術スタック】\n${summary.techStack.join(', ')}');
        print('\n【主要機能】\n${summary.keyFeatures.map((f) => "- $f").join("\n")}');
        print('\n【開発状況】\n${summary.maturity}');
        print('\n【競合差別化】\n${summary.rivalComparison}');
        print('\n${'-' * 40}\n');
      }

      return const Success(null);
    } catch (e) {
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }
}
