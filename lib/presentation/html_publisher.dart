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
        .main-header {
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
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            border: 1px solid var(--card-border);
            border-top: 1px solid var(--glass-border);
            border-radius: 24px;
            padding: 48px;
            margin-bottom: 48px;
            transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
            position: relative;
            overflow: hidden;
            animation: fadeInUp 0.8s ease-out backwards;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        .repo-card:hover {
            transform: translateY(-8px);
            border-color: var(--accent);
            box-shadow: 0 30px 60px rgba(0,0,0,0.5), 0 0 20px var(--accent-glow);
        }
        /* New Layout Sections */
        .card-inner {
            display: grid;
            grid-template-columns: 1fr;
            gap: 32px;
        }
        .main-info {
            display: grid;
            grid-template-columns: 1fr;
            gap: 20px;
        }
        .metadata-section {
            background: rgba(255, 255, 255, 0.02);
            border-radius: 16px;
            padding: 24px;
            border: 1px solid var(--card-border);
        }
        .insight-tag {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 4px 12px;
            background: var(--accent-soft);
            color: var(--accent);
            border-radius: 100px;
            font-size: 0.75rem;
            font-weight: 700;
            margin-bottom: 12px;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }
        .repo-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 8px;
        }
        .header-left {
            display: flex;
            flex-direction: column;
            gap: 12px;
        }
        .maturity-badge {
            font-size: 0.7rem;
            padding: 2px 10px;
            border-radius: 6px;
            font-weight: 600;
            width: fit-content;
        }
        .repo-name {
            font-size: 2rem;
            font-weight: 800;
            text-decoration: none;
            color: #fff;
            letter-spacing: -0.02em;
            transition: color 0.3s;
        }
        .repo-name:hover {
            color: var(--accent);
        }
        .stars {
            color: var(--star);
            font-weight: 700;
            font-size: 1.1rem;
            display: flex;
            align-items: center;
            gap: 6px;
            background: rgba(240, 136, 62, 0.1);
            padding: 6px 14px;
            border-radius: 12px;
        }
        .repo-description {
            color: var(--text-dim);
            font-size: 1rem;
            margin: 0;
            line-height: 1.5;
        }
        .summary-box {
            font-size: 1.1rem;
            color: var(--text-main);
            margin: 0;
            line-height: 1.6;
        }
        .grid-sections {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 32px;
        }
        @media (max-width: 768px) {
            .grid-sections { grid-template-columns: 1fr; }
            .repo-card { padding: 32px; }
        }
        .section-item h3 {
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.1em;
            color: var(--accent);
            margin: 0 0 12px 0;
            opacity: 0.8;
        }
        .section-item p, .section-item li {
            margin: 0;
            font-size: 0.95rem;
            color: var(--text-main);
            line-height: 1.7;
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
        <header class="main-header">
            <h1>Trending Intelligence</h1>
            <p class="header-sub">Daily GitHub analysis powered by Gemini AI</p>
            <div class="update-time">Last Updated: ${DateTime.now().toUtc().add(const Duration(hours: 9)).toString().split('.')[0]} (JST)</div>
        </header>

        <main>
''');

      for (final s in summaries) {
        final repo = s.repository;
        buffer.writeln('''
            <div class="repo-card">
                <div class="card-inner">
                    <header class="repo-header">
                        <div class="header-left">
                            <div class="maturity-badge" style="background:${_getMaturityBg(s.maturity)}; color:${_getMaturityColor(s.maturity)}; border:1px solid ${_getMaturityColor(s.maturity)};">
                                ${_escapeHtml(s.maturity)}
                            </div>
                            <a href="${repo.url}" class="repo-name" target="_blank">${_escapeHtml(repo.owner)} / ${_escapeHtml(repo.name)}</a>
                            <p class="repo-description">${_escapeHtml(repo.description ?? 'No description provided')}</p>
                        </div>
                        <span class="stars">⭐ ${repo.stars}</span>
                    </header>

                    <div class="main-info">
                        <p class="summary-box">${_escapeHtml(s.summary)}</p>

                        <div class="grid-sections">
                            <div class="section-item">
                                <h3>活用シーン / Use Case</h3>
                                <p>${_escapeHtml(s.useCase)}</p>
                            </div>
                            <div class="section-item">
                                <h3>競合差別化 / Competitive Edge</h3>
                                <p>${_escapeHtml(s.rivalComparison)}</p>
                            </div>
                        </div>
                    </div>

                    <div class="metadata-section">
                        <div class="insight-tag">
                            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path><polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline><line x1="12" y1="22.08" x2="12" y2="12"></line></svg>
                            Deep Technical Insight
                        </div>
                        <div class="section-item">
                            <h3>実装のこだわり / Implementation Flavor</h3>
                            <p>${_escapeHtml(s.implementationFlavor)}</p>
                        </div>
                        
                        <div class="section-item" style="margin-top: 24px;">
                            <h3>主要機能 / Key Features</h3>
                            <ul style="margin-top: 8px; padding-left: 20px;">
                              ${s.keyFeatures.map((f) => "<li>${_escapeHtml(f)}</li>").join("")}
                            </ul>
                        </div>

                        <div class="tech-stack">
                            ${s.techStack.map((tag) => '<span class="tech-tag">${_escapeHtml(tag)}</span>').join('')}
                        </div>
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
      return 'rgba(46, 160, 67, 0.1)';
    } else if (maturity.contains('Experimental')) {
      return 'rgba(210, 153, 34, 0.1)';
    }
    return 'var(--accent-soft)';
  }

  String _getMaturityColor(String maturity) {
    if (maturity.contains('Production Ready') || maturity.contains('Stable')) {
      return '#3fb950';
    } else if (maturity.contains('Experimental')) {
      return '#d29922';
    }
    return 'var(--accent)';
  }
}
