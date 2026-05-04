# Research: 本文取得・メタデータエンリッチメント — Phase 0

**Feature**: spec 002 — 本文取得・メタデータエンリッチメント
**Date**: 2026-05-04
**Status**: Complete (全 NEEDS CLARIFICATION 解決)

---

## R1. HTML パーサ選定 (サードパーティ禁止下)

**Decision**: **Foundation の `String` API + 軽量正規表現** で `<title>` / `<meta name="description">` / `<meta property="og:image">` を抽出する。`WebKit` (`WKWebView`) は使わない。`SwiftSoup` 等のサードパーティは禁止 (Constitution Additional Constraints)。

抽出は `MetadataParser` という pure function struct に集約。テスト時は固定 HTML フィクスチャを直接渡す。

**Rationale**:
- 抽出対象が 3 〜 4 フィールドだけなら、軽量正規表現で十分実用 (典型的な記事ページの HTML に対して 1 ms 未満で完了)。
- `WKWebView` は重量級 (フルブラウザ engine、メモリ ~50 MB+)。enrichment 数百件を順次処理する用途に過剰。
- 純粋な文字列パースなら detached task で main thread を一切ブロックしない。
- サードパーティ依存の追加申請が不要 (Constitution に従い approval プロセスを回避)。

**Alternatives considered**:
- **`WKWebView` で render 後 JavaScript 実行**: 動的に注入された OG image も拾えるが、SPA でない通常記事には不要。enrichment 件数あたりのコストが過剰。
- **`NSAttributedString(data:options:documentAttributes:)` の HTML loader**: rendering を伴うため重い + main thread 制約あり。今回はテキスト rendering 不要なので NG。
- **サードパーティ (`SwiftSoup`)**: 禁止。

---

## R2. URLSession 構成: background vs ephemeral vs default

**Decision**: **`URLSessionConfiguration.background(withIdentifier:)`** を使用。

`identifier` は `com.knowledgetree.enrichment` 固定。`isDiscretionary = false` (ユーザー認知のあるバックグラウンド処理として実行)、`sessionSendsLaunchEvents = true`。

**Rationale**:
- アプリが backgrounded された状態でも、OS が許す範囲で fetch を継続できる (Share Sheet 経由保存後にユーザーがすぐ別アプリに行っても OK)。
- システムが最適なタイミングで実行を schedule してくれるためバッテリー消費が穏当。
- `URLSession.shared` だと foreground 限定で、Share Sheet → 共有完了 → アプリ即終了のフローでジョブが走らない。

**Alternatives considered**:
- **`URLSession.shared` (default)**: foreground 限定。enrichment 完了前にアプリが backgrounded されると停止。
- **`URLSessionConfiguration.ephemeral`**: cookie 等を保持しない privacy-friendly モードだが、background 動作不可。spec 002 は cookie 不要なので ephemeral の利点は薄い。
- **`BGAppRefreshTask` (BackgroundTasks framework)**: より汎用な OS background スケジューラだが、本用途では URLSession background が直接的で十分。

---

## R3. リトライ + exponential backoff の実装

**Decision**: **`ArticleEnrichmentService` 内で手書き実装**。タイマーは `Task.sleep(for: .seconds(...))` を使用。

スケジュール: 30 s → 2 min → 10 min。失敗 3 回で `permanentlyFailed`。再試行は端末オンライン時のみ (`NWPathMonitor` で監視)。

**Rationale**:
- spec の FR-009 を直接実装。サードパーティ retry ライブラリ不要。
- `Task.sleep` は cancellation を respect するため、ネットワーク状態が変わったり ArticleEnrichment が削除されたりしたときに即停止可能。
- `NWPathMonitor` は Apple 公式 framework で軽量。

**Alternatives considered**:
- **OS task scheduler (`BGProcessingTask`)**: より OS 統合的だが、startup latency が大きく retry 単位が「次の OS schedule 時」になり予測困難。
- **third-party retry library**: 禁止。

---

## R4. SwiftData での `ArticleEnrichment` ↔ `Article` relationship

**Decision**: **`ArticleEnrichment` 側に non-optional な `Article` への参照を持たせる**。逆方向 (Article → enrichment) は optional (enrichment 未取得状態を表現するため)。`Article` 削除時に `ArticleEnrichment` も自動削除 (`@Relationship(deleteRule: .cascade)` を Article 側に付与)。

```swift
@Model
final class Article {
    @Attribute(.unique) var id: UUID
    var url: String
    var title: String
    var savedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ArticleEnrichment.article)
    var enrichment: ArticleEnrichment?
    // init 省略
}

@Model
final class ArticleEnrichment {
    @Attribute(.unique) var id: UUID
    var article: Article          // non-optional (Constitution Principle III)
    var status: EnrichmentStatusRaw  // String 永続化 (enum)
    var canonicalTitle: String?
    var summary: String?
    var ogImageURL: String?
    var rawHTML: String?
    var lastFetchedAt: Date?
    var retryCount: Int
    // init 省略
}
```

