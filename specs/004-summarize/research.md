# Research: 知識抽出 + 要約 — Phase 0

**Feature**: spec 004 — 知識抽出 + 要約 (Knowledge Extraction + Summarization)
**Date**: 2026-05-04
**Status**: Complete (全 NEEDS CLARIFICATION 解決)

---

## R1. `@Generable` で複合構造を 1 セッション生成する設計

**Decision**: トップレベル `@Generable struct ExtractedKnowledgeOutput` に 4 フィールドを並べ、`KeyFactOutput` / `KnowledgeEntityOutput` (子 struct) と `FactType` / `EntityType` (`@Generable enum`) も同時に定義。`@Guide(description:)` で field 単位の制約を日本語で書く。

```swift
import FoundationModels

@Generable
struct ExtractedKnowledgeOutput {
    @Guide(description: "1 文 / 150 字以内 / 元記事の主題と核心 / 元記事に明示されている内容のみ")
    let essence: String

    @Guide(description: "2-3 文 / 300 字以内 / 元記事の構造を維持した説明的要約 / 推測禁止")
    let summary: String

    @Guide(description: "3-5 件、元記事に明示されている事実のみ")
    let keyFacts: [KeyFactOutput]

    @Guide(description: "5-10 件、重要な固有名詞")
    let entities: [KnowledgeEntityOutput]
}

@Generable
struct KeyFactOutput {
    @Guide(description: "事実の 1 文 (200 字以内)、元記事に明示されている内容のみ")
    let statement: String

    @Guide(description: "事実の種別")
    let type: FactType
}

@Generable
enum FactType {
    case event       // 出来事
    case claim       // 主張・意見
    case statistic   // 数値・統計
    case definition  // 定義・説明
    case quote       // 引用
}

@Generable
struct KnowledgeEntityOutput {
    @Guide(description: "固有名詞 (30 字以内)")
    let name: String

    @Guide(description: "種別")
    let type: EntityType

    @Guide(description: "重要度 1〜5 (5 が最重要)")
    let salience: Int
}

@Generable
enum EntityType {
    case person        // 人物
    case organization  // 組織・企業
    case location      // 場所
    case concept       // 概念・用語
    case product       // 製品・サービス
    case work          // 作品 (本・記事・動画等)
}
```

