# Research: 記事保存 (Share Sheet 経由) — Phase 0

**Feature**: spec 001 — 記事保存 (Share Sheet 経由)
**Date**: 2026-05-04
**Status**: Complete (全 NEEDS CLARIFICATION 解決)

本 spec の plan で発生した技術的な未解決点を以下にまとめる。各項目は Decision / Rationale / Alternatives の 3 部構成。

---

## R1. Share Extension とアプリ本体での SwiftData 共有

**Decision**: **App Group capability + `ModelConfiguration(groupContainer:)` で SwiftData の `ModelContainer` を共有する。**

App Group ID は `group.<reverse-domain>.knowledgetree.shared` (実値は Bundle ID 確定後に xcconfig / entitlements に記入)。`KnowledgeTreeApp` (アプリ本体) と `ShareViewController` (Share Extension) の両方で同一 App Group ID と同一 schema (`[Article.self]`) で `ModelContainer` を初期化することで、同じディスクストアを参照する。

**Rationale**:
- iOS App Extension は親アプリと別プロセスとして動作するため、データを共有するには App Group が事実上唯一の現実的な経路 (XPC は Apple Developer Program の制約あり)。
- SwiftData は `ModelConfiguration(groupContainer: .identifier("..."))` を公式サポート (iOS 17+)。
- SQLite ファイルは App Group container 配下に配置されるため両プロセスからアクセス可能。

**Alternatives considered**:
- **NSUserDefaults + シリアライズ**: 重複検出やリスト並べ替えが SQL クエリで効率的に書けず、Principle VI (層分離) 違反になる。
- **App Group 配下にファイル直書き (JSON 等)**: SwiftData が提供するクエリ・スキーマ進化の恩恵を捨てることになる。Constitution Additional Constraints も「SwiftData が単一の真実の源」と明記。

---

## R2. Share Extension の URL / Title 抽出パターン

**Decision**: **`NSExtensionItem.attachments` を走査し、`UTType.url` を `loadItem(forTypeIdentifier:)` で取り出す。Title は `NSExtensionItem.attributedTitle?.string` または `NSExtensionItem.attributedContentText?.string` から取得し、両方とも空ならフォールバックとして URL の host を使用 (FR-009)。**

実装スケッチ (実コードは tasks.md / 実装フェーズで):

```swift
guard
    let item = extensionContext?.inputItems.first as? NSExtensionItem,
    let attachment = item.attachments?.first(where: {
        $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
    })
else {
    // FR-008: URL なし → エラー表示して dismiss
    return
}

let suppliedTitle = item.attributedTitle?.string ?? item.attributedContentText?.string

attachment.loadItem(forTypeIdentifier: UTType.url.identifier) { value, error in
    guard let url = value as? URL else { /* エラー dismiss */ return }
    let title = (suppliedTitle?.isEmpty == false) ? suppliedTitle! : (url.host ?? url.absoluteString)
    // ArticleSavingService.save(url: url, title: title) を呼び出し
}
```

**Rationale**:
- Apple 公式の Share Extension API。Safari / Chrome / X / Slack 等、主要なアプリは全て `UTType.url` を含めて share する。
- `attributedTitle` はページタイトルが入る確率が高い (Safari / Chrome の挙動)。
- ホスト名フォールバックは spec の FR-009 に直接対応。

**Alternatives considered**:
- **`UTType.propertyList` で web page metadata を取得**: より豊富なメタデータが取れるが Safari Share Extension のみで動作。Chrome 等で fallback 必要なので最初から URL ベースで統一。
- **HTML の `<title>` を fetch してパース**: 本 spec はネットワーク禁止 (FR-010)。次 spec (本文取得) で扱う。

---

## R3. SwiftData による URL 重複検出クエリ

**Decision**: **`FetchDescriptor<Article>(predicate: #Predicate<Article> { $0.url == target }, fetchLimit: 1)` で 1 件取得し、結果が空かどうかで判定する。**

`@Attribute(.unique)` は **使用しない**。理由は次項。

**Rationale**:
- `fetchLimit = 1` を付けることで全件スキャンを回避 (パフォーマンスゲート / SC-009)。
- `url` プロパティに `@Attribute(.unique)` を付けるとデータベースレベルで重複が拒否されるが、insert 時に例外が throw され、エラーハンドリングが冗長になる。spec の挙動 (「既に保存済みです」と UI 表示) を実装するには明示的な事前 fetch のほうが UI とのつなぎが素直。
- `FetchDescriptor` 上で `predicate` + `fetchLimit` を使うのは SwiftData の標準パターンで、ドキュメント化されたサポート対象。

**Alternatives considered**:
- **`@Attribute(.unique)`**: 上記の通り例外ベースのフロー制御になり Principle VI / VII (UI 表現) と相性が悪い。
- **手動 in-memory cache (`Set<URL>`)**: プロセス間 (App ↔ Extension) で同期する仕組みが追加で必要になり Principle II (シンプル MVP) に反する。

---

## R4. SwiftUI から SFSafariViewController を表示

**Decision**: **`UIViewControllerRepresentable` でラップした `SafariView` 構造体を作り、`ArticleListView` の `.sheet(item:)` modifier で表示する。**

