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
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&family=Outfit:wght@700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg: #0b0f1a;
            --card: #161b22;
            --card-border: #30363d;
            --text-main: #e6edf3;
            --text-dim: #8b949e;
            --accent: #58a6ff;
            --accent-soft: rgba(88, 166, 255, 0.1);
            --star: #e3b341;
            --bg-gradient: radial-gradient(circle at top right, #161b22, #0b0f1a);
        }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: var(--bg);
            background-image: var(--bg-gradient);
            color: var(--text-main);
            line-height: 1.6;
            margin: 0;
            padding: 0;
            min-height: 100vh;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        header {
            text-align: center;
            margin-bottom: 60px;
            animation: fadeInDown 0.8s ease-out;
        }
        h1 {
            font-family: 'Outfit', sans-serif;
            font-size: 3rem;
            background: linear-gradient(135deg, #fff 0%, var(--accent) 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin: 0;
            letter-spacing: -0.02em;
        }
        .header-sub {
            color: var(--text-dim);
            font-size: 1.1rem;
            margin-top: 8px;
        }
        .update-time {
            display: inline-block;
            margin-top: 16px;
            padding: 4px 12px;
            background: var(--accent-soft);
            border-radius: 100px;
            font-size: 0.8rem;
            color: var(--accent);
            border: 1px solid rgba(88, 166, 255, 0.2);
        }
        .repo-card {
            background: var(--card);
            border: 1px solid var(--card-border);
            border-radius: 16px;
            padding: 32px;
            margin-bottom: 32px;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            position: relative;
            overflow: hidden;
        }
        .repo-card:hover {
            transform: translateY(-4px);
            border-color: var(--accent);
            box-shadow: 0 12px 24px rgba(0,0,0,0.3);
        }
        .repo-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }
        .repo-name {
            font-size: 1.5rem;
            font-weight: 800;
            text-decoration: none;
            color: var(--accent);
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .repo-name::before {
            content: "🚀";
            font-size: 1.2rem;
        }
        .stars {
            color: var(--star);
            font-weight: 600;
            font-size: 0.9rem;
            display: flex;
            align-items: center;
            gap: 4px;
        }
        .repo-description {
            color: var(--text-dim);
            font-size: 0.95rem;
            margin-bottom: 24px;
            font-style: italic;
        }
        .summary-box {
            background: rgba(255,255,255,0.03);
            border-left: 4px solid var(--accent);
            padding: 16px 20px;
            border-radius: 4px 12px 12px 4px;
            margin-bottom: 24px;
            font-weight: 600;
        }
        .grid-sections {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 24px;
            margin-bottom: 24px;
        }
        @media (max-width: 600px) {
            .grid-sections { grid-template-columns: 1fr; }
        }
        .section-item h3 {
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.1em;
            color: var(--text-dim);
            margin: 0 0 8px 0;
        }
        .section-item p {
            margin: 0;
            font-size: 0.9rem;
            color: var(--text-main);
        }
        .tech-stack {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            margin-top: 12px;
        }
        .tech-tag {
            background: #21262d;
            border: 1px solid var(--card-border);
            color: var(--text-main);
            padding: 4px 12px;
            border-radius: 6px;
            font-size: 0.75rem;
            font-weight: 500;
        }
        footer {
            text-align: center;
            padding: 60px 0;
            color: var(--text-dim);
            font-size: 0.9rem;
        }
        footer a {
            color: var(--accent);
            text-decoration: none;
        }
        @keyframes fadeInDown {
            from { opacity: 0; transform: translateY(-20px); }
            to { opacity: 1; transform: translateY(0); }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Trending Intelligence</h1>
            <p class="header-sub">Daily GitHub analysis powered by Gemini AI</p>
            <div class="update-time">Last Updated: ${DateTime.now().toUtc().add(const Duration(hours: 9)).toString().split('.')[0]} (JST)</div>
        </header>

        <main>
''');

      for (final s in summaries) {
        buffer.writeln('''
            <div class="repo-card">
                <div class="repo-header">
                    <a href="${_escapeHtml(s.repository.url)}" class="repo-name" target="_blank">${_escapeHtml(s.repository.name)}</a>
                    <span class="stars">⭐ ${s.repository.stars.toString()}</span>
                </div>
                <p class="repo-description">${_escapeHtml(s.repository.description ?? '')}</p>
                <div class="summary-box">${_escapeHtml(s.summary)}</div>
                
                <div class="grid-sections">
                    <div class="section-item">
                        <h3>活用シーン / Use Case</h3>
                        <p>${_escapeHtml(s.useCase)}</p>
                    </div>
                    <div class="section-item">
                        <h3>主要機能 / Key Features</h3>
                        <ul>
                          ${s.keyFeatures.map((f) => "<li>${_escapeHtml(f)}</li>").join("")}
                        </ul>
                    </div>
                    <div class="section-item">
                        <h3>開発状況 / Maturity</h3>
                         <span class="tech-tag" style="background:var(--accent-soft); border-color:var(--accent);">${_escapeHtml(s.maturity)}</span>
                    </div>
                    <div class="section-item">
                        <h3>競合差別化 / Competitive Edge</h3>
                        <p>${_escapeHtml(s.rivalComparison)}</p>
                    </div>
                </div>
                
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
