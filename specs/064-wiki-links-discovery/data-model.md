# Data Model: Wiki ページ相互リンク + 関係発見

## SwiftData @Model 変更

**ゼロ。** relatedConceptIDs / embedding / bodyMarkdown はすべて spec 042/063 で既存。CloudKit migration 不要。

## 既存フィールド利用

| ConceptPage フィールド | 役割 (本 spec) |
|---|---|
| `relatedConceptIDs: [UUID]` | embedding 近傍で補完 (Phase 1) + 本文リンク候補 (Phase 2) |
| `embedding: Data?` | cosine 類似計算 (`.asFloatArray`) |
| `bodyMarkdown: String` | AI が `[名](concept-id://UUID)` リンクを埋める |
| `isHidden: Bool` | 関連候補から除外 |

## 新規定数 (ConceptSynthesisService 内)

| 名前 | 値 | 役割 |
|---|---|---|
| `relatedConceptLimit` | 8 | embedding 近傍の上限 |
| `relatedConceptThreshold` | 0.5 | cosine 類似度の下限 (無関係除外) |
| `linkCandidateLimit` | 8 | 本文リンク候補の上限 |

## 新規純関数

| 関数 | 配置 | 役割 |
|---|---|---|
| `nearestConceptIDs(for:in:)` | ConceptSynthesisService | embedding 近傍 ID 算出 |
| `sanitizeConceptLinks(in:validIDs:)` | ConceptSynthesisService (static) | 捏造リンク除去 |
| `extractConceptID(from:)` | ConceptPageDetailView (static) | concept-id:// URL → UUID |

## 状態遷移
なし。
