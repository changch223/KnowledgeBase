<!--
SYNC IMPACT REPORT
==================
Version: 1.0.0 (initial ratification)

Note: Earlier files at this path were exploratory template fills produced
during project scaffolding. They never went into operational use and are
treated as pre-ratification drafts, not as versioned predecessors. This
document is the project's authoritative initial constitution.

Primary principles (7, in Japanese):
- I.   プライバシーファースト・ローカルファースト
- II.  MVP ファースト開発
- III. ソースに基づいた知識生成
- IV.  iOS の実現可能性を重視する
- V.   シンプルで落ち着いた UX
- VI.  保守しやすい SwiftUI アーキテクチャ
- VII. 日本語ファースト

Sections under Additional Constraints:
- 対応プラットフォームと端末 (iOS/iPadOS 26+, Apple Intelligence-capable devices)
- AI: Apple Foundation Models (第一候補。fallback 実装を持てる設計)
- 記事取り込み戦略 (Share Sheet = MVP required; Shortcuts / Safari Extension = future)
- 技術スタックと依存関係

Secondary Quality Gates (engineering discipline supporting the 7 principles):
- コード品質ゲート / テストゲート / アクセシビリティ・UX 一貫性ゲート / パフォーマンスゲート
- Per-PR ゲート / Spec-driven workflow / Code review

Templates synchronized this PR:
- ✅ .specify/memory/constitution.md     (this file — initial ratification at v1.0.0)
- ✅ .specify/templates/plan-template.md (Constitution Check populated — 7 principle gates + Quality Gates)
- ✅ .specify/templates/spec-template.md (verified — platform-agnostic, no edit needed)
- ✅ .specify/templates/tasks-template.md (verified — phase structure accommodates new work, no edit needed)
- ✅ .specify/templates/checklist-template.md (verified — generic format, no edit needed)
- ✅ CLAUDE.md (verified — already directs to active plan, no edit needed)

Deferred follow-up TODOs (project-file hygiene — NOT part of this constitution PR):
- TODO: KnowledgeTree.xcodeproj — TARGETED_DEVICE_FAMILY currently "1,2,7" includes
  Apple TV (7). MVP target is iPhone+iPad only → narrow to "1,2".
- TODO: KnowledgeTree.xcodeproj — MACOSX_DEPLOYMENT_TARGET = 26.2 present despite
  Principle IV declaring macOS as future. Either remove the macOS destination or
  document why it remains as a build-only artifact.
- TODO: KnowledgeTree.xcodeproj — Confirm IPHONEOS_DEPLOYMENT_TARGET is 26.0+
  (currently 26.4 ✓) and that Apple Intelligence capability/entitlement is enabled.

Next quarterly review (per Governance): 2026-08-04.
Ratification date: 2026-05-04 (initial adoption).
-->

# KnowledgeTree Constitution

## Core Principles

### I. プライバシーファースト・ローカルファースト

ユーザーの記事データ、要約、タグ、知識ベースは、原則としてローカル端末内に保存する。
MVP では、明確な必要性があり、仕様書 (`spec.md`) 上で送信先・データ種別・必要性が
明記されていない限り、記事本文やユーザーデータを外部サーバーに送信しない。
外部送信が発生する場合は、`plan.md` の Constitution Check で根拠を記録すること。

**根拠**: 個人の知識ベースは機微情報を含みうるため、デフォルトで端末外に出さない設計が
ユーザー信頼の前提となる。

### II. MVP ファースト開発

完璧なフル機能版を最初から目指すのではなく、現実的に開発・検証できる MVP を優先する。
初期バージョンでは、信頼性の高い記事保存、本文抽出、要約、カテゴリ分類、ローカル保存、
ソース記事の閲覧を中心に開発する。高度な自動化、AI チャット、RAG、レコメンド機能は、
段階的に設計・実装する。MVP スコープ外の機能は `plan.md` で将来フェーズとして
明示的に分離すること。

