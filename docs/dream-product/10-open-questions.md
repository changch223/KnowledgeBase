# 10 — Open Questions (未確定論点)

## このファイルの目的

Phase 1-4 の spec 作成中に **「いったん defaults で進めたが、最終確定していない論点」** を集約する。
migration plan (next step) 開始前、または V1 実装着手前に、user 確認で 1 つずつ決定 → 該当 spec ファイルに反映。

各論点には:
- 該当 spec ファイル
- 現在の defaults (本 spec で採用したもの)
- 選択肢
- 推奨と理由
- 議論ログ

---

## カテゴリ A: 中核 UX

### Q-A1: Understanding Card の具体形式

- **該当**: `03-core-loops.md` Loop 2、`04-features.md` E、`06-ux-flows.md` Flow 3
- **defaults**: カード 1 枚 + 「✓ わかった / 🤔 もっと」2 ボタン + 深堀り chat 展開
- **選択肢**:
  - A: カード + 2 ボタン (defaults、推奨)
  - B: カード + 3 ボタン ("✓ わかった" "🤔 もっと" "後で")
  - C: スワイプ ジェスチャー中心 (右 = わかった、左 = もっと、下 = スキップ)
  - D: カードなし、chat 直接 (家庭教師ループのみ chat)
- **議論**: V1 では A (シンプル) で start、user feedback で B/C 検討

### Q-A2: カードキュー優先度の具体重み

- **該当**: `04-features.md` E、`06-ux-flows.md` Flow 3
- **defaults**: 7 要素 (新着 / pin / userUnderstanding 低 / コミュニティ新規 / 「次の問い」/ idle / ランダム)
- **論点**: 各要素の **重み比率** (例: 新着 30% / pin 25% / 低理解 20% / その他 25%)
- **推奨**: V1 は均等に近い、運用してから tune

### Q-A3: 「わかった」フィードバックの implicit 推定

- **該当**: `03-core-loops.md` Compound 条件 3
- **defaults**: explicit button のみ
- **選択肢**:
  - A: button のみ (defaults)
  - B: button + 滞在時間で implicit 推定 (15 秒+ なら "わかった" 推定)
  - C: button + スワイプジェスチャーで隠す = "わかった"
- **推奨**: V1 は A、V2 で B/C 検討

### Q-A4: 深堀り chat の終了タイミング

- **該当**: `06-ux-flows.md` Flow 5
- **defaults**: ユーザーが「✓ わかった」明示タップ
- **選択肢**:
  - A: 明示タップのみ (defaults)
  - B: + 5 ターン chat 後に「腹落ちしましたか?」soft prompt
  - C: + 一定時間操作なしで自動「保留」(後で再開)
- **推奨**: V1 は A、慣性で深堀り過剰になるリスクあれば B

---

## カテゴリ B: 機能スコープ

### Q-B1: Catalog View (Index 相当) を V1 に入れる?

- **該当**: `04-features.md` F
- **defaults**: V1 は内部 index のみ (UI 露出なし)、UI Catalog View は V2
- **選択肢**:
  - A: V1 で UI Catalog View 出す (全 ConceptPage / SavedAnswer / 横断 list)
  - B: V1 は内部、V2 で UI 出す (defaults、推奨)
  - C: そもそも Catalog View 不要 (検索で代替)
- **推奨**: B、ただし user が「全部一覧で見たい」と強く言えば A

### Q-B2: Activity Log の UI 露出

- **該当**: `04-features.md` C、`05-IA.md` ノード 9
- **defaults**: Settings opt-in、default OFF
- **選択肢**:
  - A: Settings opt-in OFF (defaults、推奨)
  - B: 知識 Clip 内に常時表示
  - C: 完全に隠す (内部のみ、Settings からも見えない)
- **推奨**: A

### Q-B3: 動的 Schema 進化 (LLM 提案 → user 採用)

- **該当**: `07-tech-constraints.md` Schema 層
- **defaults**: V1 は hardcode、V3+ で動的進化検討
- **選択肢**:
  - A: V1 hardcode、V3+ で再検討 (defaults、推奨)
  - B: V1 でも「カテゴリーを追加/削除」UI 提供
  - C: 完全廃案
- **推奨**: A、ただし B は「ユーザーに整理を要求しない」原則と矛盾するため reject、C は将来余地残し

### Q-B4: 「✓ わかった」スコア (userUnderstanding) の UI 露出

- **該当**: `05-IA.md` ノード 4
- **defaults**: 内部のみ、UI 非表示
- **選択肢**:
  - A: 完全非表示 (defaults、推奨)
  - B: 概念ページ詳細に「あなたの理解度: ★★★☆☆」表示
  - C: Settings opt-in で全 ConceptPage の理解度マップ表示
- **推奨**: A、B/C は「正解感」を出すリスク

---

## カテゴリ C: 入力 / 出力

