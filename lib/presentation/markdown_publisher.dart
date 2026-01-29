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
      buffer.writeln('Generated on: ${DateTime.now().toUtc().add(const Duration(hours: 9))} (JST)\n');

      for (final summary in summaries) {
        final repo = summary.repository;
        buffer.writeln('## [${repo.owner}/${repo.name}](${repo.url})');
        buffer.writeln('- **Stars**: ${repo.stars}');
        buffer.writeln('- **Language**: ${repo.language ?? "N/A"}\n');
        buffer.writeln('> ${summary.summary}\n');
        buffer.writeln('### 背景');
        buffer.writeln('${summary.background}\n');
        buffer.writeln('### 技術スタック');
        buffer.writeln('${summary.techStack.map((s) => "`$s`").join(", ")}\n');
        buffer.writeln('### 注目理由');
        buffer.writeln('${summary.whyHot}\n');
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
