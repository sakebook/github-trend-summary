import 'dart:io';
import '../core/interfaces.dart';
import '../core/models.dart';
import '../core/result.dart';

class HtmlPublisher implements Publisher {
  final String outputPath;

  HtmlPublisher({required this.outputPath});

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  @override
  Future<Result<void, Exception>> publish(List<JapaneseSummary> summaries) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('''
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GitHub Trending Intelligence</title>
    <style>
        :root {
            --bg-color: #f8f9fa;
            --card-bg: #ffffff;
            --text-color: #212529;
            --accent-color: #0d6efd;
            --secondary-text: #6c757d;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-color);
            line-height: 1.6;
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 900px;
            margin: 0 auto;
        }
        header {
            text-align: center;
            margin-bottom: 40px;
        }
        h1 {
            color: var(--accent-color);
            margin-bottom: 10px;
        }
        .update-time {
            color: var(--secondary-text);
            font-size: 0.9em;
        }
        .repo-card {
            background: var(--card-bg);
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
            padding: 24px;
            margin-bottom: 24px;
            border: 1px solid #dee2e6;
        }
        .repo-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 16px;
        }
        .repo-title {
            font-size: 1.4em;
            font-weight: bold;
            text-decoration: none;
            color: var(--accent-color);
        }
        .repo-title:hover {
            text-decoration: underline;
        }
        .stars {
            background: #f1f8ff;
            color: #0366d6;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 600;
        }
        .section-title {
            font-weight: bold;
            margin-top: 16px;
            margin-bottom: 4px;
            color: #495057;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }
        .tech-tags {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            margin-top: 8px;
        }
        .tech-tag {
            background: #e9ecef;
            padding: 2px 10px;
            border-radius: 4px;
            font-size: 0.8em;
            color: #495057;
        }
        footer {
            text-align: center;
            margin-top: 60px;
            padding-bottom: 40px;
            color: var(--secondary-text);
            font-size: 0.85em;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>GitHub Trending Intelligence</h1>
            <p>Gemini AIによる日刊トレンド分析レポート</p>
            <div class="update-time">最終更新: ${DateTime.now().toLocal().toString().split('.')[0]}</div>
        </header>

        <main>
''');

      for (final s in summaries) {
        final repo = s.repository;
        buffer.writeln('''
            <div class="repo-card">
                <div class="repo-header">
                    <a href="${s.repository.url}" class="repo-name" target="_blank">${_escapeHtml(s.repository.name)}</a>
                    <span class="stars">⭐ ${s.repository.stars}</span>
                </div>
                <p class="repo-description">${_escapeHtml(s.repository.description ?? '')}</p>
                <div class="summary-badge">${_escapeHtml(s.summary)}</div>
                
                <div class="section-title">背景</div>
                <p>${_escapeHtml(s.background)}</p>
                
                <div class="section-title">なぜ注目？</div>
                <p>${_escapeHtml(s.whyHot)}</p>
                
                <div class="tech-stack">
                    ${s.techStack.map((t) => '<span class="tech-tag">${_escapeHtml(t)}</span>').join('')}
                </div>
            </div>
''');
      }

      buffer.writeln('''
        </main>

        <footer>
            <p>&copy; 2026 GitHub Trending Intelligence Agent</p>
            <p><a href="rss.xml">RSS Feed</a></p>
        </footer>
    </div>
</body>
</html>
''');

      final file = File(outputPath);
      final parent = file.parent;
      if (!parent.existsSync()) {
        await parent.create(recursive: true);
      }
      await file.writeAsString(buffer.toString());
      return Success(null);
    } catch (e) {
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }
}
