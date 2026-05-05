# Feature Specification: UI リブランディング + AI ブレインタブ追加

**Feature Branch**: `011-ai-brain-tab`
**Created**: 2026-05-05
**Status**: Draft

## なぜ (Why)

spec 001-010 で「保存 → 取得 → 抽出 → 知識化 → 検索 / タグ / 関連記事」のパイプラインが完成した。次に必要なのは、**ユーザーが「自分の AI が育っている」と実感できる体験**。

現状はシングル画面 (ArticleListView) でリストを延々スクロールするだけで、蓄積した知識量を一覧する手段が無い。「Safari で読んだ記事が自動で吸収され、自分専用の AI がどんどん育っていく」というコアコンセプトが UI に表れていない。

本 spec では:
1. アプリ名を **「KnowledgeTree」→「知積 (ちづみ)」** にリブランディング
2. シングル画面構成を **2 タブ (ライブラリ 📚 / AI ブレイン 🧠)** に再構成
3. 新規「AI ブレイン」タブで蓄積された知識を **PowerGauge / KnowledgeMap / RecentActivity** の 3 セクションで可視化
4. ストレスゼロ原則 (レベル / バッジ / ストリーク無し) で calm UX (Constitution Principle V) を維持

既存のスキーマ・サービスは **完全に無改修** で要件達成可能。

## ゴール

- ユーザーがアプリを開くと「ライブラリ」「AI ブレイン」の 2 タブが見える
- 「AI ブレイン」タブで:
  - Article 累計数 / KnowledgeEntity 累計数 / KeyFact 累計数を一目で把握
  - Tag をノード、共通 entity をエッジとしたナレッジマップを 360° 眺められる
  - 直近 7 日の「成長記録」(吸収数 / 育ったテーマ / 新繋がり) を確認できる
- アプリ名は「知積」(ホーム画面 / Settings / Share Sheet で表示)
- 既存 ArticleListView 体験は完全に保持
- spec 005 の live update メカニズムが両タブで機能する

## 非ゴール

- Safari Extension からの自動取り込み (将来 spec)
- 高度な Force-Directed Layout (依存ライブラリ追加) — Canvas で簡易実装
- レベル数字 / バッジ / ストリーク / ランキング — calm UX に反する
- 解放ポップアップ / プッシュ通知 — calm UX に反する
- 他者比較 / シェア機能 — 個人 AI 育成体験のスコープ外
- エッジ重みづけ (接続強度の可視化) — 将来 spec

## ユーザストーリー

### US1 (P1) — 自分の AI の成長を一目で確認

**As a** 数十件の記事を保存してきたユーザー
**I want** アプリを開くと AI ブレインタブで蓄積量が一目で分かる
**So that** 「また育ってる」と気づいて嬉しくなり、また記事を読もうという気になる

#### 受け入れ基準

- ユーザーは下部タブバーで「AI ブレイン」アイコンをタップ
- PowerGaugeCard に Article 数 / KnowledgeEntity 数 / KeyFact 数が表示
- 起動時に 0 から実数までカウントアップアニメーション (~0.6 秒)
- "Your AI is growing" の固定英文がブランド感を演出
- カードはグラデーション背景で iOS ライト系
- 静かなパルスアニメーションで「生きている感じ」

### US2 (P1) — タグの繋がりを視覚的に把握 + 該当記事へ即遷移

**As a** タグや AI 抽出 entity が増えてきたユーザー
**I want** どのタグがどう繋がっているかをマップで見たい
**So that** 自分の興味の地図を俯瞰できる + 興味のあるタグから記事を辿れる

#### 受け入れ基準

- AI ブレインタブの Section 2 に KnowledgeMap が表示
- 各 Tag が円形ノードで配置され、サイズは tag.articles.count に比例 (40pt-100pt)
- 同一 KnowledgeEntity を持つタグ同士が線で結ばれる
- 新規タグ追加時、新ノードが 0.4 秒フェードインで出現
- ノードタップ → 既存 TagFilteredListView へ遷移 (該当タグの記事一覧)
- ピンチでズーム、ドラッグでパン
- タグ 0 件 (新規ユーザー) は「まだ記事がありません。Safari から記事を保存しよう！」のエンプティステート

### US3 (P2) — 直近 7 日の成長記録を見る

**As a** アプリを継続使用しているユーザー
**I want** 「最近どれだけ吸収したか」「どのテーマが育ったか」「新しい繋がり」を確認したい
**So that** 自分の知識の動きをふり返ることができる

#### 受け入れ基準

