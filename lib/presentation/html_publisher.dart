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
    <link href="https://fonts.googleapis.com/css2?family=Public+Sans:wght@700;900&family=Lexend:wght@500;700;900&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg: #e0e5ec;
            --card-w: #ffffff;
            --card-accent: #f4f0e6;
            --text: #171717;
            --border: #171717;
            --accent-red: #ff5e5e;
            --accent-blue: #a3cbf1;
            --accent-yellow: #fde047;
            --accent-green: #86efac;
            --accent-purple: #c4b5fd;
            --shadow-sm: 3px 3px 0px var(--border);
            --shadow-md: 6px 6px 0px var(--border);
            --shadow-lg: 10px 10px 0px var(--border);
            --bw: 3px;
            --space-sm: 12px;
            --space-md: 24px;
            --space-lg: 40px;
        }

        body {
            font-family: 'Lexend', ui-sans-serif, system-ui, -apple-system, sans-serif;
            background-color: var(--bg);
            background-image: radial-gradient(var(--border) 1px, transparent 1px);
            background-size: 24px 24px;
            color: var(--text);
            margin: 0;
            padding: 80px 20px 100px;
            line-height: 1.6;
            overflow-x: hidden;
            -webkit-font-smoothing: antialiased;
        }

        .container {
            max-width: 850px;
            margin: 0 auto;
            position: relative;
        }

        h1, h2, h3 {
            font-family: 'Public Sans', sans-serif;
            font-weight: 900;
            color: var(--text);
        }

        .header-wrapper {
            position: relative;
            margin-bottom: var(--space-lg);
        }

        .header {
            padding: var(--space-lg);
            background: var(--accent-purple);
            border: var(--bw) solid var(--border);
            box-shadow: var(--shadow-lg);
            text-align: center;
            position: relative;
            z-index: 2;
            border-radius: 8px;
        }

        .header h1 {
            font-size: clamp(2.5rem, 6vw, 4rem);
            text-transform: uppercase;
            margin: 0;
            letter-spacing: -2px;
            line-height: 1.1;
        }

        .update-time {
            font-weight: 700;
            margin: 16px 0 0 0;
            font-size: 1.2rem;
            background: var(--bg);
            display: inline-block;
            padding: 4px 12px;
            border: var(--bw) solid var(--border);
            color: var(--text);
            box-shadow: var(--shadow-sm);
            border-radius: 6px;
        }

        .card {
            background: var(--card-w);
            border: var(--bw) solid var(--border);
            padding: var(--space-lg);
            margin-bottom: 60px;
            box-shadow: var(--shadow-lg);
            position: relative;
            z-index: 10;
            border-radius: 12px;
        }

        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: var(--space-md);
            border-bottom: var(--bw) solid var(--border);
            padding-bottom: var(--space-md);
            gap: var(--space-md);
            flex-wrap: wrap;
        }

        .header-left {
            display: flex;
            flex-direction: column;
            align-items: flex-start;
            gap: 8px;
        }

        .repo-title {
            font-size: clamp(1.4rem, 4vw, 2rem);
            font-weight: 900;
            color: var(--text);
            text-decoration: none;
            background: var(--accent-yellow);
            border: var(--bw) solid var(--border);
            padding: 8px 16px;
            box-shadow: var(--shadow-sm);
            margin-top: 8px;
            transition: all 0.15s ease-out;
            font-family: 'Public Sans', sans-serif;
            align-self: flex-start;
            border-radius: 6px;
            display: inline-block;
        }

        .repo-title:hover {
            transform: translate(-2px, -2px);
            box-shadow: var(--shadow-md);
        }

        .repo-title:active {
            transform: translate(3px, 3px);
            box-shadow: 0px 0px 0 var(--border);
        }

        .badge {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            color: var(--text);
            border: var(--bw) solid var(--border);
            padding: 4px 12px;
            font-weight: 900;
            text-transform: uppercase;
            font-size: 0.85rem;
            box-shadow: var(--shadow-sm);
            border-radius: 9999px;
            cursor: default;
            letter-spacing: 0.5px;
        }

        .stars {
            background: var(--card-w);
            border: var(--bw) solid var(--border);
            padding: 8px 16px;
            font-weight: 900;
            font-size: 1.2rem;
            box-shadow: var(--shadow-sm);
            display: flex;
            align-items: center;
            gap: 6px;
            border-radius: 9999px;
        }

        .desc {
            font-size: 1.15rem;
            font-weight: 500;
            margin-bottom: var(--space-lg);
            margin-top: 0;
            background: var(--card-accent);
            display: block;
            padding: var(--space-md);
            border: var(--bw) solid var(--border);
            line-height: 1.6;
            border-radius: 8px;
            box-shadow: var(--shadow-sm);
        }

        .grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: var(--space-md);
            margin-top: var(--space-md);
        }

        @media (max-width: 768px) {
            .grid { grid-template-columns: 1fr; }
            .card { padding: 24px; }
        }

        .section {
            border: var(--bw) solid var(--border);
            padding: var(--space-md);
            background: #fff;
            box-shadow: var(--shadow-sm);
            border-radius: 8px;
        }

        .section h3 {
            font-size: 1rem;
            text-transform: uppercase;
            margin: 0 0 var(--space-sm) 0;
            padding-bottom: 8px;
            border-bottom: var(--bw) solid var(--border);
            letter-spacing: 1px;
        }

        .section.highlight {
            background: var(--card-accent);
        }

        .section p, .section ul {
            margin: 0;
            font-size: 1rem;
            font-weight: 500;
            line-height: 1.7;
            color: #333;
        }

        .section ul {
            padding-left: 20px;
        }

        .section li {
            margin-bottom: 8px;
        }

        .tech-container {
            margin-top: var(--space-lg);
        }

        .tech-container h3 {
            font-size: 1rem;
            text-transform: uppercase;
            margin: 0 0 var(--space-sm) 0;
            letter-spacing: 1px;
        }

        .tech-stack {
            display: flex;
            flex-wrap: wrap;
            gap: 12px;
        }

        .tech-tag {
            background: #fff;
            border: var(--bw) solid var(--border);
            color: var(--text);
            padding: 6px 14px;
            font-weight: 700;
            font-size: 0.9rem;
            box-shadow: var(--shadow-sm);
            border-radius: 6px;
            cursor: default;
        }

        footer {
            text-align: center;
            padding: 40px 0;
            font-weight: 700;
        }

        footer a {
            color: var(--text);
            text-decoration: none;
            border-bottom: var(--bw) solid var(--border);
            padding-bottom: 2px;
            transition: all 0.15s ease-out;
            font-family: 'Public Sans', sans-serif;
            text-transform: uppercase;
        }

        footer a:hover {
            background: var(--accent-yellow);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header-wrapper">
            <header class="header">
                <h1>Trending Intelligence</h1>
                <p class="update-time">Daily GitHub analysis powered by Gemini AI<br>
                <span style="font-size: 0.9rem; font-weight: 500;">Last Updated: ${DateTime.now().toUtc().add(const Duration(hours: 9)).toString().split('.')[0]} (JST)</span></p>
            </header>
        </div>

        <main>
''');

      for (final s in summaries) {
        final repo = s.repository;
        buffer.writeln('''
            <div class="card">
                <header class="card-header">
                    <div class="header-left">
                        <span class="badge" style="background:${_getMaturityBg(s.maturity)};">
                            ${_escapeHtml(s.maturity)}
                        </span>
                        <a href="${_escapeHtml(repo.url)}" class="repo-title" target="_blank">${_escapeHtml(repo.owner)} / ${_escapeHtml(repo.name)}</a>
                    </div>
                    <span class="stars">⭐ ${repo.stars}</span>
                </header>

                <p class="desc">${_escapeHtml(repo.description ?? 'No description provided')}</p>

                <div class="section highlight" style="margin-bottom: var(--space-md);">
                    <h3>Summary</h3>
                    <p>${_escapeHtml(s.summary)}</p>
                </div>

                <div class="grid">
                    <div class="section">
                        <h3>活用シーン / Use Case</h3>
                        <p>${_escapeHtml(s.useCase)}</p>
                    </div>
                    <div class="section">
                        <h3>競合差別化 / Competitive Edge</h3>
                        <p>${_escapeHtml(s.rivalComparison)}</p>
                    </div>
                    <div class="section">
                        <h3>実装のこだわり / Flavor</h3>
                        <p>${_escapeHtml(s.implementationFlavor)}</p>
                    </div>
                    <div class="section">
                        <h3>主要機能 / Key Features</h3>
                        <ul style="margin-top: 8px;">
                          ${s.keyFeatures.map((f) => "<li>${_escapeHtml(f)}</li>").join("")}
                        </ul>
                    </div>
                </div>

                <div class="tech-container">
                    <h3>Tech Stack</h3>
                    <div class="tech-stack">
                        ${s.techStack.map((tag) => '<span class="tech-tag">${_escapeHtml(tag)}</span>').join('')}
                    </div>
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

  String _getMaturityBg(String maturity) {
    if (maturity.contains('Production Ready') || maturity.contains('Stable')) {
      return 'var(--accent-green)';
    } else if (maturity.contains('Experimental')) {
      return 'var(--accent-blue)';
    }
    return 'var(--accent-purple)'; // Fallback color that fits the scheme
  }
}
