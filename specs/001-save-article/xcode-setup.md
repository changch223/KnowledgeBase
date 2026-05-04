# Xcode セットアップ手順 (spec 001 / Round 2)

**対象**: Mac の Xcode に戻ったときに実施する手作業の一覧。
**前提**: Round 1 (Swift コード + テスト + extension ファイル) は既にディスク上に存在し、未コミット状態。

## 0. 現在の状態確認

ターミナルで:

```sh
cd ~/Desktop/KnowledgeTree
git status
```

期待される出力:
- `D KnowledgeTree/ContentView.swift`
- `D KnowledgeTree/Item.swift`
- `M KnowledgeTree/KnowledgeTreeApp.swift`
- `M specs/001-save-article/tasks.md`
- `?? KnowledgeTree/AppGroup.swift`
- `?? KnowledgeTree/KnowledgeTree.entitlements`
- `?? KnowledgeTree/Localization/`
- `?? KnowledgeTree/Models/`
- `?? KnowledgeTree/Services/`
- `?? KnowledgeTree/Views/`
- `?? KnowledgeTreeShareExtension/`
- `?? KnowledgeTreeTests/ArticleSavingServiceTests.swift`
- `?? KnowledgeTreeTests/SwiftDataArticleStoreTests.swift`
- `?? KnowledgeTreeUITests/SaveArticleUITests.swift`

⚠️ **このまま Xcode で開くとビルドは通りません** (新規ファイルがまだ target に登録されていないため)。Xcode 作業を完了するとビルドが通るようになります。

---

## 1. Xcode で project を開く

```sh
open KnowledgeTree.xcodeproj
```

Xcode が新規 Swift ファイル (Models/, Services/, Views/, AppGroup.swift) を自動的に検出する場合は **「Add to Xcode」を承認** する。検出されない場合は次のステップ 2 で手動追加する。

---

## 2. 既存ファイル群を `KnowledgeTree` target に追加

Project navigator (左ペイン) で `KnowledgeTree` グループを右クリック → **「Add Files to "KnowledgeTree"」**。以下を一括選択:

- `KnowledgeTree/AppGroup.swift`
- `KnowledgeTree/Models/Article.swift`
- `KnowledgeTree/Services/ArticleStore.swift`
- `KnowledgeTree/Services/ArticleSavingService.swift`
- `KnowledgeTree/Views/ArticleListView.swift`
- `KnowledgeTree/Views/EmptyStateView.swift`
- `KnowledgeTree/Views/SafariView.swift`
- `KnowledgeTree/Localization/Localizable.xcstrings`

ダイアログで:
- ✅ "Copy items if needed" は **OFF** (既にディスク上にあるので)
- ✅ "Create groups" を選択
- ✅ "Add to targets" → **`KnowledgeTree` のみ** を ON (Share Extension は target がまだ無いので後で)

テストも同様に追加:

- `KnowledgeTreeTests/ArticleSavingServiceTests.swift` → target: **`KnowledgeTreeTests`** のみ
- `KnowledgeTreeTests/SwiftDataArticleStoreTests.swift` → target: **`KnowledgeTreeTests`** のみ
- `KnowledgeTreeUITests/SaveArticleUITests.swift` → target: **`KnowledgeTreeUITests`** のみ

---

## 3. App Group capability を `KnowledgeTree` (app target) に追加

1. Project navigator で project root (一番上の青いアイコン) を選択
2. TARGETS から `KnowledgeTree` を選択
3. **Signing & Capabilities** タブを開く
4. 左上の **「+ Capability」** をクリック
5. 検索ボックスに `App Groups` と入力 → ダブルクリックで追加
6. 「+」ボタンで新規 App Group を追加し、ID として:
   ```
   group.com.changchiawei.KnowledgeTree.shared
   ```
   を入力 (※ Apple Developer Team のサブドメインに合わせて変更可。変更したら `KnowledgeTree/AppGroup.swift` の `identifier` 定数と両 entitlements ファイルの値も同じ ID に揃えること)