- AI ブレインタブの Section 3 に横スクロール 3 枚のカード
- カード A: 「今週 N 件 新たに吸収」(Article.savedAt が 7 日以内の件数)
- カード B: 「最近育ったテーマ: ○○」(7 日以内に最も記事が増えたタグ Top3)
- カード C: 「新しい繋がり: ○○ ↔ ○○」(7 日以内に初出現の KnowledgeEntity)
- データが 0 件のカードは「まだありません」と表示 (押し付けがましくない calm UX)

### US4 (P1) — 既存ライブラリ体験は完全保持

**As a** spec 001-010 までの体験に慣れたユーザー
**I want** タブが増えても従来のリスト → タップで記事 Detail の体験が変わらない
**So that** 学習コストなしで新機能を享受できる

#### 受け入れ基準

- 「ライブラリ」タブで ArticleListView が以前と全く同じ挙動
- 検索バー、タグ一覧ボタン、Detail シート、関連記事、自動タグ提案すべて従来通り
- BottomStatusBar (knowledge 抽出進捗) は両タブで表示される
- spec 005 の live update (RefreshTrigger / NotificationCenter / Timer) が両タブで機能
- spec 009 / 010 のバックグラウンド処理は AI ブレインタブを開いても進行中なら裏で動作

### Edge Cases

- **記事 0 件・タグ 0 件 (新規インストール直後)**: PowerGauge は全部 0、KnowledgeMap はエンプティステート、RecentActivity は全カード「まだありません」
- **Tag 100+ 件 (パワーユーザー)**: KnowledgeMap のノード数が増えても 60fps を維持 (force-directed 反復は最大 10 回で打ち切り)
- **タグ 1 件のみ**: 単一ノード中央に配置、エッジ無し
- **エッジが極端に多い (タグ間で多くの entity を共有)**: 線が密集して見にくい場合は線の透明度を下げる (固定 alpha 0.3)
- **アプリ起動直後の AI ブレインタブ表示**: bootstrap 完了前でも空状態を表示、bootstrap 後 RefreshTrigger で更新
- **KnowledgeMap で同一座標に複数ノード**: force-directed の反発力で自動的に分散
- **アプリ名変更**: ホーム画面アイコンの label / Settings のアプリ名 / Share Sheet の表示名がすべて「知積」になる

## 機能要件

### 1. アプリ名リブランディング

- **FR-001**: アプリの表示名を「KnowledgeTree」から「**知積**」(ちづみ) に変更
- **FR-002**: 変更箇所は **CFBundleDisplayName** (build setting で `INFOPLIST_KEY_CFBundleDisplayName = 知積`) のみ
- **FR-003**: Bundle Identifier、コード上の `KnowledgeTree` クラス名 / module 名 / プロジェクト構造は変更しない (内部実装は KnowledgeTree のまま)

### 2. TabView 化

- **FR-004**: ルート view を `TabView` に変更し、2 タブ構成にする
- **FR-005**: Tab 1: 「ライブラリ」、SF Symbol アイコン `books.vertical`、root は既存 `ArticleListView`
- **FR-006**: Tab 2: 「AI ブレイン」、SF Symbol アイコン `brain`、root は新規 `AIBrainView`
- **FR-007**: TabView は spec 005 の live update メカニズム (`RefreshTrigger`、`NotificationCenter` listen、`scenePhase` 監視) を **TabView root で 1 回だけ** 配置し、両タブに伝播
- **FR-008**: `BottomStatusBar` は TabView の overlay で全タブに表示 (spec 005 既存挙動継承)
- **FR-009**: 既存の `ArticleListView` は 1 行も改修しない
- **FR-010**: 既存の `navigationDestination` (TagListDestination / TagFilteredDestination / EntityFilteredDestination) は両タブで動作可能 (各タブの NavigationStack 内で同じ destination 型を使う)

### 3. AIBrainView 構成

- **FR-011**: AIBrainView は `NavigationStack` 内に縦 `ScrollView` で 3 セクションを配置
- **FR-012**: NavigationBar title: 「AI ブレイン」
- **FR-013**: 3 セクションの順序: PowerGauge → KnowledgeMap → RecentActivity
- **FR-014**: AIBrainView の `navigationDestination` は spec 008 既存の `TagFilteredDestination` を使用 (新規 destination 型は導入しない)

### 4. PowerGauge (Section 1)

- **FR-015**: 高さ約 160pt のグラデーションカード
- **FR-016**: メイン数字: 「**N** 記事を吸収済」(N = Article 総数)
- **FR-017**: サブ数字: 「**N** 知識  ·  **N** キーファクト」
   - 知識数 = `KnowledgeEntity` 全件を `name.lowercased() + trim` で重複排除した個別数
   - キーファクト数 = `KeyFact` 全件 count
