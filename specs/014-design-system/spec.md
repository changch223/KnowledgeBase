# Feature Specification: 統一デザインシステム + Phase 3/4 視覚改善

**Feature Branch**: `014-design-system`
**Created**: 2026-05-05
**Status**: Draft (retroactive — 実装が先に working tree に存在し、spec 化はその documentation)

## なぜ (Why)

spec 011 で AI ブレインタブを追加し、spec 012 / 013 で auto-tag 機能を完成させた段階で、UI 全体を見渡すと:

1. **マジックナンバーが散在**: `cornerRadius: 16` / `padding(.vertical, 12)` / `.opacity(0.18)` 等が各 view にハードコード
2. **アニメーションが不揃い**: 同じ意味 (status 表示の出現) でも `easeInOut(0.2)` / `spring()` / `easeOut(0.6)` が混在
3. **Reduce Motion 未対応**: アクセシビリティ設定で「視差効果を減らす」を ON にしても、PowerGauge のパルス / カウントアップ / ノード fade-in がそのまま動く
4. **AI ブレイン系の視覚密度が低い**: PowerGaugeCard / KnowledgeMap / RecentActivityCards は機能は揃ったが、Apple 純正アプリ (Weather / Health / Fitness) と比べると見た目が flat
5. **ArticleRow / Detail / EmptyStateView の polish 不足**: 機能 OK だが iOS 26 の表現力を活かせていない

これらを **デザイントークンの統一** + **Phase 3-4 の視覚改善** で一括解決する。新機能追加ではなく **リファクタリング + 視覚 polish**。

ユーザー体験:
- AI ブレインタブが Apple Weather / Health 風の質感に
- ArticleRow が「knowledge 完了記事は左端に色付きアクセント」で一目で識別可能
- EmptyStateView が静的な状態から「優しく動く」入場体験に
- Reduce Motion ON でも動作 (アニメは静止する、機能は不変)

## ゴール

- 全 view (18 個) で magic number 駆逐 → 1 つの `enum DS` に集約
- AI ブレイン系 4 view (PowerGaugeCard / KnowledgeMapView / RecentActivityCards / AIBrainView) の視覚密度向上 (material / gradient / shadow / pill)
- ArticleRow / ArticleDetailView / EmptyStateView の polish (リーディングエッジ / 入場アニメ等)
- `UIAccessibility.isReduceMotionEnabled` 対応で全装飾アニメをガード
- データ層 / Service 層は完全無改修 (新 @Model / 新 schema / 新 service ゼロ)

## 非ゴール

- 新機能の追加 (本 spec はリファクタ + 視覚改善のみ)
- spec 008 / 011 / 012 / 013 の機能挙動の変更
- Localizable.xcstrings への大幅追加 (EmptyStateView 1 文言 + 既存 auto-extract のみ)
- iPad 専用レイアウト (本 spec では iPhone と同じ表現で OK)
- ライト / ダークの Color asset カタログ化 (DS.Color は Color literal で直接定義、将来 spec で asset 化検討)
- 全 view の Constitution Per-PR ゲート (UI 影響 PR のスクショ添付 + iPhone / iPad 両方確認) は遡及 spec のため事後

## ユーザストーリー

### US1 (P1) — AI ブレインタブの視覚密度向上

**As a** AI ブレインタブを開いて自分の AI が育っていることを確認したいユーザー
**I want** Apple Weather / Health 風の質感ある表現で「育ってる感」を体感
**So that** 機能だけでなくビジュアル的にも「自分の AI」と感じられる

#### 受け入れ基準

- PowerGaugeCard が `.ultraThinMaterial` + AI gradient + specular highlight (上端 40pt 白フェード) + hairline border の 4 層構造
- KnowledgeMap のエッジが gradient stroke (源ノードから外へフェード)、ノードが radial gradient + drop shadow + ラベル背景 pill (capsule)
- RecentActivityCards のアイコンが Apple Health 式の色付き円形背景 (accentColor / green / purple)
- AIBrainView 上部に full-bleed AI brand gradient (300pt、Apple Weather 風)
- パルスアニメは `scaleEffect` でなく `shadow(radius:)` で表現 (jitter 防止)

### US2 (P1) — Reduce Motion 対応

**As a** 視差効果を減らす設定を ON にしているユーザー
**I want** 装飾アニメ (パルス / カウントアップ / ボブ等) がすべて停止
**So that** 設定通りの体験が得られる

#### 受け入れ基準

- PowerGauge の数字 0 → N カウントアップが Reduce Motion ON で即時表示に
- PowerGauge のパルス (shadow radius pulse) が ON で停止
- EmptyStateView の入場 / ボブが ON で静止
- KnowledgeMap の新ノード fade-in は影響 (本 spec では guard 入れる必要があれば追加)
- 機能は変わらない (タグ付与 / 数字更新 / ノード追加 はそのまま)

