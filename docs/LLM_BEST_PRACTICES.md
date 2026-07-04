# Knowledge Base — LLM 処理ベストプラクティス完全案

> 調査日: 2026-07-04  
> 対象: iOS 26 / Apple Foundation Models / RAG / 知識管理アプリ競合分析

---

## TL;DR

Knowledge Base の LLM 処理は spec 065 の軽量化 (AI 12→2-3 回/記事) 以来、大きく改善した。  
しかし iOS 26.4 / WWDC 2026 の新 API・競合動向・研究知見と照合すると、**6 つの改善軸**が残っている。  
最高インパクトは ① Private Cloud Compute (32K window) 移行 と ② ハイブリッド検索 の 2 つ。

---

## 1. 競合アプリ分析

### 1-1. Mem X (参考度: ★★★★★)
- **アーキテクチャ**: "Mem It" ですべての入力をキャプチャ → AI が裏で自動タグ・エンティティグラフ構築 → ユーザーは分類しない
- **Knowledge Base との差分**: Mem はサーバー側 LLM (GPT-4o) で token 上限を気にしない。KB は on-device 4096 トークン制約が本質的な違い
- **参考ポイント**: 「入力を受け取ったらすぐ返し、知識整理は非同期」の非同期パイプライン設計は同じ。Mem の「フォルダ廃止・AI 全自動整理」哲学は KB の VISION と一致

### 1-2. Readwise Reader (参考度: ★★★★)
- **アーキテクチャ**: ハイライト収集 → Spaced Repetition → daily digest。LLM は要約生成に限定使用
- **参考ポイント**: 「長文をチャンク分割して重要度でフィルタ後に要約」は KB の ChunkedKnowledgeAggregator と同思想
- **差分**: Readwise はサーバー側 Anthropic Claude を使用。KB は on-device 優先のプライバシー強みがある

### 1-3. Obsidian Copilot + Smart Connections (参考度: ★★★★)
- **アーキテクチャ**: ローカル Ollama バックエンド + nomic-embed-text (~274MB) でベクトル検索 → チャット
- **参考ポイント**: nomic-embed-text はセマンティック類似度が高い (日本語も対応) が、KB はすでに `NLEmbedding.sentenceEmbedding(for: .japanese)` でオンデバイス embedding を使用しており同等以上のプライバシー
- **差分**: Obsidian は `filesystem = state` (markdown + YAML)、KB は SwiftData + CloudKit。KB は sync が強み

### 1-4. Google NotebookLM (参考度: ★★★)
- **アーキテクチャ**: 複数ドキュメントをソースに設定 → Gemini がドキュメントに根拠を限定して回答 (引用必須・ハルシネーション抑制)
- **参考ポイント**: 「KB 外の情報は明示してから一般回答」は KB の `answeredFromGeneralKnowledge` バッジと同思想
- **差分**: NotebookLM は手動でソース追加、KB は自動取り込みが差別化

### 1-5. Notion AI Agent 3.0 (参考度: ★★)
- **アーキテクチャ**: ワークスペース全体を横断して 20 分の自律エージェント実行
- **参考ポイント**: agentic loop (ChatService の agent ループ) は方向性が同じだが、KB は on-device 制約で大規模ループ不可
- **差分**: Notion AI はサーバー側、KB は on-device。KB の強みはプライバシー・オフライン動作

### 1-6. Andrej Karpathy 提唱 "LLM Wiki" (参考度: ★★★★★)
- **思想**: 「7 分裂した概念ページを 1 WikiPage に畳む」「軽い・情報過多でない」「ユーザーが必要な時だけ開く」
- **参考ポイント**: KB の VISION v2 の基盤。spec 063-067 がこの実装。**現在の方向性は正しい**

---

## 2. iOS 26 / WWDC 2026 最新動向

### ⚠️ 提供状況 (2026-07-04 時点) — リリース前に必読

| 機能 | 提供状況 | 本番リリース版に入れられるか |
|---|---|---|
| `contextSize` / `tokenCount(for:)` | **iOS 26.4 GA (正式版)** + `@backDeployed` で iOS 26.0 まで対応 | ✅ **今すぐ可能** |
| Private Cloud Compute LanguageModel (32K) | iOS 27 **ベータのみ** | ⏳ iOS 27 GA (~2026年9月) 以降 |
| 真のトークンストリーミング (`LanguageModelExecutor`) | iOS 27 **ベータのみ** | ⏳ iOS 27 GA 以降 |
| LLM Provider Framework | iOS 27 **ベータのみ** | ⏳ iOS 27 GA 以降 |