**Rationale**:
- Principle III の要件を構造的に満たす (enrichment 単独の存在を SwiftData レベルで禁止)。
- cascade delete で Article 削除時に enrichment が孤立しない。
- `enum EnrichmentStatus` は SwiftData で直接保存できないため、`EnrichmentStatusRaw: String, Codable` を別途定義し getter/setter で `EnrichmentStatus` に変換 (data-model.md で詳細)。

**Alternatives considered**:
- **`Article` に `enrichmentMetadata` を直接埋め込む**: 既存 `Article` schema を変更することになり spec 001 のテスト/データを壊しうる。新エンティティ追加で backward-compat を保つ方が安全。
- **External JSON ファイル管理**: SwiftData の単一真実の源原則 (Constitution Additional Constraints) に違反。

---

## R5. ATS / OG image の混在コンテンツ問題

**Decision**: **OG image URL が `http://` の場合は `https://` への自動置換を試み、失敗したら nil として扱う**。混在コンテンツ (HTTPS ページの http img) は ATS で fetch がブロックされるため。

`AsyncImage` レベルで失敗 → `ThumbnailView` がプレースホルダを表示 (layout shift なし)。

**Rationale**:
- ATS (App Transport Security) は Apple 既定で、`NSAllowsArbitraryLoads` を使うと App Store 審査でリスクになる。
- 自動 https 化は単純: URL を生成し直して 200 が返ってくるかは fetch 時に判明。事前 HEAD は不要。
- nil の場合のフォールバック表示は spec.md の Edge Cases に既に定義済み。

**Alternatives considered**:
- **`NSAllowsArbitraryLoadsInMedia`**: 部分的に許可するキーだが、App Store 審査で厳しい質問を受ける可能性あり。Principle II (MVP first) と相性悪。
- **OG image を端末にダウンロードしてキャッシュ**: spec 002 Out of Scope。

---

## R6. SwiftData schema migration (spec 001 → spec 002)

**Decision**: spec 001 が **未リリース** のため、spec 002 で新エンティティ `ArticleEnrichment` を追加する変更は **backward-compatible** (新規 entity 追加 + 既存 entity への optional relationship 追加)。SwiftData の自動 lightweight migration で吸収できる想定。

production リリース後 (spec 002 公開後) の真のマイグレーションは、spec 002 PR の verification phase で `xcodebuild test` + 起動確認を経て対応する。

**Rationale**:
- SwiftData は新規 entity の追加を lightweight migration で対応可能 (Apple ドキュメント confirmed)。
- 既存 Article への optional relationship 追加も backward-compat (default は nil)。
- spec 001 がまだ pre-release であることが、もし migration で問題が出ても dev データを wipe して再開できる安全網になっている。

**Alternatives considered**:
- **明示的な `VersionedSchema` + `MigrationPlan`**: より堅牢だがコード量が増える。spec 002 の変更が backward-compat であれば必須ではない。spec 003 以降で明示マイグレーションが必要になったタイミングで導入予定。

---

## R7. URLSession の I/O を抽象化してテスト容易に

**Decision**: 軽量 `URLSessionProtocol` を定義し、`URLSession` を conform させる。テストでは `MockURLSession` (固定 Data + Response or Error 返却) を使用。

```swift
protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}
extension URLSession: URLSessionProtocol {}
```

`URLProtocol` カスタムサブクラスでもテストできるが、protocol 抽象の方が型安全で実装シンプル。

**Rationale**:
- `ArticleEnrichmentService` のテストで実 HTTP を発生させない (Constitution テストゲート: 実ネットワーク禁止 / 決定論的)。
- protocol 1 メソッドだけなら overhead が無視できる。

**Alternatives considered**:
- **`URLProtocol` サブクラス**: より低レベルで `URLSession` API 全体を intercept できるが、本 spec で必要なのは `data(for:)` 1 つだけなので過剰。

---

## 追加メモ (NEEDS CLARIFICATION なし)

- **背景: backfill 実装のタイミング**: 起動時に「`ArticleEnrichment` が無い `Article`」を SwiftData query で取得し順次キューイング。アプリが既に enrichment ジョブ中なら待機後に追加。
- **rawHTML サイズ判定**: `URLResponse.expectedContentLength` を見て 2 MB 超なら fetch を中止。実 download bytes も最終チェック。
- **User-Agent 文字列の確定**: `KnowledgeTree/1.0 (iOS)` + アプリの marketing バージョンを足す形に拡張可能 (例: `KnowledgeTree/1.0.0 (iOS)`)。Bundle から読み取る簡易ヘルパを `URLSessionProtocol` 利用側に置く。
- **Constitution の deferred TODO** (`TARGETED_DEVICE_FAMILY` / macOS deployment target) は spec 001 の plan で flag 済み。spec 002 では追加で flag しない。
