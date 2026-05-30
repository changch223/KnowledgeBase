# KnowledgeTree 全コードベース監査レポート (Codebase Audit Report)

**監査日時**: 2026年5月28日
**対象**: KnowledgeTree プロジェクト全域

本ドキュメントは、アプリの全対象ファイル、コード規模、テスト網羅性、ローカライズ状況、ビルド設定、およびAIやUI/UXに潜む主要な危険パターン（Technical Debt）を包括的に整理した監査レポートです。

---

## 1. コードベース統計 (Codebase Statistics)

全体を走査した結果、プロジェクトは以下の規模で構成されています。

| 項目 | 数値 / パス | 備考 |
| :--- | :--- | :--- |
| **Swiftファイル総数** | 248 ファイル | `Views/`, `Services/`, `Models/` などの主要コード群 |
| **総コード行数** | 73,816 行 | 空行・コメントを含む全体規模 |
| **テストファイル数** | 66 ファイル | `*Tests.swift` の総数 |
| **テストケース数** | 334 ケース | `func test` で定義された単体・UIテストの総数 |
| **ローカライズ** | 1 ファイル | `KnowledgeTree/Localization/Localizable.xcstrings` に一元管理 |

### ビルド設定・Entitlements
アプリ本体に加えて、3つのExtensionターゲットが正しく構成されており、App GroupおよびiCloud (CloudKit) の権限が付与されています。
- `./KnowledgeTree/KnowledgeTree.entitlements` (本体)
- `./KnowledgeTreeShareExtension/KnowledgeTreeShareExtension.entitlements` (Share Extension)
- `./KnowledgeTreeSafariExtension/KnowledgeTreeSafariExtension.entitlements` (Safari Extension)
- `./iKnowWidgetExtension.entitlements` (Widget)

---

## 2. 主要危険パターン (Major Danger Patterns)

サブエージェントによるディープスキャン（Models, Services, Views 全層）の結果、以下のアーキテクチャ上の欠陥やバグの温床となるパターンが発見されました。これらはデータ量の増加や長期間の運用によって、**クラッシュ、フリーズ、APIコスト増大**を引き起こすクリティカルな問題です。

### 2.1 致命的なパフォーマンス・メモリ問題 (Critical Performance)
*   **SwiftDataの全件インメモリスキャン:**
    *   **箇所**: `ChatTabView.swift`, `ConceptSynthesisService.swift`, `KnowledgeClipView.swift`
    *   **問題**: `#Predicate` を使用してSQLiteレベルでフィルタリングせず、すべてのエンティティ（全メッセージ、全記事など）をメモリにロード（`@Query` や `fetch`）してから、Swiftの `filter` で絞り込んでいます。
    *   **影響**: ユーザーの蓄積データが数百〜数千件に達した時点で、アプリのフリーズやOOM (Out Of Memory) クラッシュを確実に引き起こします。

### 2.2 データモデルとデータリーク (Data Model Integrity)
*   **カスケーディング削除の欠落 (Orphaned Data):**
    *   **箇所**: `Article.swift` の `conflictsAsNew` および `conflictsAsOld`
    *   **問題**: リレーションシップに `deleteRule: .cascade` が明記されていません。
    *   **影響**: `Article` を削除した際、それに紐づいていた `ConflictProposal` がデータベース内に「孤児データ（Orphan）」として残置され、永遠にストレージを圧迫します。
*   **Optional Collectionによる述語クラッシュ:**
    *   **箇所**: `KnowledgeDigestService.swift` など
    *   **問題**: `#Predicate` 内部で `article.tags?.contains { ... } ?? false` のようなOptional型の展開を行っています。
    *   **影響**: SwiftDataの基盤であるCore Data / SQLiteはこのような複雑なクロージャ変換に弱く、ランタイムクラッシュ（EXC_BAD_ACCESS）のトリガーになります。

### 2.3 ビジネスロジックとAIループの欠陥 (Logic Bugs)
*   **AI回答の無限再生成ループ:**
    *   **箇所**: `LintEngine.swift` (`stepRefreshStaleSavedAnswers`)
    *   **問題**: AIへ再生成リクエスト（`ChatService.send`）を非同期のまま投げ放しにし、元の回答の `isStale` を `false` にリセットするのを待っていません。
    *   **影響**: 次回のLintループでも同じ回答が再度「古い（Stale）」と判定され、AI API（LLM）へのリクエストが無限に走り続け、利用コストが暴騰する危険性があります。
*   **最新50件のハードリミット:**
    *   **箇所**: `ChatService.swift` (`fetchArticlesInCategory`)
    *   **問題**: カテゴリのフィルタリングをかける**前**に `fetchLimit = 50` を適用しています。
    *   **影響**: 全体で最新50件の記事しか検索対象にならず、それ以前に保存された特定のカテゴリの古い記事はAIから完全に無視（見落とし）されます。

### 2.4 UI/UXライフサイクルとアンチパターン (Lifecycle Bugs)
*   **非同期タスクの未キャンセル (Ghost Updates):**
    *   **箇所**: `ChatTabView.swift` (擬似ストリーミング処理)
    *   **問題**: `for` ループ内で `Task.sleep` を使っていますが、`Task.isCancelled` のチェックがありません。
    *   **影響**: ユーザーがストリーミング中に別の画面やチャットに切り替えても裏でループが回り続け、新しい画面に予期せぬ文字が混入します。
*   **トグルのバウンスバグ (Toggle Bounce):**
    *   **箇所**: `SettingsView.swift`
    *   **問題**: iCloud同期トグルの `Binding(get:set:)` 内で、値を保存せずにアラートを表示しています。
    *   **影響**: タップした瞬間にスイッチが元の状態に弾き戻される（バウンスする）UIバグが発生しています。
*   **タイマーによる強制再描画 (Timer Anti-Pattern):**
    *   **箇所**: `ArticleDetailView.swift`
    *   **問題**: 1.0秒間隔の `pollTimer` で `refreshTick` を回し、`.id(refreshTick)` を使ってView全体を無理やり再構築しています。
    *   **影響**: SwiftUIの効率的な差分更新メカニズムを破壊し、無駄なCPU消費とバッテリーの枯渇を招きます。

---

## 3. 推奨アクションプラン

この監査結果に基づき、以下の順序で技術的負債の解消（リファクタリング）を進めることを強く推奨します。

1.  **データ整合性の確保**: `Article.swift` への `.cascade` 追加、および述語でのOptional Collection回避。
2.  **LintEngineの無限ループ防止**: 非同期タスクの適切な `await` と `isStale` リセット処理の確実な実行。
3.  **SwiftData Queryの最適化**: `ChatTabView` や `ConceptSynthesisService` での全件フェッチを辞め、適切な `#Predicate` によるSQLite層での絞り込みへ移行。
4.  **UIの健全化**: トグルバウンスの修正、タスクキャンセルの徹底、`pollTimer` アンチパターンの排除。
