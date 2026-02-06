typedef Repository = ({
  String name,
  String owner,
  String? description,
  String url,
  int stars,
  String? language,
  String? readmeContent,
  String? metadataContent,
});

sealed class TrendSummary {
  final Repository repository;
  final String summary;
  const TrendSummary({required this.repository, required this.summary});
}

final class JapaneseSummary extends TrendSummary {
  final List<String> techStack;
  final String useCase;
  final String rivalComparison;
  final List<String> keyFeatures;
  final String maturity;
  final String implementationFlavor;

  const JapaneseSummary({
    required super.repository,
    required super.summary,
    required this.techStack,
    required this.useCase,
    required this.rivalComparison,
    required this.keyFeatures,
    required this.maturity,
    required this.implementationFlavor,
  });
}