**iOS 27 タイムライン**: WWDC keynote 2026年6月8日 → デベロッパーベータ 6月〜 → パブリックベータ 7月〜 → **正式版 ~2026年9月14日 見込み**。

**リリース戦略への影響**:
- **今回の App Store リリース (v1.0)**: iOS 26.4 GA の `contextSize`/`tokenCount` (下記 2-1) までを使う。→ **Priority 1 + Priority 2 で完結**
- **WWDC 2026 の機能 (下記 2-2 / 2-3 / 2-4)**: iOS 27 ベータのため本番不可。→ **v1.1 (iOS 27 GA 後) に回す。Priority 3 として計画**

### 2-1. Foundation Models フレームワーク更新 (iOS 26.4) ✅ GA

```swift
// 新 API: contextSize と tokenCount (バックデプロイ済み)
let model = SystemLanguageModel.default
let contextSize = model.contextSize          // 実機で 4096 or それ以上を返す
let cost = try await model.tokenCount(for: schema)  // @Generable スキーマのコスト
let remaining = contextSize - cost
```

- **`contextSize`**: ハードコード 4096 を排除。端末・モデル更新に自動追従
- **`tokenCount(for:)`**: プロンプト送信前にオーバーフローを予測可能。KB の `TokenBudgetProbe` (DEBUG 専用) を本番に格上げできる
- **`@backDeployed`**: iOS 26.0 以降で使用可能（API シグネチャの後方互換保証済み）

### 2-2. Private Cloud Compute Language Model (WWDC 2026) ⏳ iOS 27 ベータ

```swift
// 仮コード (iOS 27 beta 想定)
let cloudModel = PrivateCloudComputeLanguageModel.default
// contextSize = 32,000 tokens (on-device の ~8x)
// Apple の PCC: サーバー側でも完全プライベート (stateless、Apple も閲覧不可)
```

- **32K トークン**: 概念合成の overflow 問題を根本解消できる
- **プライバシー**: PCC はユーザーデータをサーバーに保存しない = KB のプライバシー価値と矛盾しない
- **推奨戦略**: on-device で生成可能 → on-device。大概念 (記事 10 件超) や long context が必要 → PCC にフォールバック

### 2-3. LLM Provider Framework (WWDC 2026) ⏳ iOS 27 ベータ

```swift
// 仮コード
let session = LanguageModelSession(provider: .anthropic(model: "claude-haiku-4-5"))
```

- Foundation Models フレームワークが Apple 以外の LLM プロバイダーを受け付けるようになった
- KB は同一の `LanguageModelSessionProtocol` 抽象化により**プロバイダー交換がコードゼロで対応可能** (既存設計が正しかった)

### 2-4. トークン単位ストリーミング (WWDC 2026) ⏳ iOS 27 ベータ

- `LanguageModelExecutor` が token ごとにイベントを emit
- ChatTabView の疑似ストリーミング (15ms/字 → 4ms/字) を**真のストリーミング**に置き換え可能
- AI 生成中の体感速度が Gemini / ChatGPT 同等になる

---

## 3. 現行アーキテクチャ評価

### 3-1. 強み (引き続き維持すべき)

| 要素 | 評価 | 理由 |
|---|---|---|
| `LanguageModelSessionProtocol` 抽象化 | ★★★★★ | Mock / Foundation / PCC を DI で切り替え可能 |
| adaptive retry (compact fallback) | ★★★★★ | overflow を自動回避、overflow 率が大幅低下 |
| `AIPriorityCoordinator` | ★★★★ | チャット中は概念合成を停止、ANE 競合を回避 |
| `NLEmbedding.sentenceEmbedding(ja)` | ★★★★ | 完全 on-device、日本語 RAG で高品質 |
| plain string 生成 (`generateWikiBody`) | ★★★★★ | @Generable スキーマを外し ~1500 token 節約 (spec 063 の最重要発見) |
| `TokenBudgetProbe` (DEBUG) | ★★★ | 実測インフラ整備済み。本番昇格で全スキーマを常時監視可能 |
| resumable lint loop | ★★★★ | NEVER STOP 設計、バッチ再開で途中中断に強い |
| 翻訳前処理 (英語・中国語 → 日本語) | ★★★★ | 全パイプラインを日本語固定にしたまま多言語対応 |

