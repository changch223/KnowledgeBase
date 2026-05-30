# Contract: Onboarding 廃止タブ案内修正 + xcstrings 化 (P0-2 / R2)

## 対象

- `KnowledgeTree/Views/OnboardingView.swift` (`pages` 配列 :23-48、`OnboardingPage` private struct)
- `KnowledgeTree/Localization/Localizable.xcstrings`

## 変更

### Page 4 文言 (学習タブ廃止対応)

| 要素 | before | after |
|---|---|---|
| symbol | `book.fill` | `book.fill` (維持) |
| title | 「家庭教師と一緒に学ぶ」 | 維持 (key 化) |
| body | 「『学習タブ』では AI が次に深めるべきカードを 5 つ提案。…」 | 「『知識 Clip』タブの『続きが気になる』から、AI 家庭教師と対話して理解を深められます。『✓ わかった』で理解度が育ちます。」 |

### 全 4 ページ + ボタン xcstrings 化

`OnboardingPage.title`/`.body` を表示時 `Text(LocalizedStringKey)` 化 (or `LocalizedStringResource`)。

| key | ja value (要点) |
|---|---|
| `onboarding.page1.title` / `.body` | ようこそ iKnow へ / 第二の脳 |
| `onboarding.page2.title` / `.body` | Share Sheet で保存 / 共有メニューから |
| `onboarding.page3.title` / `.body` | AI が自動で整理 / 概念ページ |
| `onboarding.page4.title` / `.body` | 家庭教師と一緒に学ぶ / **現行導線 (上記 after)** |
| `onboarding.skip` / `onboarding.next` / `onboarding.start` | スキップ / 次へ / はじめる |

## 契約条件

| 条件 | 期待 |
|---|---|
| onboarding 全 4 ページ走査 | 「学習タブ」「AIブレイン」リテラル 0 箇所 (SC-002) |
| Page 4 表示 | 現行 3 タブ導線 (知識 Clip → 続きが気になる → 家庭教師) を案内 |
| スキップ / 次へ / はじめる ボタン | 既存挙動維持 (`onboarding.skip` / `onboarding.next` id 維持) |
| OnboardingFlagStore 完了 flag | 無改修 |
| UI test 用 | 各ページ root に `onboarding.page.\(index)` id 付与 (任意) |
