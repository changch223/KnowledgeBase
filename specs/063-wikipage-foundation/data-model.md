# Data Model: WikiPage 土台

## SwiftData @Model 変更

**ConceptPage に 4 フィールド追加のみ** (全て default 付き = CloudKit lightweight migration 安全)。新 @Model ゼロ、rename ゼロ、削除ゼロ。

### ConceptPage 追加フィールド

| フィールド | 型 | default | 役割 |
|---|---|---|---|
| `bodyMarkdown` | `String` | `""` | AI が書く Wiki 本文 (Markdown)。要約 (summary) より詳しい全体像 |
| `kindRaw` | `String` | `"concept"` | 種別 rawValue (WikiPageKind) |
| `isHidden` | `Bool` | `false` | ユーザーが非表示にした |
| `bodyEditedByUser` | `Bool` | `false` | ユーザーが本文を訂正した (自動再生成の無断上書き防止) |

### ConceptPage 既存フィールド (無改修、WikiPage 素地として活用)

| 既存 | WikiPage 役割 |
|---|---|
| `name` / `nameAliases` | ページ名 |
| `summary` | 短い preview (bodyMarkdown と役割分離) |
| `crossSourceInsights` | 横断知見 (将来 bodyMarkdown に吸収) |
| `relatedArticles` (@Relationship.nullify) | 元記事 = Raw source (不変) |
| `relatedConceptIDs` | ページ間リンク素地 (spec 064 で `concept-id://` 解決) |
| `embedding` | 関係発見用ベクトル (spec 064) |
| `categoryRaw` | 分野 |
| `userUnderstanding` / `isFollowing` / `isStale` | spec 042-044 の蓄積 |

## 新規 enum

```swift
enum WikiPageKind: String, CaseIterable {
    case person      // 人物
    case concept     // 概念
    case project     // プロジェクト
}
```
computed `ConceptPage.kind` で rawValue 変換。表示名 (localizationKey) + SF Symbol を持つ。

## 永続化互換

- **CloudKit**: フィールド追加 (default 付き) は lightweight migration で安全。既存 `CD_ConceptPage` レコードは新フィールドを default で読む。
- **SharedSchema**: ConceptPage 登録済、**無改修**。
- **3 extension target** (Share/Safari/Widget): ConceptPage.swift は登録済、ファイル追加なし → pbxproj 無改修。

## 状態遷移

- **bodyMarkdown**: 空 (未生成) → AI 生成 → [ユーザー訂正 → bodyEditedByUser=true で保護] / [再生成は bodyEditedByUser=false の時のみ]
- **isHidden**: false → ユーザーが非表示 → true (一覧から除外、データは残る)
