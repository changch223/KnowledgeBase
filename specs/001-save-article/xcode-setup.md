# Xcode セットアップ手順 (spec 001 + 002 + 003 一括)

**対象**: Mac の Xcode に戻ったときに実施する手作業の一覧。
**前提**: spec 001 / 002 / 003 の実装コード (Swift / 設定ファイル / テスト) はすべて既にディスク上に存在し、未コミット状態。
**目標**: Xcode で wire up → ビルド → `xcodebuild test` 全 pass → Share Sheet 動作確認 → コミット → push。

---

## 0. 現在の状態確認

ターミナルで:

```sh
cd ~/Desktop/KnowledgeTree
git status
git log --oneline -6
```

期待される出力:
- 直前のコミット: `313bb90 docs: add specs 002 + 003, plus spec 001 Round 1 progress + Xcode setup guide`
- 未コミット: spec 001 Round 1 + spec 002 + spec 003 の Swift コード一式 (削除 2 / 修正 1 / 新規多数)

⚠️ **このまま Xcode で開くとビルドは通りません** (新規ファイルがまだ target に登録されていないため)。Xcode 作業完了後にビルドが通るようになります。

---

## 1. Xcode で project を開く

```sh
open KnowledgeTree.xcodeproj
```

---

## 2. すべての新規 Swift ファイルを `KnowledgeTree` target に追加

Project navigator で `KnowledgeTree` グループを右クリック → **「Add Files to "KnowledgeTree"」**。以下を一括選択 (Command-click で複数選択):

### spec 001 のファイル
- `KnowledgeTree/AppGroup.swift`
- `KnowledgeTree/Models/Article.swift`
- `KnowledgeTree/Services/ArticleStore.swift`
- `KnowledgeTree/Services/ArticleSavingService.swift`
- `KnowledgeTree/Views/EmptyStateView.swift`
- `KnowledgeTree/Views/SafariView.swift`
- `KnowledgeTree/Views/ArticleListView.swift`
- `KnowledgeTree/Localization/Localizable.xcstrings`

### spec 002 のファイル
- `KnowledgeTree/Models/ArticleEnrichment.swift`
- `KnowledgeTree/Services/URLSessionProtocol.swift`
- `KnowledgeTree/Services/MetadataParser.swift`
- `KnowledgeTree/Services/ArticleEnrichmentStore.swift`
- `KnowledgeTree/Services/ArticleEnrichmentService.swift`
- `KnowledgeTree/Views/ArticleRow.swift`
- `KnowledgeTree/Views/ThumbnailView.swift`
- `KnowledgeTree/Views/EnrichmentStatusBadge.swift`

### spec 003 のファイル
- `KnowledgeTree/Models/ArticleBody.swift`
- `KnowledgeTree/Services/ArticleBodyStore.swift`
- `KnowledgeTree/Services/BodyExtractionService.swift`
- `KnowledgeTree/Services/BodyExtractor.swift`
- `KnowledgeTree/Views/ReaderView.swift`
- `KnowledgeTree/Views/ReaderToolbar.swift`

### spec 004 のファイル
- `KnowledgeTree/Models/ExtractedKnowledge.swift` ← 3 @Model + 2 enum 集約
- `KnowledgeTree/Services/LanguageModelSessionProtocol.swift` ← Foundation Models ラッパ + Generable 型定義 (`import FoundationModels` あり)
- `KnowledgeTree/Services/KnowledgeExtractor.swift`
- `KnowledgeTree/Services/ArticleKnowledgeStore.swift`
- `KnowledgeTree/Services/KnowledgeExtractionService.swift`
- `KnowledgeTree/Views/EntityChip.swift`
- `KnowledgeTree/Views/KeyFactRow.swift`
- `KnowledgeTree/Views/KnowledgeSummaryView.swift`

ダイアログの設定:
- ✅ "Copy items if needed" は **OFF** (既にディスク上にあるため)
- ✅ "Create groups" を選択
- ✅ "Add to targets" → **`KnowledgeTree` のみ** を ON (Share Extension は未追加なので後で)

### テストファイル