- **FR-018**: 固定英文「Your AI is growing」(translate しない、ブランド感のため)
- **FR-019**: 起動時に 0 から実数までカウントアップアニメーション (約 0.6 秒、easeOut)
- **FR-020**: 静かなパルスアニメーション (scale 1.0 ↔ 1.02、周期 2 秒、繰り返し) — 押し付けがましくない calm UX
- **FR-021**: カードのグラデーションは iOS ライト系 (`.linearGradient` で 2 色、青系 → 紫系)
- **FR-022**: 数字の更新タイミング: 新記事保存 / knowledge 抽出完了で `RefreshTrigger.bump` 経由で即時反映

### 5. KnowledgeMap (Section 2)

- **FR-023**: Section 2 の高さは ScrollView 内で「Section 1 + Section 3 を除いた残り全体」(最低 300pt 確保)
- **FR-024**: 描画は `Canvas` + `GeometryReader` で実装、サードパーティ依存なし (Constitution Additional Constraints)
- **FR-025**: Tag 1 件 = 円形ノード 1 個
- **FR-026**: ノードサイズは `tag.articles.count` に比例 (最小 40pt、最大 100pt、対数スケール)
- **FR-027**: ノード内またはノード直下にタグ名 (Caption フォント、1 行、はみ出し ellipsis)
- **FR-028**: エッジ (接続線): タグ A の article から得られた entity name set と タグ B の article entity name set の intersection が空でないペアに線
- **FR-029**: 線の太さは固定 (1pt)、color は `.secondary.opacity(0.3)` で線が密集しても見やすく
- **FR-030**: ノード位置は **簡易 force-directed layout** で計算
   - 反発力: 全ノード間で逆 2 乗の push
   - 引力: エッジで結ばれたペアにバネ pull
   - 中心引力: 全ノードを画面中心へ弱く引く
   - 反復回数: 5-10 回 (60fps を維持できる範囲で)
- **FR-031**: 新規タグ追加時、対応するノードは 0.4 秒フェードインアニメーション
- **FR-032**: ノードタップ → 既存 `TagFilteredListView(tagName:)` へ NavigationLink 遷移
- **FR-033**: ピンチジェスチャでマップ全体ズーム (scale 0.5x - 3x)
- **FR-034**: ドラッグジェスチャでマップ全体パン
- **FR-035**: タグ 0 件のとき: 「まだ記事がありません。Safari から記事を保存しよう！」のエンプティステート (`ContentUnavailableView`)
- **FR-036**: ノード位置計算は純粋関数 `KnowledgeMapBuilder.buildGraph(tags:) -> (nodes:[Node], edges:[Edge])` に切り出し、Service テスト容易化

### 6. RecentActivity (Section 3)

- **FR-037**: 高さ約 120pt の横スクロール 3 枚カード
- **FR-038**: カード A: 「今週 **N** 件 新たに吸収」 = 直近 7 日 (今日から 7 日前 0:00 以降) の Article 件数
- **FR-039**: カード B: 「最近育ったテーマ: **○○**」 = 直近 7 日で article 数が最も増えたタグ Top3 を bullet で表示。データ無しなら「まだありません」
- **FR-040**: カード C: 「新しい繋がり: **○○** ↔ **○○**」 = 直近 7 日に初めて出現した KnowledgeEntity を 2 つペア表示。データ無しなら「まだありません」
- **FR-041**: カードはタップ可能だが、MVP ではタップ動作なし (将来 spec で各カードに対応する詳細画面遷移)
- **FR-042**: 直近 7 日の判定境界は `Date().addingTimeInterval(-7 * 86400)` の Article.savedAt 比較

### 7. ストレスゼロ原則

- **FR-043**: レベル数字 (Lv.5 など) を一切表示しない
- **FR-044**: バッジ・実績通知を一切表示しない
- **FR-045**: ストリーク (連続日数) を一切表示しない
- **FR-046**: ランキング・他者比較を一切表示しない
- **FR-047**: 「○○ 解放！」系ポップアップを一切表示しない
- **FR-048**: PowerGaugeCard の数字は **常に増え続ける** (削除でも数字を減らさない一方向 UX は MVP 範囲外、削除すれば普通に減る)

## 主要エンティティ

新規スキーマ追加なし。既存 entity を読み取るのみ:

| 表示要素 | 既存モデル / プロパティ |
|---|---|
| 吸収済記事数 | `Article` 全件 count |
| 知識数 | `KnowledgeEntity.name` を `lowercased + trim` で重複排除した個別 count |
| キーファクト数 | `KeyFact` 全件 count |
| マップノード | `Tag` 全件 |
| ノードサイズ | `tag.articles.count` |
| エッジ | `KnowledgeEntity.name` が共通する Tag ペア |
| 今週吸収 | `Article.savedAt > now - 7d` の件数 |
| 育ったテーマ | `Article.savedAt > now - 7d` でタグ別にグループ化、件数 desc |
| 新しい繋がり | 全 article の `KnowledgeEntity` のうち、初出現が 7 日以内の name |