### 3-2. 改善余地

| 課題 | 重大度 | 現状 |
|---|---|---|
| contextSize をハードコード 4096 で判定 | High | `isContextOverflow` が文字列判定で間接的に対処 |
| @Generable スキーマコストの本番可視化ゼロ | High | DEBUG の TokenBudgetProbe のみ |
| RAG 検索がセマンティックのみ (BM25 なし) | Medium | キーワード完全一致はヒットしても embedding 低スコアで埋もれる場合あり |
| WikiBody 生成の品質不安定 | Medium | plain string 生成は @Generable の制約なし → 形式逸脱・漏れが起きやすい |
| ConflictDetection の誤検知率 | Medium | topEntityCount=1, comparisonLimit=1 で過度に削減 |
| CategoryClassification の 1 タグ 1 回 | Low | タグ数 × LLM 呼び出し数 (spec 072 で定義+例追加済み) |
| EmbeddingService が @MainActor 依存残り | Low | spec 086 で cosine はオフメインに移したが embed 自体はメイン |
| 検索クエリのキャッシュ未実装 (本番) | Low | spec 086 で embedding キャッシュ 64 FIFO 追加済み |

---

## 4. ベストプラクティス 6 軸

### A. トークン管理 (最重要)

#### A-1. `contextSize` と `tokenCount` を本番で使う

```swift
// 現行 (文字列ハック)
static func isContextOverflow(_ error: Error) -> Bool {
    String(describing: error).contains("exceededContextWindowSize")
}

// 改善: 送信前に予測してスキーマを選択
func chooseOutputSchema(forPrompt prompt: String, session: LanguageModelSession) async -> OutputMode {
    let model = SystemLanguageModel.default
    let promptCost = (try? await model.tokenCount(for: prompt)) ?? 1000
    let remaining = model.contextSize - promptCost
    if remaining > 800 {
        return .full      // ConceptSynthesisOutput
    } else if remaining > 400 {
        return .compact   // ConceptSynthesisCompactOutput
    } else {
        return .fallback  // plain string fallback
    }
}
```

**効果**: overflow が起きてからリトライするより、最初から適切なスキーマを選択するほうが 1 LLM 呼び出し節約になる。

#### A-2. @Generable スキーマコストの常時ログ

```swift
// TokenBudgetProbe を RELEASE でも起動時 1 回実行に昇格
// DEBUG → #if DEBUG を外すだけで TokenBudgetProbe.runDiagnostics() を常時 log
// 実機ログで各スキーマの token コストをユーザーが確認できる
```

実機計測結果の目安 (spec 071 実測値より):
| スキーマ | 推定 token コスト |
|---|---|
| `ExtractedKnowledgeOutput` | ~552 tokens |
| `ConceptSynthesisOutput` | ~300-400 tokens |
| `ChatAnswerOutput` | ~200 tokens |
| `WikiBody` (plain string) | ~0 tokens (スキーマなし) |

#### A-3. Private Cloud Compute へのフォールバック設計

```swift
// 仮実装 (iOS 27+ 対応)
func synthesize(articles: [Article]) async throws -> ConceptSynthesisOutput {
    let model = SystemLanguageModel.default
    if articles.count > 8 || model.contextSize < 4096 {
        // 大概念 or 端末スペック低: PCC (32K) を使用
        let cloudModel = PrivateCloudComputeLanguageModel.default
        return try await runWithModel(cloudModel, articles: articles)
    }
    return try await runWithModel(model, articles: articles)
}
```

---

### B. RAG アーキテクチャ

#### B-1. ハイブリッド検索 (Embedding + キーワード)

現在の問題: 「Claude Code」と入力 → embedding が "AI アシスタント" 系記事を高スコアで返し、「Claude Code」そのものを論じた記事が低スコアになる場合がある。

