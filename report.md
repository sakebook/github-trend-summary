# GitHub Trending Summary
Generated on: 2026-02-06 20:46:19 (JST)

## [vueuse/skills](https://github.com/vueuse/skills)
- **Stars**: 304
- **Language**: TypeScript

> VueUseのメタデータをAIエージェント向けに最適化し、トークン節約と精度向上を図る「エージェント用スキル」

### 活用シーン
AIエージェント（Claude Code等）がVueUseの膨大な関数群を正確に理解し、ハルシネーションを抑えつつ、最小限のトークン消費でVue/Nuxtのコードを生成・修正する開発環境。

### 主要機能
- Progressive Disclosure: 関数概要を先に送り、詳細な型や使用法はオンデマンドで読み込む段階的情報提供
- Minimal Token Usage: エージェントが必要な情報のみを抽出・加工し、コンテキスト窓の消費を最小化
- Offline-first Design: インターネット接続や外部権限なしで、ローカルの定義ファイルから正確なAPI参照が可能
- Hallucination Reduction: 存在しないAPIの捏造を防ぐため、厳密なメタデータに基づいた実在する関数情報を提供

### 実装のこだわり
【メタデータの二次加工】@vueuse/metadataをソースに、AIが理解しやすい形式へ変換する独自ビルド（build.ts）を採用。【コンテキスト制御】AGENTS.mdやプロンプトによる関数呼び出しルールのカスタマイズを許容。本家VueUseリポジトリをサブディレクトリとして保持し、常に最新の公式定義に同期させる強固なデータ構造。

### 開発状況
**Experimental (実験的)**

### 技術スタック
`TypeScript`, `Node.js (tsx)`, `pnpm Workspace`, `@vueuse/metadata`, `Claude Code Marketplace`, `LLM Agent Skills`

### 競合差別化
従来のRAG（検索）や巨大なコンテキスト注入とは異なり、関数の「概要」と「詳細（型・使用法）」を段階的に提供するProgressive Disclosureを採用し、コストと精度を両立させている点。

---

## [dwzhu-pku/PaperBanana](https://github.com/dwzhu-pku/PaperBanana)
- **Stars**: 2083
- **Language**: JavaScript

> AI論文向けの複雑な学術図解（アーキテクチャ図等）を自動生成し、研究者の製図負荷を軽減するツール

### 活用シーン
論文執筆時において、テキストベースのモデル解説や数式から、トップ会議（CVPR/NeurIPS等）に耐えうる高品質なアーキテクチャ図を生成するシーン

### 主要機能
- 学術図解の自動生成: 論文の抄録や手法説明から、視覚的なダイアグラムを自動構築
- AI研究者特化: ニューラルネットワークの階層構造やデータフローなど、専門的な表現に最適化
- 専用データセットの活用: 質の高い論文図解から学習したモデルによる、学術的コンテキストの維持

### 実装のこだわり
「Datasetを公開予定」という点から、単なるプロンプトエンジニアリングではなく、学術図解の構造を理解させるためのファインチューニングや、専門的なRAG（検索拡張生成）の実装が示唆される

### 開発状況
**Active Development (開発中)**

### 技術スタック
`Python`, `Large Language Models (LLMs)`, `LaTeX/TikZ (推測)`, `Vector Graphics Generation`, `Diffusion Models (推測)`

### 競合差別化
汎用的な画像生成AI（DALL-E等）が苦手とする「学術的な正確性」と「編集可能なベクトル形式（TikZ等）」の提供による、実用的なワークフローへの統合

---

## [tldev/posturr](https://github.com/tldev/posturr)
- **Stars**: 1883
- **Language**: Swift

> VisionとAirPodsのモーションセンサーを活用し、OSレベルの動的ブラーで姿勢を正すmacOS専用ツール。

### 活用シーン
長時間のコーディング中に無意識に猫背になるのを防ぐため、通知ではなく「視覚情報の制限」という物理的なフィードバックで姿勢を矯正したいシチュエーション。

### 主要機能
- ハイブリッド・トラッキング: Visionによる画像解析（鼻/頭の位置）とCoreMotionによるAirPodsの頭部傾斜検知の両立。
- プログレッシブ・フィードバック: 姿勢の悪化に連動してブラーの強度を段階的に高める、自然かつ効果的なユーザー体験。
- 堅牢なフォールバック設計: プライベートAPIが動作しない環境向けに、NSVisualEffectViewを用いた互換モードを標準搭載。