### US3 (P2) — ArticleRow で knowledge 完了の一目識別

**As a** 大量の記事を保有しているユーザー
**I want** どの記事の AI 抽出が完了しているかを一覧で一目で識別
**So that** 「読みたい記事 (= AI 抽出済)」を素早く見つけられる

#### 受け入れ基準

- knowledge 抽出 succeeded 記事のみ、ArticleRow 左端に 3pt 縦バー (`aiBrandEnd` 色) が表示
- `accessibilityHidden(true)` で VoiceOver ノイズを抑制
- 抽出未完 / failed 記事には縦バーが表示されない (= 一目で区別可能)
- 「AI 生成」ラベルは平文から Capsule バッジに変更 (`aiBrandEnd.opacity(0.08)` 背景)

### US4 (P2) — EmptyStateView の優しい入場体験

**As a** 新規インストール直後でまだ記事を保存していないユーザー
**I want** 空状態が単調でなく「優しく動く」表現で歓迎される
**So that** Share Sheet で記事を保存しようというモチベーションが湧く

#### 受け入れ基準

- アプリ起動時、tray アイコンが scale 0.8 → 1.0 で入場
- 静止後、scale +0.03 / -0.03 周期 (2 秒) でゆっくりボブ
- 「Safari で記事を開いて「共有」→ アプリ名 で保存できます」案内テキスト追加
- Reduce Motion ON で 入場 / ボブ 共に停止

### Edge Cases

- **Reduce Motion ON + 起動**: 全装飾アニメ停止、機能不変
- **Dark Mode 切替中**: DS.Color のグラデーション / overlay / textEmphasis が両モードで自然
- **Dynamic Type 最大**: DS.Typography トークン (heroCounter 等) で文字が拡大、レイアウト崩れない
- **iPad での表示**: 18 view は spec 011 まで iPhone レイアウト前提だが、iPad でも崩れず動作
- **AI バッジが付いた article (= knowledge 完了) 1 件 + 付いてない 1 件のリスト**: leading edge accent の有無で一目判別可

## 機能要件

### 1. デザイントークン namespace

- **FR-001**: `KnowledgeTree/DesignSystem.swift` に `enum DS` を新設、すべてのトークンの single source of truth
- **FR-002**: `enum Color` で 16 種のセマンティック Color を定義 (surface / overlay / aiBrand* / phase* / textEmphasis)
- **FR-003**: `enum Spacing` で 9 段階 (xxs:2 / xs:4 / sm:6 / md:8 / lg:10 / xl:12 / xxl:16 / xxxl:20 / section:24)
- **FR-004**: `enum Radius` で 4 段階 (thumb:8 / chip:12 / card:16 / hero:20)
- **FR-005**: `enum Typography` で 10 種の Font + bodyLineSpacing(8)
- **FR-006**: `enum Animation` で 7 種の Animation スタイル + `ifMotionAllowed(_:)` Reduce Motion ガード関数
- **FR-007**: `extension View` で `dsCardBackground()` / `dsAIGradientBackground()` ViewModifier を提供
- **FR-008**: DesignSystem.swift は `import SwiftUI` のみ依存 (SwiftData 不要 → Share Extension からも参照可能)

### 2. 18 view への一括適用 (Phase 2)

- **FR-009**: 18 view のマジックナンバー (`cornerRadius` / `padding` / `spacing` / `Color literal opacity`) を全部 DS.* に置換
- **FR-010**: 既存挙動 / レイアウト / 体感サイズは変更しない (置換のみ)
- **FR-011**: BottomStatusBar の phase tint color は `DS.Color.phase*` を使う

### 3. AI ブレイン視覚再設計 (Phase 3)

- **FR-012**: PowerGaugeCard を 4 層 ZStack で再構築 (material + AI gradient + specular highlight + content)
- **FR-013**: PowerGaugeCard に Mini-stats cluster を導入 (知識/キーファクト数を縦並び 2 列、Divider 区切り、monospacedDigit)
- **FR-014**: PowerGauge のパルスは shadow(radius:) で表現 (scale jitter 廃止)
- **FR-015**: KnowledgeMap のエッジを linearGradient stroke、ノードを radial gradient + drop shadow + ラベル pill
- **FR-016**: RecentActivityCards のアイコンを iconBadge() ヘルパー経由で円形色付き背景に
- **FR-017**: AIBrainView 上部に full-bleed AI brand gradient (height 300pt、Apple Weather 風)
- **FR-018**: AIBrainView に `.navigationBarTitleDisplayMode(.large)` + `.scrollIndicators(.hidden)` を適用