7. Xcode が自動生成した `KnowledgeTree.entitlements` が現れる場合があるが、**既に Round 1 で書いた `KnowledgeTree/KnowledgeTree.entitlements` を Build Settings の `CODE_SIGN_ENTITLEMENTS` に設定**:
   - Build Settings タブ → 検索ボックスに "Code Signing Entitlements" → 値を `KnowledgeTree/KnowledgeTree.entitlements` に
   - Xcode 自動生成の方が残ったら不要なので削除

---

## 4. Share Extension target を追加

1. Xcode メニュー → **File → New → Target...**
2. **iOS → Share Extension** を選択 → Next
3. 設定:
   - Product Name: **`KnowledgeTreeShareExtension`** (重要: ディスク上のディレクトリ名と一致させる)
   - Team: あなたの Apple Developer Team
   - Bundle Identifier: 自動 (例 `com.changchiawei.KnowledgeTree.KnowledgeTreeShareExtension`)
   - Language: Swift
   - Embed in Application: `KnowledgeTree`
4. Finish
5. 「Activate "KnowledgeTreeShareExtension" scheme?」 と聞かれたら **Cancel** (アプリ scheme のままでビルド時に extension も自動含まれる)

Xcode が自動生成した `ShareViewController.swift`、`Info.plist`、`MainInterface.storyboard` が新規 `KnowledgeTreeShareExtension` グループに作られる。

---

## 5. 自動生成ファイルを Round 1 の手書きに置き換え

Round 1 で既に手書きの `ShareViewController.swift` / `Info.plist` / `KnowledgeTreeShareExtension.entitlements` / `ShareReceivedItem.swift` をディスクに置いてあるため、Xcode 自動生成を削除して手書きを取り込む:

1. Xcode で自動生成の `ShareViewController.swift` を選択 → Delete → **「Move to Trash」** (ディスクから削除する)
2. 自動生成の `MainInterface.storyboard` も削除 — 本 spec では使わない (UIKit 直接構築)
3. Project navigator で `KnowledgeTreeShareExtension` グループを右クリック → **「Add Files to "KnowledgeTree"」**:
   - `KnowledgeTreeShareExtension/ShareReceivedItem.swift`
   - `KnowledgeTreeShareExtension/ShareViewController.swift` (Round 1 で書いた手書き版)
   - target: **`KnowledgeTreeShareExtension`** のみ ON
4. 自動生成の `Info.plist` を Round 1 の手書きに置き換える:
   - 自動生成の `Info.plist` を Xcode で右クリック → "Show in Finder" → `Finder` で削除
   - Round 1 で書いた `KnowledgeTreeShareExtension/Info.plist` を Xcode に Add Files → target: `KnowledgeTreeShareExtension` ON
   - Build Settings で `INFOPLIST_FILE` が `KnowledgeTreeShareExtension/Info.plist` を指していることを確認
5. `MainInterface` 参照を Info.plist から消した状態だと、`NSExtensionMainStoryboard` キーが残っていないことを確認 (Round 1 の Info.plist には書いていないので OK)

---

## 6. Share Extension に App Group capability を追加

1. TARGETS から `KnowledgeTreeShareExtension` を選択
2. Signing & Capabilities → 「+ Capability」→ App Groups → 追加
3. **app target と同じ ID** (`group.com.changchiawei.KnowledgeTree.shared`) を選択 (チェックボックスを ON にするだけで OK)
4. `KnowledgeTreeShareExtension/KnowledgeTreeShareExtension.entitlements` を Build Settings の `CODE_SIGN_ENTITLEMENTS` に設定 (Xcode 自動生成と置き換える)

---

## 7. Target Membership を両 target で共有

Project navigator で以下のファイルを 1 つずつ選択し、右ペインの **File Inspector** → **Target Membership** で **`KnowledgeTree` と `KnowledgeTreeShareExtension` の両方** にチェック:

- `KnowledgeTree/AppGroup.swift`
- `KnowledgeTree/Models/Article.swift`
- `KnowledgeTree/Services/ArticleStore.swift`
- `KnowledgeTree/Services/ArticleSavingService.swift`

Localizable.xcstrings も Share Extension からアクセスするため両 target ON 推奨:

- `KnowledgeTree/Localization/Localizable.xcstrings`

---

## 8. ビルド確認

1. Scheme は `KnowledgeTree` のままで ⌘B (Build)
2. エラーが出たら下の "トラブルシューティング" 参照
3. ビルドが通ったら ⌘R (Run) でシミュレータ起動 → 空状態 ("共有メニューから記事を追加してみよう") が表示されれば OK

### Share Extension の動作確認

1. シミュレータで Safari を起動
2. 任意の記事ページを開く (例: `https://www.apple.com/jp/newsroom/`)
3. アドレスバー右の共有ボタン → 共有シート → "KnowledgeTree" を探す
   - 出てこない場合: 共有シート末尾の「その他」→ 編集 → KnowledgeTree を ON
4. KnowledgeTree をタップ → 「保存しました」が表示 → 自動 dismiss
5. KnowledgeTree アプリに切り替え → 一覧に保存記事が表示される

### テスト実行

```sh
xcodebuild test \
  -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0'
```

`ArticleSavingServiceTests` (8 ケース) と `SwiftDataArticleStoreTests` (4 ケース) と `SaveArticleUITests` (1 smoke test) が pass すれば OK。

---

## 9. 動いたらコミット

```sh
cd ~/Desktop/KnowledgeTree
# Xcode が project.pbxproj を変更しているはず
git status
# Round 1 の Swift コード + Xcode project 変更を一括コミット
git add KnowledgeTree/ KnowledgeTreeShareExtension/ KnowledgeTreeTests/ KnowledgeTreeUITests/ KnowledgeTree.xcodeproj/ specs/001-save-article/
git commit -m "feat(spec-001): implement 記事保存 (Share Sheet 経由) — US1+US2+US3 + Share Extension"
git push  # 実機 / 別マシンに必要なら
```

---

## トラブルシューティング

### `Cannot find 'AppGroup' in scope` (in ShareViewController.swift)
→ ステップ 7 の `AppGroup.swift` Target Membership で `KnowledgeTreeShareExtension` が ON になっていない。

### `Cannot find 'Article' in scope` (同上)
→ `Article.swift` Target Membership 同上。

### App Group 関連の build エラー (`Provisioning profile "..." doesn't include the com.apple.security.application-groups entitlement`)
→ Apple Developer Portal でこの App Group ID を作成し、両 target の provisioning profile に追加が必要。シミュレータビルドだけなら "Automatically manage signing" を ON にすれば Xcode が自動でやる。

### Share Extension が共有シートに出てこない
→ シミュレータを再起動 + アプリを一度起動 (extension の登録が遅延するため)。それでも出ない場合は Info.plist の `NSExtensionActivationRule` を確認。

### `Could not create ModelContainer` で fatalError
→ Round 1 で App Group container を使う設定にしたため、entitlements が正しく wire されていない場合に発生。ステップ 3 + ステップ 6 を再確認。

### 既存の `Item.swift` が削除されているのに参照が残っている
→ project.pbxproj に残っているはず。Xcode で `Item.swift` を Project navigator から「Remove Reference」(Move to Trash ではなく) で project から削除。

---

## 完了マーカー

すべて成功したら `tasks.md` の以下を [X] に更新 (手動 or `sed`):

- T008 Share Extension target 追加
- T009 Extension entitlements wire
- T010 App Group capability on app target
- T011 Article + ArticleStore Target Membership
- T016 ArticleSavingService Target Membership
- T033 quickstart.md 手動検証 (動作確認済 + screenshot 撮影)

残るのは:
- T024 / T027 — UI test seed infra (別 PR で対応)
- T031 / T032 — Instruments 計測 (別 PR で対応)
- T035 — PR description リンクメモ