### Q-C1: 写真入力の精度向上 (V1)

- **該当**: `04-features.md` A、`06-ux-flows.md` Flow 2 バリエーション
- **defaults**: Vision framework OCR テキスト抽出のみ
- **選択肢**:
  - A: OCR テキストのみ (defaults、推奨)
  - B: OCR + 構造判定 (テーブル / リスト 認識)
  - C: + 画像内容も Foundation Models 経由で説明文生成 (vision LLM、現状不可)
- **推奨**: A、V3+ で vision LLM 来たら C

### Q-C2: AI 会話スクショの自動判定信頼度

- **該当**: `04-features.md` A
- **defaults**: ChatGPT / Gemini / Claude スクショを OCR 後に発話者構造判定
- **論点**: 誤判定時の fallback
  - 「これは AI 会話ですか?」prompt で user 確認?
  - 自動判定して、間違ってたら user 修正?
- **推奨**: V1 は自動判定 + 「違う場合は通常記事として扱う」修正 UI、user feedback で精度 tune

### Q-C3: Export 形式の具体スキーマ

- **該当**: `04-features.md` F、`06-ux-flows.md` Flow 8
- **defaults**: zip 全体 export、markdown 形式
- **論点**: 具体的なファイル構造 / メタデータ format
- **推奨**: V1 は シンプルな markdown directory + manifest.json、V2 で Obsidian vault 互換

### Q-C4: 「個別概念ページのみ export」絞り込みUI

- **該当**: `06-ux-flows.md` Flow 8 Option C
- **defaults**: V1 で全体 zip + 個別 markdown export 両方
- **論点**: 絞り込み (例: 「テクノロジーカテゴリーのみ」「2026 年 5 月以降のみ」) UI
- **推奨**: V1 は シンプル、絞り込みは V2

---

## カテゴリ D: 通知 / Background

### Q-D1: 通知の default

- **該当**: `04-features.md` E、`07-tech-constraints.md`
- **defaults**: 完全 OFF、Settings で opt-in
- **選択肢**:
  - A: 完全 OFF (defaults、推奨)
  - B: 学習 reminder 週 1 が default ON
  - C: 完全に通知機能を作らない
- **推奨**: A

### Q-D2: WikiLint 頻度

- **該当**: `04-features.md` F
- **defaults**: 週 1 BGTask
- **論点**: 頻度 (日 1 / 週 1 / 月 1)
- **推奨**: 週 1 で start、頻度高すぎなら下げる

### Q-D3: ConceptPage 再合成 (stale) のタイミング

- **該当**: `05-IA.md` ノード 4、`03-core-loops.md` Compound 条件 4
- **defaults**: BGTask で空き時間に少しずつ
- **論点**: 「ユーザーが該当 ConceptPage を開いた瞬間 再合成」も追加?
  - メリット: 開いた時に最新
  - デメリット: 開く度に Foundation Models 待ち (UX 悪化)
- **推奨**: V1 は BGTask のみ、開いた時は cached、user が「最新化」明示タップで再合成

---

## カテゴリ E: バージョン区切り

### Q-E1: V1 スコープを更に細分化?

- **該当**: `04-features.md` 全体
- **defaults**: V1 = 30 機能 (大規模)
- **論点**: 1 リリースに含めるか、V1.0 / V1.5 / V1.10 と分けるか
- **推奨**: V1 を 1.0 / 1.5 で 2 段階リリース
  - **V1.0**: 秘書ループ + 概念ページ + 検索 + Export (家庭教師ループは V1.5)
  - **V1.5**: 家庭教師ループ + Understanding Chat + Widget + WikiLint
  - 理由: 家庭教師ループは UX 新規性高、user feedback 必須

### Q-E2: Voice Input の優先度

- **該当**: `04-features.md` D
- **defaults**: V2
- **論点**: 通勤・両手塞がりシーンで強い、V1 入れたい?
- **推奨**: V1 は省略、V2 で確実に投入 (Speech framework は枯れている)

### Q-E3: Web Search BYOK の投入時期

- **該当**: `04-features.md` F、`08-non-goals.md` 1.5
- **defaults**: V2
- **推奨**: V2、ただし「on-device 原則を破る」リスクを Settings で明示警告 + opt-in

### Q-E4: iPad / Mac 展開のタイミング

- **該当**: `07-tech-constraints.md`
- **defaults**: V3+
- **論点**: SwiftUI で書けば iPad は比較的容易、V2 で投入する?
- **推奨**: V1 iPhone 完成 → V2 で iPad 対応 (Mac は V3+)

---

## カテゴリ F: ビジネス / 配布

### Q-F1: 価格モデル

- **該当**: `08-non-goals.md` 1.2
- **defaults**: V1 完全無料
- **選択肢**:
  - A: V1 永久無料、tip jar (V?)
  - B: V1 無料、V2 で freemium (Pro 機能 = 機能制限なし、寄付的)
  - C: V1 から $5 買い切り
