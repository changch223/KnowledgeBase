# 07 — Tech Constraints

## このファイルの目的

dream product を **実装可能にする技術前提** を明示する。
何を使う・何を使わない・何を制約として受け入れるかを記録。

---

## プラットフォーム

### V1

- **iPhone (iOS 26+)**
- 一般 iPhone ユーザー向け、iPhone 専用
- iPad / Mac は V3+ で検討 (mobile first vision)

### V2-V3+ (将来)

- iPad native アプリ (V3+)
- Mac (Catalyst or native) アプリ (V3+)
- iCloud sync (V3+)
- Apple Watch アプリ (将来検討)

### 取らないプラットフォーム

- Android (Apple Intelligence 前提なので不可)
- Web app (on-device 原則と矛盾)
- 既存 Mac の Obsidian plugin (別カテゴリ)

---

## AI / LLM スタック

### 主軸: Apple Intelligence (Foundation Models framework)

iOS 26+ で標準搭載される on-device LLM を使う。

| API | 用途 |
|---|---|
| `LanguageModelSession` | テキスト生成 |
| `@Generable` macro | 構造化出力 (JSON 型安全) |
| `@Guide` | 出力フィールドのガイド |
| `Tool` protocol | アプリ定義の関数を LLM が呼べる (将来 web search 等で使う候補) |
| `SystemLanguageModel.availability` | 利用可否判定 |
| `SystemLanguageModel.supportedLanguages` | 対応言語一覧 |

### 制約

- **on-device 完結**、API 課金なし、外部送信ゼロ
- Context window: 4096 token 程度 (将来拡張あり得る)
- 出力速度: 数秒オーダー (UX に組み込む際は spinner / 受動 surface)
- 対応言語: 主に英語 / 日本語、他言語は将来拡張
- vision input: 現状 (2026-05) なし、V3+ で出てきたら採用候補

### Foundation Models が苦手なこと (受け入れる制約)

- 長文 (4k token 超) の一括処理 → chunked + meta-summary で対応
- 完全な事実性 (ハルシネーション) → 引用付き出力 + post-process で抑制
- マルチモーダル (画像理解) → V3+
- リアルタイム streaming → 擬似 streaming (15ms/文字) で代替

### 例外 (V1 で追加採用するアプリ)

| 用途 | 採用 framework |
|---|---|
| 翻訳 (英語等 → 日本語) | **Apple Translation framework** (iOS 18+ offline、Foundation Models が非日本語入力を拒否するため) |
| OCR (画像 → テキスト) | **Vision framework** (`VNRecognizeTextRequest`、日本語 + 英語混在対応) |
| 言語判定 | **NaturalLanguage framework** (`NLLanguageRecognizer`) |
| Embedding (検索用) | **NaturalLanguage framework** (`NLEmbedding.sentenceEmbedding`、現状日本語 / 英語 sentence embedding) |

### 取らない LLM

- ❌ OpenAI / Anthropic / Google API (クラウド送信 = プライバシー違反)
- ❌ Llama / Mistral 等の OSS LLM を Core ML で動かす (アプリサイズ / メンテ負荷)
- ❌ MLX で独自 fine-tune モデル (V3+ で「Karpathy Further explorations」候補)

---

## データ層

### 主軸: SwiftData

- iOS 26+ ネイティブ ORM
- `@Model` で構造化、`@Relationship` で関係
- `@Query` で SwiftUI ビューと reactive 統合
- マイグレーション lightweight 中心、custom migration plan 必要なら別途
- App Group container で Share Extension と共有

### 検索

- Substring 検索: `localizedStandardContains` (Foundation 標準)
- Semantic 検索: NLEmbedding + cosine similarity (Accelerate vDSP_dotpr)
- Tag / カテゴリーフィルタ: SwiftData predicate
- Full-text index: SwiftData の組み込み機能を使う (or BFS で自前)

### 永続化規約

- Raw 層: immutable、ユーザー削除のみ
- Wiki 層: LLM が書く、user は補正
- Schema 層: アプリコードに hardcode

### ストレージ目安

| ノード | 容量目安 |
|---|---|
| 保存ソース 200 件 | ~5-20 MB (本文 + 抽出データ + embedding) |
| 概念ページ 100 件 | ~1-3 MB |
| グラフノード 500 + エッジ 1500 | ~1-2 MB |
| Embedding (256-dim Float) | ~1 KB / ノード × ノード数 |
| **合計目安 (中規模ユーザー)** | **~10-30 MB** |

iCloud sync (V3+) で考慮するなら数 GB 規模も想定。

---

## UI / View 層

### SwiftUI 統一

- 全 view を SwiftUI で書く (UIKit 直接使用 最小限)
- iOS 26+ 機能を積極活用 (`NavigationStack` / `@Observable` / `@Bindable` / `.searchable` 等)
- Canvas API で graph 描画 (Force-directed not、static 円形 layout)

### Widget

- WidgetKit
- timeline-based update (バックグラウンド処理は WidgetKit task で)
- 3 サイズ対応 (small / medium / large)

### Share Extension

- App Group container 経由でデータ共有
- 受け入れる activation rule: URL / Image / PDF / Text

### Spotlight 統合 (V3+ 候補)

- Core Spotlight でアプリ内データを OS 検索可

---

## バックグラウンド処理

### BGTaskScheduler

- spec 009 同パターン
- 起動時 register (登録漏れ防止)
- 用途:
  - WikiLint 週 1
  - EntityCommunity 再検出 週 1
  - 概念ページ stale 再合成 (空き時間に少しずつ)
  - 既存記事の概念ページ初期 backfill (新機能追加直後の 1 回)

### 注意

- iOS の BGTask は **実行保証されない** (システム判断)
- 重要処理はユーザー操作起点でも動かす (BGTask 失敗時の fallback)