### Transient (永続化しない)

- **MapNode**: id (Tag.name), position (CGPoint), radius (CGFloat)、純粋関数で生成
- **MapEdge**: from / to (Tag name pair)、純粋関数で生成
- **RecentActivitySnapshot**: `articlesThisWeek: Int`, `growingTags: [String]`, `newConnections: [(String, String)]` — view 内 computed property

## 成功基準 (Success Criteria)

- **SC-001**: 新規インストール直後にアプリを開いて、AI ブレインタブをタップすると 1 秒以内に空状態 (PowerGauge: 0/0/0、Map: エンプティステート) が表示される
- **SC-002**: 30 件の記事 + 10 個のタグを保有するユーザーが AI ブレインタブを開いて、PowerGauge のカウントアップが 0.6 秒で完了
- **SC-003**: KnowledgeMap が Tag 30 件 + エッジ 50 本で 60fps を維持してパン / ズーム可能
- **SC-004**: ノードタップから TagFilteredListView の表示まで 0.5 秒以内
- **SC-005**: 新記事を共有保存して knowledge 抽出が完了した後、AI ブレインタブの数字が 1 秒以内に更新される (RefreshTrigger 経由)
- **SC-006**: 100 件タグ環境で KnowledgeMap の force-directed 反復が 200ms 以内に完了
- **SC-007**: 既存ライブラリタブの ArticleListView の挙動が spec 010 までと完全に同一 (回帰テスト)
- **SC-008**: アプリホーム画面アイコンの label が「知積」に変更されている

## 依存・前提

- **spec 001-010** までの全機能が稼働済 (実装ベース、main / 010-hierarchical-summary branch)
- **iOS 26+** (TabView + NavigationStack + Canvas、SwiftUI 6)
- **既存 SwiftData schema** で全データ取得可能 (新 @Model 追加なし)
- spec 005 の live update メカニズムを TabView root に配置
- spec 008 の TagFilteredListView / EntityFilteredListView を再利用

## アサンプション

- **アプリ名「知積」は CFBundleDisplayName のみ変更**: ホーム画面 / Share Sheet / Settings 表示。Bundle Identifier (`CHIA.KnowledgeTree`) や Swift module 名 (`KnowledgeTree`) は無変更
- **タブアイコンは SF Symbol 標準**: `books.vertical` / `brain` で十分、カスタムアイコン不要
- **knowledge 数の重複排除**: name の `lowercased + trim` で同一視 (spec 008 と同パターン)
- **force-directed パラメータ**: 反発係数 200, バネ係数 0.05, 中心引力 0.02, dampening 0.85 で実機検証して微調整
- **ノード初期配置**: 中心からランダム (固定 seed なし、毎回違うが force-directed が安定化させる)
- **エッジ計算は AIBrainView の onAppear で 1 回**: refresh.version 変更で再計算
- **RecentActivity の「最近育ったテーマ」**: 直近 7 日で **新規追加された記事** に紐づくタグの件数で判定 (累計 article 数の差分は計算しない、シンプル化)
- **RecentActivity の「新しい繋がり」**: 直近 7 日に初めて Article から抽出された entity name (それ以前に同じ name は無い)。判定は KnowledgeEntity.knowledge.article.savedAt が 7 日以内かつ、それより古い同 name entity が無いこと
- **TabView の selected タブ永続化**: MVP では永続化なし。アプリ起動時は常に Tab 1 (ライブラリ)。将来 spec で AppStorage 検討

## ロールアウト

- 既存ユーザーへの破壊的変更は無い (ArticleListView 完全保持)
- アプリ名変更でホーム画面アイコン名が変わる (ユーザーに事前周知不要、自然に置換)
- Bundle Identifier 不変なので App Store 上の identity は維持
- spec 005 の RefreshTrigger は TabView root に 1 回配置するだけで両タブに伝播

## 非機能

- **メモリ**: KnowledgeMap の Canvas は GPU rendering、100 ノード + 200 エッジで peak 50MB 想定
- **電池**: パルスアニメーション + force-directed 反復は静的状態では実行しない (`.onAppear` で 1 回)
- **アクセシビリティ**: 全ノードに `accessibilityIdentifier`、VoiceOver で「タグ {name}、{N} 記事」読み上げ
- **Dynamic Type**: PowerGauge / カードのテキストはすべて `.body` / `.title2` で標準サイズに準拠
- **Dark Mode**: グラデーションは `Color(.systemBackground)` ベースで自動対応