- **推奨**: A、tip jar は V?

### Q-F2: App Store 配布リージョン

- **defaults**: 日本 + 米国 + 英語圏 (US / UK / AU / CA)
- **論点**: 中国 / 韓国 / 欧州大陸 を V1 含むか
- **推奨**: V1 は日本 + 英語圏で start、V2 で順次拡大

### Q-F3: TestFlight ベータの規模 / 期間

- **defaults**: 内部 dogfooding + 招待 50 名程度、4-6 週間
- **論点**: 公開ベータ (10000 名) も V1 で?
- **推奨**: V1 は内部ベータのみ、V1.5 で公開ベータ検討

---

## カテゴリ G: 名前 / ブランディング

### Q-G1: 製品名最終決定タイミング

- **該当**: `09-naming-candidates.md`
- **defaults**: dream product spec 完成後に決定
- **論点**: 「migration plan 開始前」or 「V1 リリース直前」どちらで?
- **推奨**: migration plan 開始前 (実装の中で各所に hardcode されるため、早い方が良い)

### Q-G2: 「i knowledge base」を最終採用するか

- **該当**: `09-naming-candidates.md`
- **defaults**: 仮称、評価マトリクスで KnowAtlas が top
- **推奨**: user 最終判断

---

## カテゴリ H: 技術詳細 (実装フェーズで決まる)

### Q-H1: SwiftData migration 戦略

- **該当**: `07-tech-constraints.md`
- **defaults**: 全 lightweight migration、custom migration plan 不要想定
- **論点**: 既存 知積 (KnowledgeTree) からの移行は別問題 (migration plan で扱う)

### Q-H2: Foundation Models context window 4k tokens 制約への対応

- **該当**: `07-tech-constraints.md`
- **defaults**: hierarchical chunked + meta-summary (現知積 spec 010 パターン流用)
- **論点**: V1 で十分か、別 strategy が必要か

### Q-H3: NLEmbedding の精度限界

- **該当**: `07-tech-constraints.md`
- **defaults**: 日本語 sentence embedding 標準使用
- **論点**: 英語含む multi-language 検索で精度劣化、retrieval 後の re-ranking 追加検討
- **推奨**: V1 はシンプル、V2 で SAGE 流 reader tricks 検討

---

## カテゴリ I: vision / 戦略

### Q-I1: 「Apple Intelligence を進化させる」キャッチコピーの訴求方法

- **該当**: `01-vision.md`、マーケティング
- **defaults**: App Store 紹介文 / Web LP で「Apple Intelligence をあなた専用に進化」打ち出し
- **論点**: Apple が「Apple Intelligence」商標を縛る可能性 → Apple のガイドライン確認
- **推奨**: 段階的に、Apple ガイドライン違反にならない表現で

### Q-I2: 競合との明示的差別化

- **該当**: `01-vision.md` 既存ツール対比
- **defaults**: NotebookLM / ChatGPT / Obsidian / Pocket 等の対比表
- **論点**: マーケで「〇〇より良い」と言うか、淡々と「新カテゴリ」と打つか
- **推奨**: 淡々と新カテゴリ、競合 disrespect しない

### Q-I3: ターゲット 7 ペルソナのうち最優先

- **該当**: `02-target-users.md`
- **defaults**: 7 ペルソナを並列、特定しない
- **論点**: 初期マーケで誰を最優先 segment するか
- **推奨**: タブ太郎 (情報過食型) + 学さん (学習者) + 営みさん (経営者) の 3 つに集中、他は副次

---

## まとめ表 (優先度順)

最終 spec 完成までに最低限決めたいもの:

| 優先度 | Q | 内容 |
|---|---|---|
| ★★★ V1.0 着手前 | Q-A1 | Understanding Card 形式 (2 ボタン or 3 or スワイプ) |
| ★★★ | Q-A2 | カードキュー優先度の重み比率 |
| ★★★ | Q-E1 | V1 を V1.0 / V1.5 分割するか (家庭教師 phase 分け) |
| ★★ | Q-B1 | Catalog View を V1 入れるか |
| ★★ | Q-C2 | AI 会話スクショの誤判定対応 |
| ★★ | Q-G1 | 名前最終決定タイミング |
| ★ | Q-A3 | implicit 推定 (V1 で入れない方が無難) |
| ★ | Q-B4 | 理解度スコア UI 露出 |
| 後で | 残り | V2 / V3+ で順次 |

---

## 議論ログ

| 日付 | Q | 議論内容 |
|---|---|---|
| 2026-05-23 | (全体) | 本ファイル作成、defaults で進行 |
| TBD | (各 Q) | user 回答待ち |

---

## 次に読むファイル

- 全 11 ファイル完成、`00-README.md` に戻って全体俯瞰
- → migration plan (next step、別 plan ファイル) に進める準備完了