```
推奨アーキテクチャ:

┌─────────────┐    ┌──────────────────┐
│ セマンティック │    │  キーワード (BM25) │
│ (NLEmbedding) │    │  (SearchPredicate) │
└──────┬──────┘    └────────┬─────────┘
       │                    │
       └────────┬───────────┘
                ▼
         Reciprocal Rank Fusion
                ▼
          Top-K results
```

**実装の最小コスト**: `SearchService` に既存の `SearchPredicate` (8 フィールド substring) の結果を embedding スコアとマージする RRF 関数を追加。新サービス不要。

```swift
// 既存 SearchService に追加
static func reciprocalRankFusion(
    semanticRanks: [(id: String, rank: Int)],
    keywordRanks: [(id: String, rank: Int)],
    k: Int = 60
) -> [String] {
    var scores: [String: Double] = [:]
    for item in semanticRanks  { scores[item.id, default: 0] += 1.0 / Double(k + item.rank) }
    for item in keywordRanks   { scores[item.id, default: 0] += 1.0 / Double(k + item.rank) }
    return scores.sorted { $0.value > $1.value }.map(\.key)
}
```

#### B-2. クエリ拡張 (Query Expansion)

```
ユーザー質問: 「最近の生成 AI 動向」
              ↓
クエリ拡張: 「生成AI」「LLM」「大規模言語モデル」「Claude」「GPT」「Gemini」
              ↓
各クエリで embedding 検索 → union → 再ランク
```

KB ではすでに spec 083 で「history-aware rewrite」(追質問の文脈考慮) を実装済み。これを「1 クエリ → 複数クエリ expand → union」に進化させると recall が向上する。

#### B-3. チャンク戦略の最適化

現在の chunking は文字数ベース (`ChunkSplitter`)。研究ベストプラクティスでは「セマンティック境界 (段落・見出し・文末) で分割」が推奨。

```swift
// 改善: 段落単位 + 文字数上限の組み合わせ
// 1. 改行 2 つ (\\n\\n) で段落分割
// 2. 段落が 500 字超 → 句読点 (。！？) で再分割
// 3. 各チャンク = 300-500 字 (embedding 品質の Sweet Spot)
```

---

### C. Embedding 品質

#### C-1. 現行評価

`NLEmbedding.sentenceEmbedding(for: .japanese)` は Apple の SentencePiece ベースモデル (dimensions: 512)。日本語で高品質な embedding を返す。**維持を推奨**。

#### C-2. Embedding バージョン管理

モデル更新 (iOS アップデート) で embedding の分布が変わる可能性がある。

```swift
// Article.essenceEmbedding に埋め込むバージョン情報
// (現状: バージョン管理なし)
struct EmbeddingRecord: Codable {
    var vector: [Float]
    var modelVersion: String  // e.g. "NLEmbedding.ja.v2"
}
// iOS アップデート後に全 embedding を再生成するトリガー
```

#### C-3. Foundation Models の埋め込み (iOS 27+ 候補)

WWDC 2026 では Foundation Models での multimodal 対応が発表された。将来的に Foundation Models の embedding API が提供された場合、より高品質な日本語 embedding が得られる可能性がある。`EmbeddingService` の protocol 抽象化 (`EmbeddingServicing`) を作ることで、NLEmbedding → Foundation Models の移行がシームレスになる。

---

### D. バックグラウンド処理

#### D-1. 処理フェーズの優先度設計

```
優先度高 ←────────────────────────────────────────────────→ 優先度低

[ ユーザー操作中 ]  [ アプリ前景 ]  [ バックグラウンド ]  [ BGTask ]
  AIPriorityCoord    知識抽出(1)    Lint バッチ(15件)    週1 BGTask
  チャット応答        翻訳(1)         Backfill             カテゴリ昇格
  概念詳細生成        カテゴリ分類(1)
```

KB の `AIPriorityCoordinator` は正しい設計。追加改善: BGTask 中に概念合成をスキップする条件を `AIPriorityCoordinator.isAppActive` で分岐できるようにする。

#### D-2. 失敗耐性 (Exponential Backoff)

```swift
// 現状: Foundation Models が利用不可の場合は nil / fallback に即落下
// 改善: バックオフで再試行

func withRetry<T>(maxAttempts: Int = 3, _ operation: () async throws -> T) async throws -> T {
    var lastError: Error?
    for attempt in 0..<maxAttempts {
        do {
            return try await operation()
        } catch {
            if Self.isContextOverflow(error) { throw error }  // overflow は再試行しない
            lastError = error
            if attempt < maxAttempts - 1 {
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
            }
        }
    }
    throw lastError!
}
```