### 実装のこだわり
デフォルトでPrivate CoreGraphics APIを選択し、低負荷かつマルチディスプレイ対応のシステムブラーを実現するこだわり。また、/tmp/posturr-command を介したファイルベースのIPCにより外部制御を可能にするなど、ハッカーライクな拡張性が組み込まれている。SwiftPMによるモジュール分離（Core/App）でテスト容易性も考慮されている。

### 開発状況
**Active Development**

### 技術スタック
`Swift 5.9`, `Vision Framework`, `CoreMotion`, `CoreGraphics (Private API)`, `SwiftUI`, `AppKit`, `Swift Package Manager`

### 競合差別化
通知のみの既存ツールに対し、CoreGraphicsのプライベートAPIを用いたシステム全体の動的ブラーによる強制力と、AirPodsのジャイロを利用したカメラ不要の追跡機能で差別化。

---

## [NeptuneHub/AudioMuse-AI-NV-plugin](https://github.com/NeptuneHub/AudioMuse-AI-NV-plugin)
- **Stars**: 63
- **Language**: Go

> WASMとExtism PDKを採用し、NavidromeにAIレコメンデーション機能を統合するプラグイン

### 活用シーン
セルフホスト型音楽サーバーNavidromeにおいて、既存の静的なタグ管理を超え、AIによる楽曲・アーティストの類似度に基づいた動的な音楽発見体験を実現する際。

### 主要機能
- Instant Mix: 楽曲の類似性をAIで判定し、関連性の高い楽曲によるインスタントプレイリストを生成
- Radio Mode: 特定のアーティストに類似したアーティストを抽出し、パーソナライズされたラジオ機能を提供
- Artist Info Enrichment: 外部のAudioMuse-AIコアから類似アーティスト情報を取得し、メタデータを拡張

### 実装のこだわり
【WASMネイティブ】TinyGoとExtismを採用し、プラグインを.ndp (WASMバイナリ) として配布する近代的な設計。 【疎結合なAI連携】重い処理はFlaskベースの外部コアに逃がし、プラグイン側はNavidromeのPlugin Development Kit (PDK) に準拠したブリッジに徹する責務分離の徹底。 【Subsonic API互換性】getSimilarSongs2等の標準的なAPIにマッピングすることで、既存のモバイルクライアント側への変更を最小限に抑える設計思想。

### 開発状況
**Active Development**

### 技術スタック
`Go / TinyGo`, `WebAssembly (WASM)`, `Extism PDK`, `Navidrome Plugin SDK`, `Flask (AudioMuse-AI Core)`

### 競合差別化
従来のLast.fmやSpotify等の外部API依存のメタデータ補完とは異なり、独自のAudioMuse-AIコア（Flask/Worker構成）と連携。WASMによるサンドボックス実行により、ホスト環境を汚染せず高セキュアかつポータブルなプラグイン導入が可能。

---

## [m1heng/clawdbot-feishu](https://github.com/m1heng/clawdbot-feishu)
- **Stars**: 2640
- **Language**: TypeScript

> OpenClawを飛書/Larkへ統合し、ユーザー毎の隔離された環境と高度なツール群を提供するプラグイン。

### 活用シーン
企業内飛書環境において、ユーザー間でファイルやメモリを完全に分離・隔離した、セキュアなマルチテナント型AIエージェントを構築・提供するシーン。

### 主要機能
- WebSocket（長接続）とWebhookの両モードに対応した柔軟な接続性
- dynamicAgentCreationによる、ユーザー毎の独立したWorkspace/MEMORY.mdの動的生成
- 飛書Doc/Drive/Wiki/Bitableへアクセスする高度なSkills（Agentツール）群の提供
- Markdownの構造解析に基づく、リッチテキストカードとプレーンテキストの自動切り替え描画
- 権限エラーを検知し、ユーザーへ認可URLを自動提示するセルフサービス型のエラーハンドリング

### 実装のこだわり
飛書のAPIレート制限を考慮し「安定性のためにあえて非ストリーミング（complete-then-send）」を選択。WebSocket採用による疎結合なデプロイ、および`workspaceTemplate`を用いたファイルシステムレベルでのコンテキスト隔離に、エンタープライズ運用を強く意識した設計思想が表れている。

### 開発状況
**Active Development**

### 技術スタック
`TypeScript`, `Node.js (ESM)`, `@larksuiteoapi/node-sdk`, `OpenClaw Framework`, `TypeBox`, `Zod`

### 競合差別化
単なるチャットIFではなく、Wiki/Bitable/Drive等の飛書エコシステムへのCRUD操作を標準提供。さらにOpenIDに基づいた動的なAgent/ディレクトリ生成により、物理的なマルチテナント分離を実現している点が独自のエッジ。

---

