# Feature Specification: Dark/Light Mode 自動切り替え対応 (Apple-quiet 維持)

**Feature Branch**: `017-dark-mode-tokens`
**Created**: 2026-05-05
**Status**: Draft

## なぜ (Why)

spec 014 で導入した `DesignSystem.swift` (DS namespace) の 5 new tokens (`actionBlue` / `actionBlueFocus` / `parchment` / `knowledgeTile` / `tagFill`) は **RGB 固定値で定義** されており、Light Mode 専用。Dark Mode で iOS が auto-adapt するのは `.systemBackground` などの **iOS 標準 token のみ** で、カスタム token は変わらず Light 値のまま表示される。

結果:
- Dark Mode で `parchment` (off-white #faf8f3) が依然として明るいまま → 全体が「白いシミ」に見える
- `actionBlue` (#0a4d8c) が Dark の暗い背景上で読みづらい (deep blue は Light 専用設計)
- `tagFill` (#eaeaef) が Dark の chip 上で目立ちすぎ
- DESIGN.md (project root) の Known Gaps セクションでも「Dark mode: 未文書化 (現状 .systemBackground 任せ)」と明示

ユーザー要望 (実機検証時): iPhone の Dark/Light Mode 自動切り替えに正しく追随し、両モードで自然な視認性を確保したい。

本 spec は **DesignSystem.swift 一元** で全 5 カスタム token に Dark variant を追加し、view 個別改修ゼロ で Dark Mode 対応を実現する。

## ゴール

- 全カスタム token が Dark Mode で適切な色に auto-adapt
- view ファイル 18 個の改修ゼロ (token 経由で auto adapt)
- DESIGN.md の Migration Notes に Dark variant を記述、Light/Dark の対応表を追加
- Reduce Transparency 設定 ON でも機能不変
- Apple-quiet 路線 (single accent + gradient/shadow 全廃) を Dark でも維持

## 非ゴール

- Dynamic Type 全 view レイアウト崩れチェック → spec 019 (既知バグ修復) または別 spec
- iPad Split View 対応 → spec 033
- 各 view 個別の Dark Mode 視覚調整 (token 一元のみ本 spec、view 個別 polish は将来)
- Custom theme (ユーザーが accent color 選択) → 将来 spec
- High Contrast 対応 (`accessibilityIncreaseContrast`) → 別 spec
- Asset Catalog (Color Sets) への移行 → 別 spec (将来デザイナー流入時)
- 廃止予定 view (PowerGauge / KnowledgeMap / RecentActivityCards) の本格 Dark 調整 → spec 031 で view 自体削除予定、本 spec では alias 経由で auto adapt のみ確認

## ユーザストーリー

### US1 (P1) — iPhone Dark Mode で全画面が自然な視認性

**As a** iPhone を夜間に使う / Dark Mode 設定にしているユーザー
**I want** アプリの全画面が Dark Mode で読みやすい色で表示される
**So that** 目に優しく、夜間でも快適に保存記事の閲覧 / AI ブレインダッシュボード確認ができる

#### 受け入れ基準

- 設定 → 画面表示と明るさ → Dark に切替 → 1 秒以内に全画面 Dark 値で表示
- AI ブレインタブ:
  - 背景が parchment (#faf8f3) → Dark 値 (#1c1c1e)
  - Stats Row / Insight Card / Category List が Dark 値で表示、全文字列 contrast 確保
  - actionBlue が #0a4d8c → #3a8eef (明るく可読)
  - Category List の progress bar も明 actionBlue で識別可能
- ライブラリタブ:
  - ArticleListView の背景が Dark 値
  - ArticleRow の AI バッジ Capsule (actionBlue 0.08 alpha 背景) が Dark で識別可能
  - 各 chip / tag / entity 表示が Dark 値で読みやすい
- Category 詳細画面 (CategoryFilteredListView):
  - タグフィルターチップが Dark 値で視認可能 (選択中チップは actionBlue 明 + white text)
  - 「+N ▼」展開ボタンも Dark で視認可能
- ArticleDetailView:
  - 本文 DisclosureGroup「本文を読む」が Dark で視認可能
  - 関連記事セクション / KnowledgeSummaryView / EntityChip 全て Dark 適応

### US2 (P1) — Light Mode で従来通り自然な表示

**As a** Light Mode (デフォルト) ユーザー
**I want** spec 014/015/016 までの Apple-quiet 視覚体験が完全保持される
**So that** Dark Mode 対応の追加で従来挙動が壊れない (Light の視認性 / 色味が変わらない)

#### 受け入れ基準

- 起動時 Light Mode → spec 016 までと完全同一の表示 (色味 / 配置 / 視認性)
- Light Mode の actionBlue = `#0a4d8c` (変更なし)
- Light Mode の parchment = `#faf8f3` (変更なし)
- Light Mode の tagFill = `#eaeaef` (変更なし)
- 全 18 view で視覚的に変化ゼロ (Dark Mode 切替前は完全 spec 016 同等)

### US3 (P1) — システム自動切替に追随

**As a** iOS の「自動」モード (日中=Light / 夜=Dark) を使うユーザー
**I want** OS が時間帯で Light/Dark を切り替える際にアプリが追随する
**So that** 何も操作しなくても朝/夜で自然な見え方になる

#### 受け入れ基準

- iOS 設定で「自動」モード ON → 時刻に応じて Light/Dark 自動切替
- アプリは OS 通知に追随、画面表示が即時 (≤1 秒) 切り替わる
- アプリ起動中の切替時、State (タグ選択 / 折りたたみ展開等) は維持される
- バックグラウンド復帰時に Light/Dark の最新状態を反映

### US4 (P2) — Reduce Transparency 設定との互換性

**As a** アクセシビリティ設定で「透明度を下げる」を ON にしているユーザー
**I want** Dark Mode と組み合わせても機能が動作する
**So that** 視覚補助設定とアプリの両立が問題なく行える

#### 受け入れ基準

- 設定 → アクセシビリティ → 表示と文字サイズ → 透明度を下げる ON
- かつ Dark Mode ON
- アプリ全画面で機能不変 (フィルター / 折りたたみ / 検索 / Detail 表示等)
- 視認性が Light Mode 同等に維持される (blur 系を使っていない設計のため、影響軽微)

### Edge Cases

- **Dark Mode で `actionBlue.opacity(0.08)` が見えにくい**: Dark の actionBlue (#3a8eef) は明るいので opacity 0.08 でも識別可能、要視覚確認
- **廃止 view (PowerGauge / KnowledgeMap / RecentActivityCards) が Dark で破綻**: AIBrainView から外れているが alias で actionBlue 経由 → 破綻なし、ただし将来 spec 031 で view 自体削除予定
- **DesignSystem.swift 内 alias の Dark 影響**: 9 deprecated alias (aiBrandStart 等) は actionBlue や `.opacity()` 経由で auto adapt、明示的な Dark variant 不要
- **Share Extension のテーマ**: Share Extension は OS の sheet 上に出るので OS 側のテーマ追随、アプリ側は無干渉
- **iPad の Split View / Slide Over**: token 一元なので size class 関係なく Dark 適用される
- **Locale 切替 (将来 en_US 多言語化時)**: token は色のみ、locale 無関係で問題なし
- **App 起動直後に Dark → Light → Dark 急速切替**: SwiftUI/UIKit が auto-handle、State 維持に影響なし

## 機能要件

### 1. DesignSystem.swift の Dark variant 追加

- **FR-001**: `Color.adaptive(light:dark:)` static 関数を新設 (`Color` extension)
- **FR-002**: 内部実装は `Color(uiColor: UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })`
- **FR-003**: `actionBlue` を `Color.adaptive(light: <#0a4d8c>, dark: <#3a8eef>)` に書き換え
- **FR-004**: `actionBlueFocus` を `Color.adaptive(light: <#1565b8>, dark: <#5aa3f5>)` に書き換え
- **FR-005**: `parchment` を `Color.adaptive(light: <#faf8f3>, dark: <#1c1c1e>)` に書き換え
- **FR-006**: `knowledgeTile` を `Color.adaptive(light: <#f5f5f7>, dark: <#2a2a2c>)` に書き換え
- **FR-007**: `tagFill` を `Color.adaptive(light: <#eaeaef>, dark: <#2c2c2e>)` に書き換え
- **FR-008**: 既に adaptive な token (`overlaySubtle` / `overlayLight` / `overlayMedium` / `textEmphasis` / `surfacePrimary` / `surfaceSecondary`) は変更なし
- **FR-009**: 9 deprecated alias (aiBrandStart / End / Edge / NodeFill / NodeStroke / phaseEnrichment / phaseBody / phaseKnowledge / phaseTagging) は actionBlue 経由で auto adapt、明示的 Dark variant 追加不要

### 2. DESIGN.md の更新

- **FR-010**: DESIGN.md の `colors:` frontmatter セクションに Dark variant 記述を追加
- **FR-011**: Migration Notes セクションに「Dark Mode 対応 token 一覧」を追記
- **FR-012**: Known Gaps セクションから「Dark Mode: 未文書化」エントリを削除 (本 spec で解決)

### 3. view ファイル改修ゼロ

- **FR-013**: 全 18 view (ArticleRow / ArticleDetailView / AIBrainView / 等) は code 改修なし
- **FR-014**: 全 view は `DS.Color.actionBlue` 等の token 経由で参照、`Color.adaptive(...)` 内部実装に依存しない

### 4. テスト

- **FR-015**: `Color.adaptive(light:dark:)` の単体テスト (UITraitCollection の userInterfaceStyle で適切な color が返ることを検証)
- **FR-016**: 既存 unit test 全回帰 PASS (66+ 既存 + 27 spec 015/016 新規 = 93+ ケース)
- **FR-017**: xcodebuild build SUCCEEDED (warning ゼロ追加)

### 5. ストレスゼロ + Apple-quiet 原則 (DESIGN.md 準拠)

- **FR-018**: 単一 accent rule 維持 (Light/Dark どちらも actionBlue 1 色)
- **FR-019**: gradient / shadow / 多色 phase tint 全廃継続
- **FR-020**: Dark variant も落ち着いた彩度低色合い (Apple-quiet)

## 主要エンティティ

新規 @Model なし、新 schema migration なし。

### 改修ファイル

| File | 改修内容 |
|---|---|
| `KnowledgeTree/DesignSystem.swift` | `Color.adaptive(light:dark:)` extension 追加 + 5 tokens を adaptive 化 (8-12 行追加程度) |
| `DESIGN.md` | colors frontmatter に dark variant 追記 + Migration Notes 更新 + Known Gaps から Dark Mode を削除 |

### 新規ファイル

なし。

## 成功基準 (Success Criteria)

- **SC-001**: Light Mode 起動 → 全画面が spec 016 までと完全同一 (色味 / 配置 / 視認性が変わらない)
- **SC-002**: 設定 → 画面表示と明るさ → Dark に切替 → 1 秒以内に全画面 Dark 値で表示
- **SC-003**: Auto モードで日中/夜の自動切替に追随、State (タグ選択 / 折りたたみ等) 維持
- **SC-004**: AI ブレインタブ Dark 視覚 OK (Stats Row / Insight Card / Category List 全て contrast 適切)
- **SC-005**: Category 詳細画面 Dark 視覚 OK (タグフィルターチップ選択中=明 actionBlue / 未選択=Dark tagFill、+N 展開ボタン視認可能)
- **SC-006**: ArticleDetailView 本文 DisclosureGroup の Dark 視覚 OK (essence / KnowledgeSummary / 関連記事 / タグ / OG 画像 全て Dark 適応)
- **SC-007**: Reduce Transparency ON + Dark Mode で機能不変、視認性維持
- **SC-008**: Dark Mode 起動時のパフォーマンス (再描画 ≤100ms、60fps 維持)
- **SC-009**: 廃止 view (alias 経由) も Dark で破綻なし表示 (将来 spec 031 で削除予定だが現状維持)
- **SC-010**: 既存 unit test 93+ ケース全回帰 PASS、build warning ゼロ追加

## 依存・前提

- spec 014/015/016 が main マージ済 (現在 main = `66ab948`)
- iOS 26+ / iPadOS 26+
- 既存 SwiftData schema 完全保持 (Dark Mode と無関係)
- DesignSystem.swift の 5 new tokens (spec 014/015 で導入済) を再利用
- 全 18 view が DS.Color.* 経由で token 参照していること (spec 014 で確認済 154 件)

## アサンプション

- **`Color(uiColor: UIColor { trait in ... })` の SwiftUI 互換性**: iOS 14+ サポートで安定動作
- **UITraitCollection.userInterfaceStyle の追随性**: SwiftUI が自動で trait change を View に伝搬、明示的な `@Environment(\.colorScheme)` 不要
- **Dark variant の色値**: DESIGN.md の Apple-quiet 路線に準拠、誤差は微調整可能 (実機で違和感あれば fine-tune)
- **アクセシビリティ contrast**: WCAG AA 基準 (4.5:1) を満たす設計、ただし全 token の正式 contrast 計測は本 spec では実施せず実機目視で代替
- **既存 view の `.opacity(N)` 適用箇所**: opacity は base color に対して適用、base が adaptive なら opacity 後も adaptive 維持 (例: `actionBlue.opacity(0.08)` は Light/Dark 両対応)
- **Share Extension は無干渉**: OS sheet 上で表示され、アプリ側のテーマに影響受けない (DesignSystem を import しても影響なし)

## ロールアウト

- ユーザーへの破壊的変更:
  - Light Mode 表示は完全保持 (誰も影響受けない)
  - Dark Mode ユーザーは初めて適切な Dark 表示を見る (UX 向上のみ、機能損失なし)
- 既存データ完全保持
- View 改修ゼロ → 回帰リスク極小

## 非機能

- **パフォーマンス**: Dark/Light 切替時の再描画 ≤100ms、60fps 維持
- **アクセシビリティ**: WCAG AA 基準を満たす contrast、Reduce Transparency 互換、全 interactive 要素は accessibility 既存維持
- **Localization**: token は色のみで locale 無関係、既存日本語 UI に影響なし
- **iPad / iPhone 互換**: size class 関係なく統一、Apple-quiet 路線継続

## オープン質問

なし (確定済 Q&A 経由 8 点で全方針確定)。

将来 spec 候補:
- Dynamic Type 全 view レイアウト崩れ修正 (spec 019 or 別 spec)
- iPad Split View (spec 033)
- High Contrast 対応 (`accessibilityIncreaseContrast`)
- Custom theme (ユーザー accent color 選択)
- Asset Catalog 移行 (将来デザイナー流入時)
- 廃止 view (PowerGauge / KnowledgeMap / RecentActivityCards) のコード削除 (spec 031)