#### D-3. resumable バッチ → 記事単位のカーソル

現在の `Tag.lastLintedAt` パターン (lastLintedAt 古い順に次のバッチを選ぶ) は正しい。  
同じパターンを `Article` の知識再抽出にも適用する:

```swift
// Article に lastExtractedAt: Date? を追加 → lint loop のステップで古いものから再抽出
// → 品質向上のバックフィルが常に「最も古いもの」から進む NEVER STOP ループになる
```

---

### E. WikiPage / 知識グラフ

#### E-1. WikiBody 品質安定化

plain string 生成 (spec 063) は token 節約で正しい判断。しかし @Generable の「制約による品質担保」がなくなった副作用として、形式逸脱 (spec 079 で修正済み) が起きた。

**推奨: 生成後の構造チェック**

```swift
// WikiBodySanitizer.sanitize (既実装) の強化
// 追加チェック:
// - Markdown 見出しが最低 1 個あるか
// - 本文が minimum 100 字あるか
// - 禁止パターン (UUID, concept-id://, "関連ページ候補") が残っていないか
// → 不合格なら summary から fallback テキストを合成

static func validate(_ body: String) -> Bool {
    body.count >= 100 &&
    !body.contains("concept-id://") &&
    !body.contains("関連ページ候補")
}
```

#### E-2. インクリメンタル WikiBody 更新

現在は `isStale = true` → 次の `resynthesizeAllStale` で全体を再生成。  
記事追加時は「関連記事 1 件分のパッチ」だけを生成して既存本文に統合する方が token 効率が高い。

```swift
// 新記事追加時の差分パッチ生成 (仮)
// buildWikiPatchPrompt(existingBody: String, newArticle: Article) -> String
// → 「既存本文を維持しつつ、以下の新記事の情報を自然に統合してください」
// → 出力を既存本文と diff して最小変更で更新
```

#### E-3. 確信度付きリンク

spec 064 の相互リンクは embedding cosine ≥ 0.5 のものを自動リンク。  
確信度を ConceptPage に保存し、低確信度リンクをユーザーが検証できるよう UI に出す (現在の `isUncertain` edge パターンの WikiPage 版)。

---

### F. プロンプトエンジニアリング

#### F-1. Apple Foundation Models 向け設計原則

Apple の公式ガイド (WWDC 2025 "Explore prompt design & safety") からの要点:

1. **タスク分解**: 複雑なタスクを簡単なステップに分割する (KB の chunk → aggregate → synthesize フローは正しい)
2. **ソースオブトゥルース**: 「記事に明示されているもののみ」指示は必須 (現在実装済み)
3. **ツール呼び出し優先**: 外部データ参照はツール呼び出しとして実装すると信頼性が上がる
4. **世界知識を求めない**: on-device モデルは summarization / extraction に特化。一般知識は PCC または general knowledge fallback で対応 (現在実装済み)

#### F-2. 日本語プロンプトの品質指針

```swift
// 悪い例: 英語指示 + 日本語出力期待
"Summarize the following article in Japanese."

// 良い例: 日本語指示 + 出力形式を明示
"以下の記事の主題と核心を **1〜2 文 / 200 字以内** で、断定調の日本語でまとめてください。
記事に明示されていない内容は含めないでください。"
```

KB のプロンプトは既にこの原則に沿っている。追加改善: 各 `@Guide` の文字制限の単位を「字」から「トークン」に切り替えると、日本語の 1 字 ≈ 1.5-2 トークンの差を意識した設計になる。

#### F-3. Few-shot 例の追加

カテゴリ分類で誤分類が起きる原因の一つは、例が少ない。各カテゴリの `@Guide` に実例を追加すると精度が上がる:

```swift
@Guide(description: """
テクノロジー: AIソフトウェア・プログラミング言語・クラウド・半導体に関する内容。
例(テクノロジー): Claude Code, Swift 6, AWS, GPU, LLM
例(その他に分類すべきでない): '人工知能'はテクノロジー、'男性'はその他
""")
```

---

## 5. 改善ロードマップ

