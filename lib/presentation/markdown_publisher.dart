import 'dart:io';
import '../core/interfaces.dart';
import '../core/models.dart';
import '../core/result.dart';

class MarkdownFilePublisher implements Publisher {
  final String outputPath;

  MarkdownFilePublisher({required this.outputPath});

  @override
  Future<Result<void, Exception>> publish(
      List<JapaneseSummary> summaries) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('# GitHub Trending Summary');
      buffer.writeln('Generated on: ${DateTime.now().toUtc().add(const Duration(hours: 9)).toString().split('.')[0]} (JST)\n');

      for (final summary in summaries) {
        final repo = summary.repository;
        buffer.writeln('## [${repo.owner}/${repo.name}](${repo.url})');
        buffer.writeln('- **Stars**: ${repo.stars}');
        buffer.writeln('- **Language**: ${repo.language ?? "N/A"}\n');
        buffer.writeln('> ${summary.summary}\n');
        buffer.writeln('### 活用シーン');
        buffer.writeln('${summary.useCase}\n');
        buffer.writeln('### 主要機能');
        buffer.writeln('${summary.keyFeatures.map((f) => "- $f").join("\n")}\n');
        buffer.writeln('### 開発状況');
        buffer.writeln('**${summary.maturity}**\n');
        buffer.writeln('### 技術スタック');
        buffer.writeln('${summary.techStack.map((s) => "`$s`").join(", ")}\n');
        buffer.writeln('### 競合差別化');
        buffer.writeln('${summary.rivalComparison}\n');
        buffer.writeln('---\n');
      }

      final file = File(outputPath);
      await file.writeAsString(buffer.toString());

      return const Success(null);
    } catch (e) {
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }
}
