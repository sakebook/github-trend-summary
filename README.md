# GitHub Trend Summary

GitHubのトレンドリポジトリを自動で収集し、Gemini AIを使って日本語で要約を生成するプロジェクトです。

## 特徴

- **複数条件での収集**: 特定の言語（Dart, TypeScript, Rust等）やトピック（AI, LLM等）に基づいたトレンド検索。
- **AI要約**: Google Gemini APIを使用して、リポジトリの内容を日本語で分かりやすく要約。
- **マルチフォーマット出力**: Markdown, RSS, HTML形式での出力に対応。
- **自動実行**: GitHub Actionsによる定期的なレポート生成。

## ローカルでの実行方法

### 準備

1.  [Gemini API Key](https://aistudio.google.com/app/apikey) を取得します。
2.  (任意) GitHub APIのレート制限を回避するため、Personal Access Tokenを取得します。

### 実行

```bash
dart pub get
dart bin/main.dart \
  --lang dart,typescript \
  --topic ai,llm \
  --gemini-key YOUR_GEMINI_KEY \
  --github-token YOUR_GITHUB_TOKEN \
  --output report.md
```

## GitHub Actions ワークフロー

このプロジェクトは現在、単一の統合されたワークフローで運用されています：

- **Trending Intelligence (`trending_report.yml`)**:
    - **定期実行**: 毎日実行され、幅広い言語（Dart, Rust, Go等）とAI関連トピックのレポートを生成します。
    - **成果物**: 生成されたレポートは GitHub Actions のアーティファクトとして保存されるほか、GitHub Pages にも自動デプロイされます。
    - **手動実行**: 必要に応じて、対象とする言語やトピックを指定してカスタムレポートを生成することも可能です。