**Rationale**:
- 1 セッション生成で 4 出力を整合性付きで得られる (Plan 設計判断 #2)。
- `@Generable enum` でモデルが固定の case から 1 つを選ぶ形にし、自由文字列より安定。
- @Guide の日本語制約は Apple Foundation Models が日本語コンテキストで動作する際に有効。

**Alternatives considered**:
- **4 回の独立セッション**: 4 倍の時間 + 整合性制約を prompt で書けない。電力非効率。
- **type を String で宣言**: モデルが自由に文字列を生成して種別が標準化されない。enum で型安全に制約。
- **入れ子をフラットにする** (KeyFact を ExtractedKnowledge の field 配列にまとめずトップレベル別 generable): 1 セッションで複数 generable を返す API は無いため、入れ子で生成して後で分解。

---

## R2. `SystemLanguageModel.availability` チェックパターン

**Decision**: 各抽出ジョブ起動前に `SystemLanguageModel(useCase: .general).availability` を取得し、`.available` 以外なら ジョブを skip (ExtractedKnowledge 作成しない)。

```swift
import FoundationModels

let model = SystemLanguageModel.default  // または useCase 指定
switch model.availability {
case .available:
    // 抽出ジョブ実行
    break
case .unavailable(let reason):
    // skip。reason は .deviceNotEligible / .appleIntelligenceNotEnabled / .modelNotReady 等
    Logger.knowledge.info("Skipping extraction: \(reason)")
    return
}
```

reactive 監視 (Combine 等) は MVP 範囲外。起動時 backfill + 都度チェックで十分カバー (Plan 設計判断 #4)。

**Rationale**:
- Apple 公式の availability API。アプリは状態を polling するだけで OK。
- 都度チェックすることで「ユーザーが設定切替直後に Apple Intelligence を OFF にした」ようなレースを安全側に倒せる。
- 起動時 backfill が ON 切替を吸収するため reactive subscription なしで運用可能。

**Alternatives considered**:
- **Combine `availabilityPublisher`**: 公式 API の存在を未確認。あっても overkill。
- **NotificationCenter での state 変更通知**: そもそも Apple がそのような notification を投げない。

---

## R3. ハルシネーション抑止の prompt 設計

**Decision**: 3 層緩和:

1. **`@Guide(description:)` で field 単位制約**: 各フィールドに「元記事に明示されている内容のみ / 推測禁止」を含める。
2. **prompt 末尾の strict instructions**: 以下を **必ず** prompt 末尾に付ける:
   ```
   # 抽出ルール (厳守)
   - 元記事に明示されている内容のみを抽出してください
   - 推測・補完・常識による補強は行わないでください
   - 該当する事実が見つからない場合は空配列を返してください
   - essence と summary と key facts は互いに矛盾しないでください
   - すべて日本語で出力してください
   ```
3. **UI で「AI 生成」ラベル**: 一覧 / Reader View で必ず併記、ユーザーが「これは AI 由来」と認識できる。Reader では本文を併置し見比べられる動線を維持。

自動検証 (key fact が本文に存在するか) は MVP 外、SC-009 で sampling 計測のみ。

**Rationale**:
- Apple Foundation Models は汎用言語モデルで、prompt 制約に対する従順性は限定的。3 層で実用品質に到達。
- 自動検証 (例: 各 key fact を extractedText 内 substring search) は false positive (言い換えで存在) と false negative (literal match で見つからない) があり、MVP の閾値判定が難しい。将来 spec で扱う。

**Alternatives considered**:
- **Few-shot prompting (例文を含める)**: prompt 長を圧迫し、汎用性を損なう。MVP は instruction-only で運用。
- **Chain-of-thought prompting**: 出力に「考えた過程」を含めると structured output が崩れる。`@Generable` と相性悪。

---

## R4. `LanguageModelSession` の生存期間

**Decision**: **記事ごとに新規セッション、使い捨て** (per-article session)。

```swift
@MainActor
func extract(article: Article) async {
    guard let text = article.body?.extractedText else { return }
    let session = LanguageModelSession()  // 都度作成
    do {
        let response = try await session.respond(
            generating: ExtractedKnowledgeOutput.self,
            prompt: buildPrompt(text: text)
        )
        await store.upsert(article: article, output: response.content)
    } catch {
        await store.upsert(article: article, status: .failed, ...)
    }
}
```

**Rationale**:
- Apple ガイドで short-lived session が推奨。
- 記事間で session を共有すると context が混入するリスク (前の記事の内容を引きずる)。記事ごとに分離が安全。
- 初期化コストは数 ms オーダーで、生成時間 (数秒) に比べて無視可能。

**Alternatives considered**:
- **Long-lived session (バッチ処理 1 つで全 article)**: 状態漏れリスク + cancellation 制御が複雑。
- **Singleton session**: 同上、`@MainActor` 共有リソースとして競合。

---

## R5. エラーハンドリング (safety filter / context size / その他)

**Decision**: `LanguageModelSession.respond` の throw を catch し、ステータスを以下で分類:

| エラー | 状態 | UI 影響 |
|---|---|---|
| safety filter で blocked | `.failed` | UI に何も出さない (spec.md FR-014) |
| context window 超過 | `.failed` | extractedText を切り詰めて 1 度だけ retry、それでも失敗なら `.failed` (Phase 4 の研究で詳細化) |
| 生成 timeout | `.failed` | 同上 retry、ダメなら `.failed` |
| 出力フォーマット不一致 (Generable パース失敗) | `.failed` | 部分的にでも取れた要素を `.partiallySucceeded` で保存 |
| Apple Intelligence 不可能 (起動時チェックを通過後の途中変化) | `.skipped` | 何も保存しない |
| Task.cancel | `.pending` のまま | 次回 backfill で再開 |

**Rationale**:
- 永続失敗 / 一時失敗 / skip の 3 つを区別することで、起動時 backfill が正しく挙動する。
- safety filter blocked と通常失敗の区別は Apple API がエラー型で提供する想定 (詳細は実装で確認)。

**Alternatives considered**:
- **すべて `.failed`**: 区別ないと backfill で永続失敗を毎回 retry してしまう。`.permanentlyFailed` まで状態を分けるが、本 MVP では再試行ロジックなしのため `.failed` 一段で運用 (将来 spec で拡張)。

---

## R6. Foundation Models のモック / テスト戦略

**Decision**: `LanguageModelSessionProtocol` を導入し、本番は Apple `LanguageModelSession` をラップ、テストは `MockLanguageModelSession` で固定 `ExtractedKnowledgeOutput` を返す。

```swift
protocol LanguageModelSessionProtocol: Sendable {
    func generateKnowledge(prompt: String) async throws -> ExtractedKnowledgeOutput
}

@MainActor
final class FoundationModelLanguageModelSession: LanguageModelSessionProtocol {
    func generateKnowledge(prompt: String) async throws -> ExtractedKnowledgeOutput {
        let session = LanguageModelSession()
        let response = try await session.respond(
            generating: ExtractedKnowledgeOutput.self,
            prompt: prompt
        )
        return response.content
    }
}

final class MockLanguageModelSession: LanguageModelSessionProtocol, @unchecked Sendable {
    var nextResult: Result<ExtractedKnowledgeOutput, Error> = .success(.fixture())
    func generateKnowledge(prompt: String) async throws -> ExtractedKnowledgeOutput {
        switch nextResult {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }
}
```

実 Foundation Models を呼ぶテストは Apple Intelligence 対応シミュレータが必要なため CI で動かない。`quickstart.md` で手動検証担保 (Constitution テストゲート / Principle II 解釈の範囲内)。

**Rationale**:
- protocol 抽象でテスト容易性を維持 (Principle VI)。
- 実 Foundation Models の品質テストは end-to-end 手動で sampling、自動化は将来 spec。

**Alternatives considered**:
- **Foundation Models をテスト時もそのまま呼ぶ**: 非決定論的 + 実時間 (数秒) でテストスイートが遅くなる + CI で動かない。

---

## R7. 1 セッション 4 出力 vs 複数セッション

**Decision**: **1 セッションで 4 出力**。詳細は Plan 設計判断 #2 / R1 を参照。

**追加のパフォーマンス考察**:
- 4 出力を 1 セッションで生成する想定時間: median 6 秒 (SC-001、Apple Foundation Models の経験値ベース。実機検証で確認)
- 4 出力を 4 セッションに分ける場合の想定時間: 1 出力 1〜2 秒 × 4 = 4〜8 秒。一見近いが、初期化オーバーヘッド + コンテキスト切替 + 整合性破綻リスクを考えると 1 セッション有利。

**Alternatives considered**:
- **2 セッション (要約 + 構造化)**: 中庸案だが、2 つの出力間の整合性 (essence と key facts が矛盾しない) を担保しづらい。

---

## R8. SwiftData の cascade delete + Generable→@Model マッピング

**Decision**: `Article` を root とする削除カスケード:

```swift
@Model
final class Article {
    // 既存
    @Relationship(deleteRule: .cascade, inverse: \ExtractedKnowledge.article)
    var extractedKnowledge: ExtractedKnowledge?
}

@Model
final class ExtractedKnowledge {
    var article: Article  // non-optional
    @Relationship(deleteRule: .cascade, inverse: \KeyFact.knowledge)
    var keyFacts: [KeyFact] = []
    @Relationship(deleteRule: .cascade, inverse: \KnowledgeEntity.knowledge)
    var entities: [KnowledgeEntity] = []
    // ...
}
```

`ArticleKnowledgeStore.upsert(article:, output:)` で:
1. 既存 ExtractedKnowledge があれば update、なければ create
2. 古い `[KeyFact]` / `[KnowledgeEntity]` を削除し、新しい output から `[KeyFact]` / `[KnowledgeEntity]` を生成して関連付け
3. `context.save()`

**Rationale**:
- Article 削除で 3 階層 (Article → ExtractedKnowledge → [KeyFact, KnowledgeEntity]) すべて削除されるため、孤児レコード防止。
- Generable 出力 → @Model 変換は Store 層で集中管理 (Principle VI)。

**Alternatives considered**:
- **個別 KeyFact / KnowledgeEntity の merge** (id を保持して update): MVP では再生成しないため不要、将来 spec で entity 集約時に検討。

---

## 追加メモ (NEEDS CLARIFICATION なし)

- **背景: prompt の言語**: 本文 (extractedText) が日本語なら prompt も日本語、英語記事は best-effort で日本語要約 (Out of Scope: 多言語切替)。
- **生成バージョン管理**: `ExtractedKnowledge.modelVersion` (Apple Foundation Models のバージョン記録) と `extractionVersion` (アプリ側の prompt / Guide バージョン) を別フィールドで持つ。MVP は `modelVersion = nil` (未取得) / `extractionVersion = 1`。将来再生成判定で使う。
- **electricity / heat**: 1 ユーザー数百件の backfill は実機で温度 / バッテリー影響を確認する必要あり (実装フェーズの Polish phase で対応)。MVP では並列度 1 + バックグラウンド優先度 `.utility` で穏当に運用。
- **prompt template の保管**: Swift コード内に String として埋め込む (簡易)。Bundle resource 化や server-side 取得は将来 spec。
- **既存記事 backfill のトリガ**: アプリ起動時 + 「Apple Intelligence の availability が `.available` に変化」の 2 トリガ。後者は MVP では起動時の都度チェックで吸収 (Plan 設計判断 #4)。
