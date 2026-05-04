# Contract: ShareReceivedItem (DTO)

**Layer**: Share Extension entry boundary
**Used by**: `ShareViewController` ↔ `ArticleSavingService`

## Purpose

`NSExtensionItem` から抽出した値を、`ArticleSavingService.save(url:suppliedTitle:)` に渡す前の中間表現として表す。Share Extension の UIKit / `NSExtensionItem` 詳細を Service 層に漏らさないための DTO。

## Definition

```swift
struct ShareReceivedItem: Equatable, Sendable {
    /// Share payload から抽出した URL。nil の場合は missingURL エラーとして
    /// 上位 (ArticleSavingService) で扱う。
    let url: URL?

    /// Share payload から抽出したタイトル候補。空または nil の場合は
    /// ArticleSavingService 側で url.host にフォールバックする (FR-009)。
    let suppliedTitle: String?
}
```

## Extraction logic (ShareViewController 側)

1. `extensionContext?.inputItems.first as? NSExtensionItem` を取得。
2. `item.attachments` から `UTType.url.identifier` に conform する最初の attachment を取得。なければ `ShareReceivedItem(url: nil, suppliedTitle: nil)`。
3. `attachment.loadItem(forTypeIdentifier:)` で `URL` を取得。
4. `item.attributedTitle?.string` または `item.attributedContentText?.string` から suppliedTitle を取得。
5. 上記から `ShareReceivedItem` を構築 → `ArticleSavingService.save(url: item.url, suppliedTitle: item.suppliedTitle)` に渡す。

## Why a separate DTO?

- `NSExtensionItem` は UIKit 由来かつ extension target でしか自然に扱えない。Service 層 (Share Extension とアプリ本体の両方から呼ばれる可能性あり) を汚染しないため。
- 将来 Safari Web Extension (Out of Scope) を実装するときも、同じ `ShareReceivedItem` で `ArticleSavingService` を呼び出す形に統一できる。
- テスト時、Mock の Share Extension 入力をシミュレートしやすい (struct を直接構築すればよい)。

## Tests

DTO 自体はロジックを持たないため単体テスト不要。`ShareViewController` 側の抽出ロジックを Mock `NSExtensionItem` で検証する unit test は、API 制約により省略 (quickstart.md の手動検証で担保。research.md / R6 参照)。