優先度は **インパクト / 実装コスト** で評価。

> **✅ 2026-07-04 実装状況**: P1 + P2 (iOS 26.4 GA 範囲) を全て実装済み。Build SUCCEEDED + 全 unit test PASS。
> 実装は Priority 3 以降 (iOS 27 ベータ依存) を除く「今対応できる範囲」を対象とした。

### Priority 1 — すぐに実装 (1-2 日、リリース前) — ✅ 実装済み

| # | 改善内容 | 状態 | 実装 |
|---|---|---|---|
| P1-1 | `contextSize` / `tokenCount` を本番計測に昇格 | ✅ | `FoundationModelLanguageModelSession` の `generateStructured` catch で overflow 時のみ prompt/schema トークンを本番 os.Logger (`token-overflow`) に記録 (happy path ゼロコスト) |
| P1-2 | 窓超過エラー検出を頑健化 | ✅ | `isContextOverflow` を実 overflow `exceededContextWindowSize` + preflight `wouldExceedContextWindowSize` の両方検出に拡張 (`isOverflowError` も追加) |
| P1-3 | `WikiBodySanitizer.isValid` 追加 | ✅ | 最低字数 + スキャフォールド (生 concept-id / 関連ページ候補) 二重防御。不合格なら summary へ fallback。ConceptSynthesisService に配線 |

### Priority 2 — 次スプリント (1 週間) — ✅ 実装済み

| # | 改善内容 | 状態 | 実装 |
|---|---|---|---|
| P2-1 | 送信前スキーマ選択 (preflight) | ✅ | `generateStructured(preflightOutputReserve:)`。概念合成で `prompt+schema+800 > contextSize` なら respond せず `FoundationModelPreflightError` を throw → adaptive retry が compact に即切替 (無駄な full respond を 1 回節約) |
| P2-2 | RRF ハイブリッド検索 | ✅ | `SearchService.reciprocalRankFusion` (純関数) + `ChatService.retrieve` embedding 経路で cosine + keyword を RRF 融合。キーワード強一致 (≥0.5) は cosine 低でも閾値救済 (embedding に埋もれない) |
| P2-3 | チャンク分割を段落境界優先に | ✅ | `ChunkSplitter` の境界判定を 段落 `\n\n` > 句点 `。` > 改行 `\n` の優先順に (maxChars 不変 = LLM 呼び出し数据え置き) |

### Priority 3 — 中期 (1-2 ヶ月)

| # | 改善内容 | 実装コスト | インパクト |
|---|---|---|---|
| P3-1 | **Private Cloud Compute フォールバック** (記事 8 件超の広い概念は PCC 32K で合成、iOS 27 対応時) | 3-5 日 | Very High: overflow 問題の根本解消 |
| P3-2 | **真のトークンストリーミング** (WWDC 2026 API で ChatTabView の疑似 streaming を置き換え) | 2-3 日 | High: チャット体感速度 |
| P3-3 | WikiBody インクリメンタル更新 (差分パッチ生成、全体再生成をやめる) | 3-4 日 | Medium: token 節約 |
| P3-4 | Embedding バージョン管理 (iOS アップデート後の自動再生成トリガー) | 1 日 | Medium: 長期運用安定性 |

### Priority 4 — 長期 / 調査後判断

| # | 改善内容 | 備考 |
|---|---|---|
| P4-1 | LLM Provider Framework でクラウド LLM 選択可能に (設定画面) | プライバシーポリシー改訂が必要 |
| P4-2 | Foundation Models adapter training (ドメイン特化ファインチューニング) | Apple Developer Program 経由 |
| P4-3 | `EmbeddingServicing` protocol 化 (NLEmbedding → Foundation Models 移行準備) | iOS 27+ の API 待ち |
| P4-4 | Query expansion (1 クエリ → 複数クエリ → union) | ChatService 改修 |

---

## 6. KPI と測定方法

### 6-1. LLM 処理品質

| KPI | 測定方法 | 目標 |
|---|---|---|
| overflow 発生率 | TokenBudgetProbe ログ + `isContextOverflow` カウント / 記事数 | < 2% |
| 概念合成 compact 使用率 | `[ConceptSynthesis] compact retry` ログをカウント | < 10% |
| WikiBody 品質スコア | `WikiBodySanitizer.validate` 不合格率 | < 5% |
| カテゴリ分類精度 | 手動サンプリング (50 タグ) | > 90% |

