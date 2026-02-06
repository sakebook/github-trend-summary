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
            --bg: #0d1117;
            --card: rgba(22, 27, 34, 0.7);
            --card-border: rgba(48, 54, 61, 0.8);
            --text-main: #e6edf3;
            --text-dim: #9198a1;
            --accent: #58a6ff;
            --accent-glow: rgba(88, 166, 255, 0.3);
            --accent-soft: rgba(88, 166, 255, 0.1);
            --star: #f0883e;
            --bg-gradient: radial-gradient(circle at 50% -20%, #1e293b, #0d1117);
            --glass-border: rgba(255, 255, 255, 0.05);
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
            -webkit-font-smoothing: antialiased;
        }
        .container {
            max-width: 900px;
            margin: 0 auto;
            padding: 60px 24px;
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
            backdrop-filter: blur(12px);
            -webkit-backdrop-filter: blur(12px);
            border: 1px solid var(--card-border);
            border-top: 1px solid var(--glass-border);
            border-radius: 20px;
            padding: 40px;
            margin-bottom: 40px;
            transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
            position: relative;
            overflow: hidden;
            animation: fadeInUp 0.8s ease-out backwards;
        }
        .repo-card:hover {
            transform: translateY(-6px) scale(1.01);
            border-color: var(--accent);
            box-shadow: 0 20px 40px rgba(0,0,0,0.4), 0 0 20px var(--accent-glow);
        }
        .repo-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }
        .header-left {
            display: flex;
            align-items: center;
            gap: 12px;
            flex-wrap: wrap;
        }
        .maturity-badge {
            font-size: 0.75rem;
            padding: 2px 8px;
            border-radius: 4px;
            font-weight: 600;
            white-space: nowrap;
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
        .section-item.full-width {
            grid-column: 1 / -1;
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
            from { opacity: 0; transform: translateY(-30px); }
            to { opacity: 1; transform: translateY(0); }
        }
        @keyframes fadeInUp {
            from { opacity: 0; transform: translateY(30px); }
            to { opacity: 1; transform: translateY(0); }
        }
        .repo-card:nth-child(1) { animation-delay: 0.1s; }
        .repo-card:nth-child(2) { animation-delay: 0.2s; }
        .repo-card:nth-child(3) { animation-delay: 0.3s; }
        .repo-card:nth-child(4) { animation-delay: 0.4s; }
        .repo-card:nth-child(5) { animation-delay: 0.5s; }
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
                    <div class="header-left">
                        <a href="${_escapeHtml(s.repository.url)}" class="repo-name" target="_blank">${_escapeHtml(s.repository.name)}</a>
                        ${!s.maturity.contains('Active Development') ? '<span class="maturity-badge" style="background:var(--accent-soft); color:var(--accent); border:1px solid var(--accent);">${_escapeHtml(s.maturity)}</span>' : ''}
                    </div>
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
                        <h3>競合差別化 / Competitive Edge</h3>
                        <p>${_escapeHtml(s.rivalComparison)}</p>
                    </div>
                    <div class="section-item full-width">
                        <h3>実装のこだわり / Implementation Flavor</h3>
                        <p>${_escapeHtml(s.implementationFlavor)}</p>
                    </div>
                    <div class="section-item full-width">
                        <h3>主要機能 / Key Features</h3>
                        <ul>
                          ${s.keyFeatures.map((f) => "<li>${_escapeHtml(f)}</li>").join("")}
                        </ul>
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