### 4. 一覧 + 詳細 polish (Phase 4)

- **FR-019**: ArticleRow を HStack で再構成 (leading edge accent 3pt 縦バー + 既存 VStack)
- **FR-020**: ArticleRow の AI バッジを Capsule 化 (背景 capsule + `aiBrandEnd.opacity(0.08)`)
- **FR-021**: ArticleListView に `.listStyle(.plain)` 適用 + 完了記事のセパレータ非表示
- **FR-022**: ArticleDetailView の OG 画像 200pt + フェードオーバーレイ + ローディング背景ピル + ボタンスタイル刷新
- **FR-023**: EmptyStateView に入場アニメ (scale 0.8 → 1.0) + ボブ演出 + Share Sheet 案内テキスト

### 5. アクセシビリティ + UX 一貫性

- **FR-024**: 全装飾アニメは `DS.Animation.ifMotionAllowed(...)` で Reduce Motion ガード
- **FR-025**: leading edge accent 等の装飾要素には `accessibilityHidden(true)` で VoiceOver ノイズを抑制
- **FR-026**: Dynamic Type 最大サイズで全 18 view のレイアウトが崩れない
- **FR-027**: Dark Mode で全グラデーション / overlay / textEmphasis が自然な見た目
- **FR-028**: 既存 accessibilityIdentifier は保持 (UI test 互換性)

### 6. データ層保持

- **FR-029**: 新 @Model / 新 schema / 新 migration ゼロ
- **FR-030**: 全 Service / Store / Model / Spec 001-013 の機能挙動は変更しない
- **FR-031**: SwiftData / Foundation Models / BGTaskScheduler 連携は変更しない

## 主要エンティティ

新規スキーマなし。デザイントークンは `enum DS` の static let のみ (transient、永続化対象外)。

詳細は `data-model.md` 参照。

## 成功基準 (Success Criteria)

- **SC-001**: 18 view のマジックナンバーがすべて DS.* に置換され、`grep -r "cornerRadius: [0-9]"` などで magic number が出ない (除外: PowerGauge / KnowledgeMap 等の SwiftUI 標準パラメータでトークンに該当するものがないケース)
- **SC-002**: PowerGaugeCard が 4 層 ZStack で表示され、specular highlight が上端に視認可能
- **SC-003**: KnowledgeMap のエッジが gradient (中央薄)、ノードが radial gradient + drop shadow で表示
- **SC-004**: ArticleRow で knowledge 完了記事のみ左端 3pt 縦バーが表示
- **SC-005**: Reduce Motion ON で全装飾アニメが停止 (機能は変わらない)
- **SC-006**: 既存 unit テスト (66 ケース) が全 PASS (data 層 / Service 層に影響なし)
- **SC-007**: build 成功 + 本 PR 起因の警告ゼロ

## 依存・前提

- spec 001-013 までの全機能が稼働済 (本 spec はそれら view への視覚 polish)
- iOS 26+ / iPadOS 26+ (Constitution: Apple Intelligence 対応端末)
- 既存 SwiftData schema 完全保持

## アサンプション

- **Color literal vs Asset Catalog**: DS.Color は Color literal で直接定義 (例: `Color.accentColor.opacity(0.15)`)。将来 spec で asset 化検討
- **iPad 対応**: 本 spec で個別レイアウト調整なし、SwiftUI の adaptive layout に任せる
- **Localizable.xcstrings**: EmptyStateView の Share Sheet 案内 1 件追加、他は既存
- **既存 UI test 互換性**: accessibilityIdentifier はすべて保持、機能テストは pass する想定

## ロールアウト

- データ層無改修なので backward compatible 100%
- 既存ユーザーは「見た目が新しくなった」と感じるのみ、機能変化なし
- Reduce Motion ON ユーザーは静的な体験で機能不変

## 非機能

- **パフォーマンス**: 装飾増加だが、Canvas / SwiftUI レンダリングは GPU、既存 60fps 維持
- **メモリ**: 増加なし (トークンは static let、Color/Animation/Spacing 等は flyweight)
- **アクセシビリティ**: Reduce Motion / VoiceOver / Dynamic Type / Dark Mode 全対応
- **ローカライゼーション**: 1 件追加 (EmptyStateView 案内文)

## オープン質問

なし (本 spec は遡及 documentation、実装は確定済)。

将来 spec で扱う候補:
- **Asset Catalog 化**: DS.Color を Color asset に移行、ライト / ダーク手動指定可能に
- **iPad 専用レイアウト**: GeometryReader + size class で iPad 用の AI ブレインタブ
- **DS Token Test**: DS.Color / Spacing 等の値を unit test で固定化 (regression 防止)