### 6-2. RAG 精度

| KPI | 測定方法 | 目標 |
|---|---|---|
| KB 接地率 | `answeredFromGeneralKnowledge == false` 率 | > 80% (KB に記事がある質問) |
| 引用記事の関連度 | 手動評価 (チャット 20 件 × 引用 3 件) | 3 点満点で平均 > 2.5 |
| 検索応答時間 | Instruments (ChatService.retrieve) | < 500ms |

### 6-3. 処理速度

| KPI | 測定方法 | 目標 |
|---|---|---|
| 記事保存 → 概念生成完了 | アプリ内タイムスタンプ差分 | < 60 秒 |
| LLM 呼び出し回数/記事 | KnowledgeExtractionService ログ | ≤ 3 回 |
| チャット初回応答 | ChatTabView → 最初のトークン表示 | < 2 秒 |

---

## 7. まとめ

### 現在の Knowledge Base の LLM 処理評価

```
token 管理: ████████░░ 8/10 (adaptive retry ○、contextSize 未活用 △)
RAG 精度:   ██████░░░░ 6/10 (embedding のみ ○、ハイブリッド検索 ✗)
Wiki 品質:  ███████░░░ 7/10 (plain string ○、出力検証 △)
背景処理:   ████████░░ 8/10 (resumable loop ○、backoff なし △)
競合優位性: ██████████ 10/10 (完全 on-device + CloudKit ≫ サーバー依存競合)
```

### 最優先アクション 3 つ

1. **TokenBudgetProbe を本番昇格** (5 分) — 現場の数字で改善判断が変わる
2. **RRF ハイブリッド検索** (3-4 時間) — RAG の最大の弱点を最小コストで補う  
3. **Private Cloud Compute 対応準備** (設計のみ) — iOS 27 正式リリース時に即対応できるよう protocol を今から分離

---

## 参考文献・ソース

- [Apple Foundation Models 2025 Updates](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates)
- [What's new in Foundation Models framework — WWDC 2026](https://developer.apple.com/videos/play/wwdc2026/241/)
- [Bring an LLM provider to Foundation Models — WWDC 2026](https://developer.apple.com/videos/play/wwdc2026/339/)
- [Apple Improves Context Window Management — InfoQ](https://www.infoq.com/news/2026/03/apple-foundation-models-context/)
- [contextSize API Doc](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/contextsize)
- [Tracking token usage in Foundation Models — Artemnovichkov](https://artemnovichkov.com/blog/tracking-token-usage-in-foundation-models)
- [Apple Foundation Models 10x Faster on iOS — Medium/CodeX](https://medium.com/codex/make-your-foundation-llm-app-10%C3%97-faster-on-ios-real-world-optimizations-38b6892132de)
- [RAG Best Practices 2025 — Eden AI](https://www.edenai.co/post/the-2025-guide-to-retrieval-augmented-generation-rag)
- [AWS RAG Writing Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/writing-best-practices-rag/introduction.html)
- [From LLMs to Knowledge Graphs — Medium](https://medium.com/@claudiubranzan/from-llms-to-knowledge-graphs-building-production-ready-graph-systems-in-2025-2b4aff1ec99a)
- [Build Second Brain AI Assistant (RAG) — DecodingAI](https://www.decodingai.com/p/build-your-second-brain-ai-assistant)
- [Andrej Karpathy LLM Wiki + Obsidian — MindStudio](https://www.mindstudio.ai/blog/andrej-karpathy-llm-wiki-obsidian-ai-second-brain)
- [Obsidian + Local LLM 2026 — PromptQuorum](https://www.promptquorum.com/power-local-llm/local-llm-with-obsidian-2026)
- [NotebookLM + Obsidian 2026 workflow — GeekyGadgets](https://www.geeky-gadgets.com/notebooklm-obsidian-workflow-2/)
- [LLM Knowledge Graph Builder 2025 — Neo4j](https://neo4j.com/blog/developer/llm-knowledge-graph-builder-release/)
- [Second Brain Playbook 2026 — DEV Community](https://dev.to/truongpx396/the-second-brain-playbook-2026-edition-33)