`KnowledgeTreeTests` グループに追加 (Add to target: `KnowledgeTreeTests` のみ):
- `KnowledgeTreeTests/ArticleSavingServiceTests.swift` (spec 001)
- `KnowledgeTreeTests/SwiftDataArticleStoreTests.swift` (spec 001)
- `KnowledgeTreeTests/MetadataParserTests.swift` (spec 002)
- `KnowledgeTreeTests/SwiftDataArticleEnrichmentStoreTests.swift` (spec 002)
- `KnowledgeTreeTests/ArticleEnrichmentServiceTests.swift` (spec 002)
- `KnowledgeTreeTests/BodyExtractorTests.swift` (spec 003)
- `KnowledgeTreeTests/SwiftDataArticleBodyStoreTests.swift` (spec 003)
- `KnowledgeTreeTests/BodyExtractionServiceTests.swift` (spec 003)
- `KnowledgeTreeTests/KnowledgeExtractorTests.swift` (spec 004)
- `KnowledgeTreeTests/SwiftDataArticleKnowledgeStoreTests.swift` (spec 004)
- `KnowledgeTreeTests/KnowledgeExtractionServiceTests.swift` (spec 004)

`KnowledgeTreeUITests` グループに追加:
- `KnowledgeTreeUITests/SaveArticleUITests.swift` (spec 001)

---

## 3. App Group capability を `KnowledgeTree` (app target) に追加

1. Project navigator で project root (青いアイコン) を選択
2. TARGETS から `KnowledgeTree` を選択 → **Signing & Capabilities** タブ
3. 左上の **「+ Capability」** をクリック → `App Groups` をダブルクリック追加
4. 「+」で App Group ID を追加:
   ```
   group.com.changchiawei.KnowledgeTree.shared
   ```
   (※ Apple Developer Team のサブドメインに合わせて変更可。変更したら `KnowledgeTree/AppGroup.swift` の `identifier` 定数と両 entitlements ファイルの値も同じ ID に揃えること)
5. **Build Settings** タブ → 検索 "Code Signing Entitlements" → 値を `KnowledgeTree/KnowledgeTree.entitlements` に設定 (Xcode が自動生成した entitlements が出来た場合は削除)

---

## 4. Share Extension target を追加

1. Xcode メニュー → **File → New → Target...**
2. **iOS → Share Extension** を選択 → Next
3. 設定:
   - Product Name: **`KnowledgeTreeShareExtension`** (重要: ディスク上のディレクトリ名と一致させる)
   - Team: あなたの Apple Developer Team
   - Language: Swift
   - Embed in Application: `KnowledgeTree`
4. Finish (scheme activate は Cancel)

Xcode が自動生成する `ShareViewController.swift` / `Info.plist` / `MainInterface.storyboard` は次のステップで置き換える。

---

## 5. 自動生成ファイルを Round 1 の手書き版に置き換え

1. Xcode で自動生成の `ShareViewController.swift` を選択 → Delete → **「Move to Trash」**
2. 自動生成の `MainInterface.storyboard` も削除 (本 spec では使用しない)
3. Project navigator で `KnowledgeTreeShareExtension` グループを右クリック → **「Add Files to "KnowledgeTree"」**:
   - `KnowledgeTreeShareExtension/ShareReceivedItem.swift`
   - `KnowledgeTreeShareExtension/ShareViewController.swift` (Round 1 の手書き)
   - target: **`KnowledgeTreeShareExtension`** のみ
4. 自動生成の `Info.plist` を Round 1 の手書きに置換:
   - 自動生成の `Info.plist` を Finder で削除
   - 手書きの `KnowledgeTreeShareExtension/Info.plist` を Add Files → target: `KnowledgeTreeShareExtension` ON
   - Build Settings の `INFOPLIST_FILE` が `KnowledgeTreeShareExtension/Info.plist` を指すことを確認

---

## 6. App Group capability を Share Extension target にも追加

1. TARGETS から `KnowledgeTreeShareExtension` を選択
2. Signing & Capabilities → 「+ Capability」 → App Groups
3. **app target と同じ ID** (`group.com.changchiawei.KnowledgeTree.shared`) のチェックボックスを ON
4. Build Settings の `CODE_SIGN_ENTITLEMENTS` を `KnowledgeTreeShareExtension/KnowledgeTreeShareExtension.entitlements` に設定