**根拠**: 個人開発者の限られたリソースを集中させ、検証可能な価値を早期に届けるため。

### III. ソースに基づいた知識生成

すべての要約、インサイト、AI 回答は、元記事 URL（または保存済み記事の `Article` ID）
に追跡できるようにする。データモデル上、AI 生成物は元記事への非 optional な参照を
保持しなければならない。根拠となるソースがない推測や unsupported claims を生成しない。
ユーザーが AI の回答を見たとき、どの記事に基づく内容なのかを UI 上で確認できる
ようにする。

**根拠**: ソース無し AI 出力はハルシネーションの温床であり、知識管理アプリの信頼性を
直接損なう。データモデル層で参照を強制することで、設計時点で根拠なし生成を防ぐ。

### IV. iOS の実現可能性を重視する

iOS プラットフォームの制約を尊重する。MVP では、Share Sheet / Share Extension を
主要な記事取り込み方法とする。Chrome / Safari の完全自動取り込みや Shortcuts による
自動化は、実現可能性が確認できるまではオプション機能または将来機能として扱う。
MVP の主対象は iOS (iPhone + iPad) とする。macOS 対応は将来拡張として扱う。

**根拠**: iOS のサンドボックス制約上、ブラウザからの完全自動取り込みは技術的リスクが
高い。Share Sheet は OS 提供の確実な経路であり、まずここを完成度高く実装する。

### V. シンプルで落ち着いた UX

このアプリは、ユーザーの情報過多や未読記事への不安を増やすのではなく、軽減するための
ものである。UI は、要約、知識の成長、すきま時間での素早い理解を重視する。片手操作、
移動中の利用、短時間での確認を前提に設計する。未読数バッジ等の不安喚起 UI を導入する
場合は `spec.md` で理由を明記すること。

**根拠**: 「読んでない記事が溜まる」体験は既存サービスで飽和しており、本アプリの差別化は
読了プレッシャーを与えない静かな UX にある。

### VI. 保守しやすい SwiftUI アーキテクチャ

UI、データモデル、記事取り込み、本文抽出、AI 処理、カテゴリ分類、ローカル保存を
明確に分離する。1つの巨大な SwiftUI View に処理を詰め込まない。個人開発者でも理解・
保守・拡張しやすい構成にする。将来的に AI モデルやデータ保存方法を差し替えられるよう、
処理層の境界をプロトコル等で疎結合にする。

**根拠**: Apple Foundation Models が将来差し替わる可能性 (オンデバイス強化、サーバー
モデル併用、別フレームワーク移行) を見越し、AI 処理層は他層から隔離しておく。

### VII. 日本語ファースト

本プロジェクトの仕様書、設計ドキュメント、UI 文言、サンプルデータ、カテゴリ名、
エラーメッセージ、オンボーディング文言は、原則として日本語を主言語とする。
ユーザー体験は日本語ユーザーを主対象として設計する。記事本文は日本語を中心に扱う。
ただし、英語記事も保存・要約できる余地を残す。多言語対応は将来拡張として設計してよいが、
MVP では日本語 UX の完成度を優先する。

**根拠**: 主対象ユーザーが日本語話者であり、要約・カテゴリ分類の品質は言語依存である。
最初から日本語に最適化した方が、後から多言語化するより成果物の質が高い。

## Additional Constraints

### 対応プラットフォームと端末

- **OS**: iOS 26+ / iPadOS 26+ のみ (MVP)。macOS は対象外 (将来検討)。
- **対応端末**: Apple Foundation Models (Apple Intelligence) が動作する端末のみサポート。
  - iPhone: iPhone 15 Pro / 15 Pro Max、iPhone 16 シリーズ以降。
  - iPad: iPad mini (A17 Pro)、および M1 以降の iPad Pro / iPad Air。
- **Apple Intelligence の有効化**: ユーザー側で Apple Intelligence が有効化されている
  必要がある。アプリは未有効化・非対応端末で起動された場合のフォールバック UX を
  提供しなければならない (詳細は次節)。

