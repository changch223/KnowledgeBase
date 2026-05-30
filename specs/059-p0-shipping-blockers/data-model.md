# Data Model: Sprint 1 P0 出荷ブロッカー修正

## SwiftData @Model 変更

**ゼロ。** 本 spec は永続化スキーマを一切変更しない (FR-013)。CloudKit Production schema deploy 不要。

## 既存 @Model (参照のみ、無改修)

| Model | 本 spec での関与 |
|---|---|
| `Article` | P0-4 引用リンクの遷移先 (ArticleDetailView)。参照のみ。 |
| `ChatMessage` | P0-4 引用リンクを含む AI 回答。表示挙動のみ調整、永続化変更なし。 |

## 新規 transient / closure

| 名前 | 型 | 配置 | 役割 |
|---|---|---|---|
| `onArticleLinkTap` | `((Article) -> Void)?` | `ChatMessageRow` の stored property (default `nil`) | 引用リンク tap 時に親 (ChatTabView) へ Article を通知する callback。永続化しない transient closure。 |

## xcstrings キー追加 (Localizable.xcstrings)

| key | 用途 | 由来 |
|---|---|---|
| `list.empty.instruction` | ライブラリ空状態の案内文 (「iKnow」含む) | P0-1 / R1 |
| `onboarding.page1.title` / `.body` | Onboarding 1 ページ目 | P0-2 / R2 |
| `onboarding.page2.title` / `.body` | Onboarding 2 ページ目 | P0-2 / R2 |
| `onboarding.page3.title` / `.body` | Onboarding 3 ページ目 | P0-2 / R2 |
| `onboarding.page4.title` / `.body` | Onboarding 4 ページ目 (現行導線、学習タブ廃止) | P0-2 / R2 |
| `onboarding.skip` / `onboarding.next` / `onboarding.start` | ボタン文言 | P0-2 / R2 (触る view) |

合計 ~12-15 文言。全て日本語 value、key は英語 dot-notation。

## 状態遷移

なし (本 spec は文言 + navigation 配線のみ、状態機械の追加なし)。