---

## 7. Target Membership: 両 target で共有するファイル

Project navigator で以下のファイルを 1 つずつ選択し、右ペイン **File Inspector** → **Target Membership** で **`KnowledgeTree` と `KnowledgeTreeShareExtension` の両方** にチェック:

### 必須 (Article モデルが relationship で参照するため compile に必要)
- `KnowledgeTree/Models/Article.swift`
- `KnowledgeTree/Models/ArticleEnrichment.swift` ← spec 002 で追加された関係先
- `KnowledgeTree/Models/ArticleBody.swift` ← spec 003 で追加された関係先
- `KnowledgeTree/Models/ExtractedKnowledge.swift` ← spec 004 で追加された関係先 (3 @Model + 2 enum)
- `KnowledgeTree/AppGroup.swift`

### Share Extension が直接利用するもの
- `KnowledgeTree/Services/ArticleStore.swift`
- `KnowledgeTree/Services/ArticleSavingService.swift`
- `KnowledgeTree/Localization/Localizable.xcstrings` (Share Extension 内の status メッセージ用)

### Share Extension は使わない (KnowledgeTree only)
- `Services/ArticleEnrichmentStore.swift`、`ArticleEnrichmentService.swift`、`MetadataParser.swift`、`URLSessionProtocol.swift`
- `Services/ArticleBodyStore.swift`、`BodyExtractionService.swift`、`BodyExtractor.swift`
- `Views/*` (ArticleListView、ArticleRow、ThumbnailView、EnrichmentStatusBadge、ReaderView、ReaderToolbar、SafariView、EmptyStateView)
- (これらは KnowledgeTree target のみ ON)

---

## 8. ビルド & 自動テスト

```sh
# ビルド (warning も含めてチェック)
xcodebuild -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  clean build 2>&1 | grep -E '(warning|error)' | head -50

# テスト全 pass を確認
xcodebuild test \
  -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0'
```

期待:
- spec 001 tests: `ArticleSavingServiceTests` (8) + `SwiftDataArticleStoreTests` (4) + `SaveArticleUITests` (1)
- spec 002 tests: `MetadataParserTests` (13) + `SwiftDataArticleEnrichmentStoreTests` (5) + `ArticleEnrichmentServiceTests` (4)
- spec 003 tests: `BodyExtractorTests` (9) + `SwiftDataArticleBodyStoreTests` (7) + `BodyExtractionServiceTests` (5)
- 合計 約 56 テスト全 pass

---

## 9. Share Sheet からの動作確認 (実機 / シミュレータ)

### spec 001 (記事保存)
1. シミュレータで Safari → 任意の記事ページ → 共有 → KnowledgeTree → 「保存しました」
2. KnowledgeTree アプリを開く → 一覧に表示
3. 同 URL を再共有 → 「既に保存済みです」、重複なし
4. 行スワイプ削除 → アプリ再起動でも消えたまま

### spec 002 (enrichment)
5. 保存後 5 秒待つ → 一覧の行にサムネイル + canonical title + 説明文が表示される (enriched カード)
6. 機内モードで保存 → 「未取得」アイコン → 機内モード解除で自動 retry → enriched に置換

### spec 003 (Reader View)
7. enriched 表示の行をタップ → アプリ内 Reader View が開く (Safari View Controller ではない)
8. Reader View の「完了」で一覧に戻る、「元記事を開く」で SVC が重ねて開く
9. 抽出失敗の記事 (短すぎる本文等) は SVC 直行 (Reader 表示は試みない)

詳細は各 spec の `quickstart.md` 参照:
- `specs/001-save-article/quickstart.md`
- `specs/002-fetch-content/quickstart.md`
- `specs/003-extract-body/quickstart.md`

---

## 10. 動いたらコミット + push

ターミナルで:

```sh
cd ~/Desktop/KnowledgeTree
git status

# Round 1 (spec 001 + 002 + 003) の Swift コード + Xcode project 変更を一括コミット
git add KnowledgeTree/ KnowledgeTreeShareExtension/ KnowledgeTreeTests/ KnowledgeTreeUITests/ KnowledgeTree.xcodeproj/

git commit -m "feat(spec-001+002+003): implement 記事保存 + enrichment + Reader View"

git push
```

PR を作るなら:

```sh
gh pr create --base main --head 001-save-article --title "feat: spec 001-003 implementation" --body "..."
```

---

## トラブルシューティング

### `Cannot find 'AppGroup' in scope` (in ShareViewController.swift)
→ ステップ 7 で `AppGroup.swift` Target Membership で `KnowledgeTreeShareExtension` が ON になっていない。

### `Cannot find 'Article' / 'ArticleEnrichment' / 'ArticleBody' in scope` (in ShareViewController.swift)
→ Article は relationship で `enrichment` / `body` を持つため、Article.swift が compile するには ArticleEnrichment.swift と ArticleBody.swift も同じ target に含まれている必要がある。ステップ 7 で 3 つすべて両 target にチェック。

### App Group 関連の build エラー (`Provisioning profile "..." doesn't include the com.apple.security.application-groups entitlement`)
→ Apple Developer Portal でこの App Group ID を作成し、両 target の provisioning profile に追加が必要。シミュレータビルドだけなら "Automatically manage signing" を ON にすれば Xcode が自動でやる。

### Share Extension が共有シートに出てこない
→ シミュレータを再起動 + アプリを一度起動 (extension の登録が遅延するため)。それでも出ない場合は Info.plist の `NSExtensionActivationRule` を確認。

### `Could not create ModelContainer` で fatalError
→ App Group container が wire されていない。ステップ 3 + ステップ 6 を再確認。

### 既存の `Item.swift` / `ContentView.swift` が削除されているのに参照が残っている
→ Xcode で `Item.swift` / `ContentView.swift` を Project navigator から「Remove Reference」で project から削除 (ファイル自体はディスクにないので Move to Trash は不要)。

### enrichment の HTTP リクエストが失敗 (シミュレータ上)
→ シミュレータの Safari でその URL に手動でアクセスして開けるか確認。開けない場合はネットワーク設定の問題。開ける場合は ATS 設定 (`Info.plist` で `NSAllowsArbitraryLoads` を一時的に YES にして検証 → 確認後戻す) を疑う。本 spec は HTTPS のみなので HTTPS の証明書エラーがあれば別途対処。

### Reader View が出ない (タップしても SVC が出る)
→ ArticleBody.status が `.succeeded` になっていない。enrichment 完了後数秒で body 抽出が走るはず。`xcrun simctl spawn booted log stream --predicate 'process == "KnowledgeTree"'` で OS log を見ると進行状況がわかる。

### SwiftData の `#Predicate` で compile エラー
→ optional relationship を predicate 内で navigate する書き方が iOS 26 SDK で変わった可能性。`$0.enrichment == nil` のような単純な比較で回避し、複雑な navigation はコード側で filter する代替を取る。

### テストの一部が fail (Network 関連)
→ `ArticleEnrichmentServiceTests` は `MockURLSession` を使うため実ネットワーク不要。fail する場合は Mock の使い方を再確認。

---

## 完了マーカー

すべて成功したら `tasks.md` の Xcode UI 関連タスクを [X] に更新:

### spec 001 tasks.md
- T008 Share Extension target 追加
- T009 Extension entitlements wire
- T010 App Group capability on app target
- T011 Article + ArticleStore Target Membership
- T016 ArticleSavingService Target Membership
- T033 quickstart.md 手動検証

### spec 002 tasks.md
- T003-T005 SwiftData schema 変更 (実装側のコードは生成済、Xcode で Add Files + Target Membership で完了)
- (spec 002 の他のタスクは Swift code 生成で大半が完了)

### spec 003 tasks.md
- T003-T006 SwiftData schema 変更
- T007 ArticleBody.swift Target Membership

残るのは各 spec の **Polish phase** (Performance / Network 監視 / 手動検証 / PR description) — Mac で順次実施。