### AI: Apple Foundation Models

- **基本方針**: **Apple Foundation Models** (`import FoundationModels`) を第一候補と
  する。ただし、非対応端末・Apple Intelligence 未有効・モデル未ダウンロード等の場合に
  備え、`AIProcessingService` (Principle VI に従ったプロトコル境界) は mock / fallback
  実装を持てる設計にする。MVP では外部 AI API は使用しない。
- **可用性チェック**: 利用前に `SystemLanguageModel.availability` を必ずチェックする。
  `.available` 以外の状態 (端末非対応、Apple Intelligence 未有効、モデル未ダウンロード等)
  では、要約・分類機能を無効化または fallback 実装に切り替え、ユーザーに状況と次の
  アクション (端末確認 / 設定への導線) を日本語で説明する。
- **構造化出力**: 構造化出力には `@Generable` マクロを使用し、ストリーミングは
  `PartiallyGenerated<T>` スナップショットで表示する。
- **アーキテクチャ境界**: AI 処理層は他層から隔離されたプロトコル境界の背後に置き、
  Foundation Models 実装・mock 実装・将来の代替実装を差し替え可能にする。

### 記事取り込み戦略

優先順位は以下の通り。MVP で **必須** なのは Share Sheet のみ。残り 2 つは設計上の
拡張余地として整備し、実現可能性が確認できたフェーズでリリースする。

1. **iOS Share Sheet** (MVP 必須) — 2 タップ (共有 → アプリ選択)。Chrome を含む
   あらゆるアプリから利用可能な確実な経路。メインの取り込み手段とする。
2. **iOS Shortcut 自動化** (将来 / オプション) — 初回設定のみ。例: 「Chrome で記事を
   開いたら自動送信」。実現可能性が確認できるまでオプション機能または将来機能扱い。
3. **Safari Extension** (将来 / オプション) — Safari からの記事情報取得 (本文・URL・
   メタデータ) を Safari Extension 経由で行う。MVP ではスコープ外。

### 技術スタックと依存関係

- 言語: Swift 5.9+。UI: SwiftUI。永続化: SwiftData (`@Model`, `ModelContainer`)。
- サードパーティ依存: 原則なし。導入する場合は `plan.md` の Complexity Tracking で
  Apple 標準 API では不十分な理由を記録すること。
- 並行処理: Swift Structured Concurrency のみ。GCD (`DispatchQueue`) は新規コードで
  禁止。既存利用は触れた際に移行する。
- 永続化先: SwiftData が単一の真実の源。CoreData 直接利用、`UserDefaults` の
  非自明な用途、ファイルシステム JSON は主アプリ状態には禁止。

## Development Workflow & Quality Gates

これらは **二次的な品質ゲート** であり、Core Principles を実現するための実装規律である。
PR レビュー時に各項目をチェックする。

### コード品質ゲート

Swift API Design Guidelines に準拠する。死コード、コメントアウトされたブロック、
投機的抽象化を含めない。`fatalError` / `try!` / 強制アンラップ (`!`) は `App`
レベルのコンテナ初期化 (例: `ModelContainer` 構築) のみ許容。新規抽象化 (protocol /
generic / property wrapper) は導入時点で 2 箇所以上の利用、または `plan.md` での
近期計画記載を必須とする。

### テストゲート

すべてのユーザー可視機能は、`KnowledgeTreeTests/` の単体テストと
`KnowledgeTreeUITests/` の主要受け入れシナリオ UI テストの両方を伴って出荷する。
SwiftData を扱うコードは `isStoredInMemoryOnly: true` の `ModelContainer` で
テストし、ディスクストアには触れない。UI テストは `accessibilityIdentifier` で
要素を特定し、ローカライズ文字列に依存しない。テストは決定論的であること
(実ネットワーク禁止、`Date` 等は注入)。

### アクセシビリティ・UX 一貫性ゲート

