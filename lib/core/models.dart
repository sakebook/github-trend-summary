typedef Repository = ({
  String name,
  String owner,
  String? description,
  String url,
  int stars,
  String? language,
});

sealed class TrendSummary {
  final Repository repository;
  final String summary;
  const TrendSummary({required this.repository, required this.summary});
}

final class JapaneseSummary extends TrendSummary {
  final String background;
  final List<String> techStack;
  final String whyHot;

  const JapaneseSummary({
    required super.repository,
    required super.summary,
    required this.background,
    required this.techStack,
    required this.whyHot,
  });
}