```swift
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
```

**Rationale**:
- `SFSafariViewController` は UIKit のため SwiftUI から直接使えない。`UIViewControllerRepresentable` でラップするのが Apple 公式パターン。
- `.sheet(item:)` は識別子付き optional Article をバインドし、選択された記事を遷移先 SVC に渡せる。
- 「完了」ボタンは `SFSafariViewController` の標準実装に含まれる (FR-006 / US2 シナリオ 2)。

**Alternatives considered**:
- **`Link` で外部 Safari に遷移**: アプリから離れてしまい UX が劣化 (US2 の「アプリから離れない」目的に反する)。
- **`WKWebView` を自前で表示**: 認証 cookie / リーダーモード / 既読履歴等の Safari 機能が失われる。SVC の既製機能を使う方が品質高。

---

## R5. Localizable.xcstrings の構成

**Decision**: **`KnowledgeTree/Localization/Localizable.xcstrings` を作成し、初期言語を「ja (日本語)」に設定。すべての UI 文言キーを `LocalizedStringKey` で参照。**

主要なキー (spec から抽出):

| Key | 表示文言 | 由来 |
|---|---|---|
| `share.duplicateMessage` | 既に保存済みです | FR-015 |
| `share.errorNoURL` | URL が見つかりません | Edge Case |
| `share.errorUnsupportedScheme` | 対応していない URL です | Edge Case |
| `share.errorStorage` | 保存に失敗しました | Edge Case |
| `share.savedConfirmation` | 保存しました | US1 シナリオ 1 |
| `list.empty.title` | 共有メニューから記事を追加してみよう | FR-013 |
| `list.deleteAction` | 削除 | US3 |
| `safari.doneButton` | 完了 (※ OS 標準) | US2 シナリオ 2 |

**Rationale**:
- iOS 17+ で `.xcstrings` (String Catalog) が標準化され、`.strings` よりレビュー / マージ容易。
- 初期言語が日本語であることで Constitution Principle VII を構造的に強制 (キーはコード上 `LocalizedStringKey`、文字列リテラルが英語で散在することを防ぐ)。
- 将来の英語ローカライズ追加時は xcstrings に列を 1 つ追加するだけで済む。

**Alternatives considered**:
- **`.strings` (旧形式)**: マージ衝突しやすく、複数言語管理時に煩雑。
- **コード内ハードコード**: Principle VII / FR-011 違反。

---

## R6. Share Extension Target の追加手順とテスト戦略

**Decision**: **Xcode の File → New → Target → Share Extension で `KnowledgeTreeShareExtension` を追加。`NSExtensionActivationRule` を `NSExtensionActivationSupportsWebURLWithMaxCount = 1` に設定して URL を受理する。`ShareViewController` は薄く保ち、URL/Title 抽出 → `ArticleSavingService.save(...)` 呼び出し → `extensionContext.completeRequest` の最小実装に留める。**

テスト戦略:
- **Service 層 (`ArticleSavingService`) のロジックは unit test で完全カバー** (重複検出 / 通常保存 / FR-009 タイトルフォールバック / FR-008 URL 不在エラー)。
- **`ShareViewController` 自体は最小限**。XCTest からの自動 UI テストは extension target に対して制約が大きい (シミュレータで Share Sheet を呼び出して Extension を起動する自動化はサポートが限定的) ため、quickstart.md に手動検証手順を明記して MVP では手動担保。
- **アプリ本体側の 一覧 / 削除 / 内蔵ブラウザビュー遷移は `KnowledgeTreeUITests` で自動化**。

**Rationale**:
- ビジネスロジックを Service 層に集約することで、テスト不能な extension UI に依存せず Constitution テストゲートを満たせる。
- 手動検証はリスクだが、Share Extension の自動 UI テストは業界全体で複雑性が高く、MVP 段階で過剰投資を避ける Principle II 判断。

**Alternatives considered**:
- **`SLComposeServiceViewController` (旧来 UIKit ベース)**: より UI 表示に向くが、本 spec は auto-save → 自動 dismiss なので UI を出さない。`UIViewController` ベースの最小実装で十分。
- **Share Extension に SwiftUI を埋め込む**: 可能だが Apple 推奨は最小 UI なのでオーバーキル。
- **Universal Links + URL Scheme で App Body をフォアグラウンド遷移して保存**: 共有 → アプリが立ち上がる動線が Principle V (落ち着いた UX) と相性悪。

---

## 追加メモ (NEEDS CLARIFICATION なし)

- **App Group ID の確定**: 実 Bundle ID (Team ID) が決まっていないため、tasks.md の最初に「App Group ID 確定」タスクを置き、xcconfig 化する。
- **Apple Intelligence 対応端末縛り**: spec 001 自体は Foundation Models 不使用だが、Constitution Principle IV により最低 deployment target は iOS 26+。`SystemLanguageModel.availability` のチェックは spec 003 (要約) 着手時に導入する。
- **constitution の deferred TODO** (`TARGETED_DEVICE_FAMILY = "1,2,7"` の `"1,2"` への絞り込み、macOS deployment target の整理) は本 spec の plan では扱わないが、実装フェーズで Xcode project を触る際に同時に対応すると効率が良い。