iOS / iPadOS 上で一貫した体験を提供する。全
インタラクティブ要素に `accessibilityIdentifier` を付与し、Dynamic Type / Dark Mode /
VoiceOver に対応する。SF Symbols とネイティブ SwiftUI コントロールを優先し、
カスタムコントロールはシステムカタログに該当がない場合のみ。すべてのユーザー向け
文字列は `LocalizedStringKey` 経由で `Localizable.xcstrings` から取得する
(View body 内の生文字列リテラルは禁止)。状態遷移は `withAnimation { ... }` で
包む。

### パフォーマンスゲート

ユーザー入力に対して 100 ms 以内に視覚フィードバックを返す。超える処理は Swift
Concurrency でメインスレッド外へ。コールド起動はベースライン端末で 2 秒以内、
200 ms 超の悪化は merge 前に調査。SwiftData `@Query` は predicate または明示的
`fetchLimit` で結果サイズを境界付ける (View body 内の無境界クエリは禁止)。100 件
超を表示する `List` / `ScrollView` は Instruments (Time Profiler + SwiftUI
テンプレート) で 60 fps 維持を実測し、結果を PR に添付する。`self` をキャプチャする
escaping closure は documented invariant がない限り `[weak self]` を使う。

### Per-PR ゲート (マージ前必須)

1. iOS / iPadOS スキームで警告ゼロビルド。
2. `KnowledgeTreeTests` と `KnowledgeTreeUITests` が `xcodebuild test` で全 pass。
3. 機能 PR は対象 `plan.md` の Constitution Check が完了し、未チェック項目に
   Complexity Tracking で justification がある。
4. UI 影響 PR は iPhone と iPad 両方のスクリーンショットまたは画面録画を PR 説明に
   添付する。
5. パフォーマンス影響 PR (List / ScrollView / SwiftData クエリ / 起動経路) は
   Principle IV / パフォーマンスゲートが要求する Instruments 計測結果を添付する。

### Spec-driven workflow (順序遵守)

`/speckit-specify` → `/speckit-clarify` (曖昧性がある場合) → `/speckit-plan` →
`/speckit-tasks` → `/speckit-implement`。スキップは PR 説明で justification 必須。

### Code review

各 PR は最低 1 名のレビュアーが Core Principles 7 項目および Quality Gates 各項目への
適合を明示的に確認する。"LGTM" のみの承認は無効。

## Governance

本 Constitution は KnowledgeTree コードベースに対する他のすべての engineering
practice / convention / preference に優先する。チュートリアル・サンプル・
サードパーティガイドと矛盾する場合、本ドキュメントが勝つ。

**改定手続き**: 改定は `.specify/memory/constitution.md` および Sync Impact Report に
列挙された依存テンプレートを変更する PR で提案する。PR 説明には (a) バージョンバンプ
と根拠、(b) 進行中機能への移行影響、(c) プロジェクトオーナーのサインオフを記載する。

**バージョニングポリシー** (semantic):

- **MAJOR**: Core Principle の削除または backward-incompatible な再定義、あるいは過去の
  compliance approval を無効化するガバナンス変更。
- **MINOR**: 新 Principle の追加、または既存 Principle の必須ガイダンスの実質的拡張。
- **PATCH**: 文言修正、誤字、非意味的な refinement。

**コンプライアンスレビュー**: `/speckit-plan` の各起動時に Constitution Check ゲートを
必ず実行する。`/speckit-analyze` は本ドキュメントと矛盾する artifact をフラグする。
ratification 日から 3 ヶ月ごと (次回: **2026-08-04**) に、プロジェクトオーナーは本
Constitution を end-to-end で読み返し、再承認するか改定 PR を起こす。

**Runtime guidance**: 各機能の能動的なエンジニアリングコンテキストはその機能の
`specs/<branch>/plan.md` に置かれる。リポジトリルートの `CLAUDE.md` が contributor と
AI agent を現在の plan に誘導する。

**Version**: 1.0.0 | **Ratified**: 2026-05-04 | **Last Amended**: 2026-05-04