---

## プライバシー

### 完全 on-device 原則

- すべての LLM 推論が iPhone 内
- すべてのデータが SwiftData (App Group container) 内
- ネットワーク通信は **Web 記事の本文 fetch のみ** (URLSession、ユーザーが共有した URL に対する HTTP GET)
- ChatGPT / Gemini / Claude API への送信: **ゼロ**

### 唯一の例外: 翻訳モデルのダウンロード

- Apple Translation framework は初回起動時に翻訳モデルを Apple サーバーから DL
- ユーザーが Settings > 一般 > 言語と地域 > 翻訳の言語 で英語+日本語を install 済の前提
- これは Apple のシステム機能 (アプリは何も送信しない)

### Export 時

- export ファイル (zip / markdown) を Files app に出力
- iOS Share Sheet で user が共有先選択
- アプリは「どこに送ったか」追跡しない (privacy)

### 取らない技術

- ❌ analytics SDK (Firebase / Mixpanel 等)
- ❌ クラッシュレポート (Apple 標準のみ受け入れ、サードパーティなし)
- ❌ A/B テスト framework
- ❌ remote config (機能フラグはアプリビルド内)

---

## 言語 (i18n)

### V1

- 主言語: **日本語** (UI / 知識層)
- 入力: 日本語 / 英語 / 中国語 (翻訳経由で日本語化)
- xcstrings で文字列管理 (Localizable.xcstrings)

### V2-V3+

- UI 多言語化 (英語 / 中国語 / 韓国語 / etc.)
- 知識層も多言語選択可 (ユーザー選択)

---

## アクセシビリティ

- VoiceOver 全画面対応
- Dynamic Type 全 view 対応
- 高コントラスト対応
- Reduce Motion 対応
- Apple HIG 完全準拠

---

## パフォーマンス目標

| 操作 | 目標時間 |
|---|---|
| Share Sheet 保存 → 「保存しました」表示 | 1-2 秒 |
| アプリ起動 → 学習タブ表示 | 1 秒以内 |
| カード遷移アニメーション | 200ms |
| 秘書 chat 答え生成 | 3-10 秒 (Foundation Models 制約) |
| 検索 query → 結果表示 | 1 秒以内 |
| 知識 Clip タブ scroll 60fps | 維持 (LazyVStack + @Query) |

---

## テスト戦略

### 単体テスト

- Swift Testing (`@Test`, `#expect`)
- 純関数中心 (Service / Algorithm)
- Mock LLM session で決定論的テスト
- カバレッジ目標: 80%+ (実装コードに対して)

### 統合テスト

- 主要パイプライン (ingest → extract → 概念ページ生成) を end-to-end
- 実 Foundation Models は使わず Mock

### UI テスト

- 主要 flow (Flow 1-9 の代表) を XCUITest で自動化
- 最小限 (重い、メンテ負荷高)

### 実機検証

- 各 spec で quickstart.md (検証シナリオ) を作成
- ユーザー自身が実機で確認
- 結果を spec ファイルに記録

---

## 実装原則 4 つ (07-external-references.md より引用)

vision レベルの 11 原則とは別に、**実装時に意識する** 4 つの原則:

### 実装原則 a: 説明文 = 検索精度の本体

- ConceptPage の `summary` が embedding の入力
- summary の質 = 検索精度
- LLM prompt で summary をリッチに書かせる工夫が必須

### 実装原則 b: Runbook pattern

- LLM 答え / カードに「次のアクション候補」を必ず内蔵
- UI で inline 表示、ユーザーが「次どうする」で迷わない

### 実装原則 c: 自己進化メカニズム

- ingest → 概念ページ更新 → query → SavedAnswer → 次の問い surface
- フィードバックループが切れない設計
- BGTask + 各操作 hook で発火

### 実装原則 d: ハルシネーション位置の意識的設計

- LLM 介在 = **抽出時のみ** (要約 / 概念ページ / コミュニティ命名 / chat 答え)
- 検索 / 表示 / 編集 = **決定論的** (LLM 介在ゼロ)
- 「答え自体がハルシネーション」ではなく「材料がレビュー済の事実」

---

## アーキテクチャパターン

### Protocol + DI

- Service は protocol で抽象化
- DI コンテナで構築時注入
- テストでは Mock 注入

例:
```
protocol ConceptSynthesisServiceProtocol {
    func synthesize(forEntity: String, in context: ModelContext) async throws
}

final class ConceptSynthesisService: ConceptSynthesisServiceProtocol {
    init(session: LanguageModelSessionProtocol, ...)
}

// テスト時
let mockSession = MockLanguageModelSession()
let service = ConceptSynthesisService(session: mockSession, ...)
```

### Hook-based パイプライン

- 投入 → 各 service の hook 連鎖
- spec 同士の依存を明示的に
- 失敗時は silent degrade (Calm UX)

### Schema は hardcode

- カテゴリー 10 種 / 概念粒度 / Lint ルール はコード内に
- 動的 schema 進化は V3+

---

## 制約まとめ

| 軸 | V1 制約 |
|---|---|
| Platform | iPhone iOS 26+ のみ |
| LLM | Foundation Models のみ |
| Cloud API | 一切使わない |
| Storage | SwiftData (App Group) |
| UI | SwiftUI |
| 言語 | 日本語主、英 / 中 入力対応 |
| Privacy | 完全 on-device、analytics ゼロ |
| 課金 | なし (V1 は無料) |
| Export | zip + markdown、user 主体 |

---

## 次に読むファイル

- `08-non-goals.md` — 技術的・機能的に「やらないこと」明示
- `09-naming-candidates.md` — 製品名候補
- `10-open-questions.md` — 未確定の論点
