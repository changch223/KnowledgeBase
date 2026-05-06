# Research: Chrome 連携 App Intents + iOS Shortcut (spec 019)

## R1 — AppIntent struct の構成

**Decision**: `SaveURLToKnowledgeTreeIntent` を `AppIntent` protocol 準拠で定義。`openAppWhenRun: false` でバックグラウンド完了、`return .result()` で silent return。

```swift
struct SaveURLToKnowledgeTreeIntent: AppIntent {
    static var title: LocalizedStringResource = "知積に保存"
    static var description: IntentDescription = IntentDescription(
        "URL を 知積に保存します",
        categoryName: "コンテンツ"
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "URL")
    var url: URL

    @Parameter(title: "タイトル", default: nil)
    var title: String?

    func perform() async throws -> some IntentResult {
        try await ArticleSavingActor.shared.save(
            url: url.absoluteString,
            title: title ?? ""
        )
        return .result()
    }
}
```

**Rationale**:
- iOS 16+ で確立された App Intents framework、Apple 公式パターン
- `openAppWhenRun: false` でアプリ起動を抑制、Personal Automation で silent 自動化
- `LocalizedStringResource` で日本語 UI 統合
- `@Parameter` で iOS Shortcuts UI に自動表示される入力フィールドを定義

**Alternatives considered**:
- INIntent (legacy SiriKit) → 廃止予定、AppIntents が後継
- `openAppWhenRun: true` → アプリが毎回起動、constitution V「不安喚起 UI 禁止」と整合しづらい
- `IntentResult` の代わりに `IntentDialog` で結果表示 → silent 仕様 (Q3=A) に反する、却下

## R2 — AppShortcutsProvider の自動登録

**Decision**: `AppShortcutsProvider` を実装、`appShortcuts` static プロパティを定義。インストール時自動で Shortcuts.app + Spotlight に登録される。

```swift
struct KnowledgeTreeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveURLToKnowledgeTreeIntent(),
            phrases: [
                "知積に保存",
                "URL を 知積に保存",
                "Save to \(.applicationName)",
            ],
            shortTitle: "保存",
            systemImageName: "square.and.arrow.down"
        )
    }
}
```

**Rationale**:
- iOS 16+ で AppShortcutsProvider に従ったアクションは **Shortcuts.app + Spotlight 検索 + Siri** に自動 expose
- ユーザーが手動でアクションを「アプリから追加」する操作不要 (Q10-D 改善案の核心)
- `phrases` は Siri 音声起動用、本 spec では副次効果
- `\(.applicationName)` placeholder で「KnowledgeTree」が動的に埋め込まれる
- `systemImageName: "square.and.arrow.down"` で SF Symbol アイコン (既存 Share Sheet と一貫)

**Alternatives considered**:
- 手動アクション登録 (旧 INVoiceShortcut) → AppShortcutsProvider が新標準、こちらが簡潔
- phrases 1 つだけ → Siri 認識率低下、複数語形が望ましい

## R3 — ArticleSavingActor の SwiftData アクセス

**Decision**: `actor ArticleSavingActor` を新設、singleton パターン (`shared`) + lazy ModelContainer cache。

```swift
actor ArticleSavingActor {
    static let shared = ArticleSavingActor()

    private var sharedContainer: ModelContainer?

    func save(url: String, title: String) async throws {
        let container = try getContainer()
        let context = ModelContext(container)
        _ = try Self.performSave(url: url, title: title, in: context)
    }

    private func getContainer() throws -> ModelContainer {
        if let existing = sharedContainer { return existing }
        AppGroup.ensureContainerDirectoryExists()
        let container = try ModelContainer(
            for: SharedSchema.all,
            configurations: [SharedSchema.sharedConfiguration()]
        )
        sharedContainer = container
        return container
    }

    /// testable 純粋関数: validation + 重複検出 + insert
    @discardableResult
    static func performSave(url: String, title: String, in context: ModelContext) throws -> Bool {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty,
              let parsed = URL(string: trimmedURL),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false  // silent skip on invalid
        }

        // 重複検出 (spec 001 同パターン)
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.url == trimmedURL }
        )
        if let _ = try? context.fetch(descriptor).first {
            return false  // silent skip on duplicate
        }

        let titleToUse = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? trimmedURL : title
        let article = Article(url: trimmedURL, title: titleToUse)
        context.insert(article)
        try context.save()
        return true
    }
}
```

**Rationale**:
- actor で thread safety 確保、App Intent から concurrent access 安全
- `getContainer()` 内で ModelContainer を lazy 生成 + cache、複数回保存呼び出し効率化
- `static performSave(url:title:in:)` は純関数、test で in-memory ModelContext で検証可能 (Q10 R10 採用案 B)
- spec 001 ArticleSavingService の重複検出ロジックを踏襲、URL 完全一致チェック
- `http/https` scheme 限定で `javascript:` / `mailto:` 等の無効 URL を弾く

**Alternatives considered**:
- `@MainActor` + 既存 ArticleSavingService 流用 → App Intent から MainActor へ jump コスト、actor 独立の方がシンプル
- ModelContainer を毎回 new → パフォーマンス悪化
- 依存注入で actor を test → singleton + static performSave で十分、過剰抽象化回避

## R4 — App Intent と SwiftData lifecycle

**Decision**: App Intent perform() 中に actor singleton + lazy ModelContainer。main app の RefreshTrigger は `ModelContext.didSave` 通知経由で auto reload (既存 spec 005 メカニズム)。

**Rationale**:
- App Intent は main app と同 process (target 別ではない、AppIntents framework が自動 register)
- App Group ModelContainer 共有で Share Extension と同パターン
- 保存後 `try context.save()` で SwiftData が `.didSave` 通知発行 → ArticleListView の RefreshTrigger が detect → auto re-fetch
- spec 005 RefreshTrigger / NotificationCenter / scenePhase live update メカニズム維持

**Alternatives considered**:
- App Intent target を別 extension にする → 不要、main app に同梱で OK (App Intents framework 自動 expose)
- 明示的な refresh notification 送信 → SwiftData の `.didSave` で十分

## R5 — SettingsView の構成

**Decision**: SwiftUI Form 形式、AI ブレインタブ右上の歯車から push 遷移。「外部連携」セクションに「Chrome から自動保存」エントリ。

```swift
struct SettingsView: View {
    @AppStorage("settings.shortcutSetupCompleted") private var setupCompleted: Bool = false

    var body: some View {
        Form {
            Section("settings.section.externalIntegration") {
                NavigationLink(value: ChromeSetupDestination()) {
                    HStack {
                        Image(systemName: "safari")
                            .foregroundStyle(DS.Color.actionBlue)
                            .frame(width: 24)
                        Text("settings.chromeSetup.entry")
                        Spacer()
                        if setupCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DS.Color.actionBlue)
                        }
                    }
                }
            }
        }
        .navigationTitle("settings.title")
        .navigationDestination(for: ChromeSetupDestination.self) { _ in
            ChromeShortcutSetupView()
        }
    }
}
```

**Rationale**:
- Form は SwiftUI 標準、iOS 設定アプリ風 UX で慣れ親しんだ
- `@AppStorage` で setupCompleted flag を UserDefaults に永続化、再起動でも保持
- Chrome icon は `safari` (Safari と同じ閲覧アプリイメージ)、actionBlue で統一
- セットアップ完了マーク (`checkmark.circle.fill`) で視覚フィードバック

**Alternatives considered**:
- List 形式 → Form の方が iOS 設定 UX に近い
- Section ヘッダ無し → 視認性低い
- @State でなく @AppStorage → 永続化必要、@AppStorage が適切

## R6 — ChromeShortcutSetupView の Step Card UI

**Decision**: 3 つの Step Card を縦並び。Step 1 のみ「Shortcuts アプリを開く」ボタン付き。「セットアップ完了」/「もう一度見る」切替ボタン。

```swift
struct ChromeShortcutSetupView: View {
    @AppStorage("settings.shortcutSetupCompleted") private var setupCompleted: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                Text("settings.chromeSetup.description")
                    .font(.body)
                    .foregroundStyle(.secondary)

                stepCard(number: 1, ...)
                stepCard(number: 2, ...)
                stepCard(number: 3, ...)

                if setupCompleted {
                    Button("settings.chromeSetup.resetLink") { setupCompleted = false }
                        .foregroundStyle(.secondary)
                } else {
                    Button("settings.chromeSetup.completeButton") { setupCompleted = true }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.Color.actionBlue)
                }
            }
            .padding(DS.Spacing.xxl)
        }
        .navigationTitle("settings.chromeSetup.title")
    }
}
```

**Rationale**:
- Step Card は数字付き Circle + actionBlue 背景 + white text、Apple-quiet 路線
- Step 1 内に「Shortcuts アプリを開く」ボタン (`shortcuts://` deeplink)
- 「セットアップ完了」ボタンで flag set、SettingsView に戻ると checkmark 表示
- 「もう一度見る」リンクで flag リセット可能 (ユーザーが Setup を再表示できる)
- `.dsCardBackground()` で既存 design token、Dark Mode (spec 017) auto adapt

**Alternatives considered**:
- 数字を SF Symbol `1.circle.fill` 使用 → カスタム Circle の方が actionBlue 統一できる
- Step ごとに アクションボタン (Step 2/3 にもデモ動画 button 等) → 将来 spec、本 spec MVP 最小

## R7 — AIBrainView 右上歯車 toolbar 追加

**Decision**: NavigationStack の toolbar に `ToolbarItem(placement: .topBarTrailing)` で歯車 NavigationLink を追加。

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        NavigationLink(value: SettingsDestination()) {
            Image(systemName: "gearshape")
                .foregroundStyle(DS.Color.actionBlue)
        }
        .accessibilityIdentifier("settings.button")
    }
}
.navigationDestination(for: SettingsDestination.self) { _ in
    SettingsView()
}
```

`SettingsDestination` は空 Hashable struct:
```swift
struct SettingsDestination: Hashable {}
```

**Rationale**:
- spec 016 / 018 の navigationDestination + Hashable struct パターン同様
- AI ブレインタブを起点にする理由: 「自分の AI が育つ庭」メタファーで設定もここに集約
- ToolbarItem `.topBarTrailing` で iOS 標準位置 (右上)
- accessibilityIdentifier "settings.button" で UI test 可能

**Alternatives considered**:
- ライブラリタブの右上に歯車 → 検索アイコンとの位置競合、AI ブレインタブの方が静か
- 知識 Clip タブ右上 → こちらは pull-to-refresh があり混雑、AI ブレインタブが best
- TabBar 4 つ目に「設定」タブ追加 → 過剰、歯車で十分

## R8 — AppIntent の Info.plist / entitlements 統合

**Decision**: Info.plist 改修なし、entitlements 改修なし。

**Rationale**:
- iOS 16+ AppIntents framework は AppShortcutsProvider の存在を自動 detect、Info.plist に明示 entry 不要
- App Group 共有は spec 001 既存設定 (`group.app.KnowledgeTree.shared`) で十分
- LSApplicationQueriesSchemes に Chrome の URL scheme を追加する必要なし (Personal Automation トリガーは OS レベル)
- `shortcuts://` deeplink は iOS Shortcuts URL scheme、`UIApplication.shared.open` で自動許可

**Alternatives considered**:
- Info.plist に `NSAppShortcutsAvailable = YES` 追加 → 不要 (AppShortcutsProvider が自動)
- App Group 別 identifier → 既存と分離する利点なし

## R9 — Localizable.xcstrings 新規文言

**Decision**: 13 文言を追加 (日本語のみ、英語 fallback は AppShortcutsProvider phrases にのみ含める)。

| Key | 日本語 |
|---|---|
| `settings.title` | 設定 |
| `settings.section.externalIntegration` | 外部連携 |
| `settings.chromeSetup.entry` | Chrome から自動保存 |
| `settings.chromeSetup.title` | Chrome 連携 |
| `settings.chromeSetup.description` | 以下の手順で Chrome を開いた時に自動保存できます。 |
| `settings.chromeSetup.step1.title` | Shortcuts アプリを開く |
| `settings.chromeSetup.step1.description` | 下のボタンをタップして Shortcuts アプリへ移動します。 |
| `settings.chromeSetup.openShortcutsButton` | Shortcuts アプリを開く |
| `settings.chromeSetup.step2.title` | 自動化を作成 |
| `settings.chromeSetup.step2.description` | 「自動化」→「個人用オートメーション」→「アプリ」→ Chrome を選択 →「開く」を選択。作成後「実行前に通知」を OFF にしてください。 |
| `settings.chromeSetup.step3.title` | アクションを追加 |
| `settings.chromeSetup.step3.description` | 「アクション追加」→ 検索で「知積」→「知積に保存」を選択。URL を「Chrome の現在の URL」に設定します。 |
| `settings.chromeSetup.completeButton` | セットアップ完了 |
| `settings.chromeSetup.resetLink` | もう一度見る |

**Rationale**:
- Constitution VII 整合 (日本語のみ、英語は将来 spec)
- Step 2 description に「実行前に通知 OFF」案内を入れる (R11 で説明)
- Step 3 の「Chrome の現在の URL」は iOS Shortcuts の標準アクション (Safari 専用、Chrome は要検証)

**Alternatives considered**:
- 英語版併記 → 将来 spec で対応、本 spec MVP は日本語 only

## R10 — テスト戦略

**Decision**: `SaveURLToKnowledgeTreeIntentTests` (5 ケース) を新設、`ArticleSavingActor.performSave(url:title:in:)` 静的純関数を in-memory ModelContext で検証。

```swift
@MainActor
struct SaveURLToKnowledgeTreeIntentTests {
    @Test func testSaveValidURLCreatesArticle() throws { ... }
    @Test func testSaveDuplicateURLSilentSkip() throws { ... }
    @Test func testSaveInvalidURLSilentSkip() throws { ... }
    @Test func testSaveWithoutTitleUsesURLAsTitle() throws { ... }
    @Test func testSaveWithTitleStoresTitle() throws { ... }
}
```

**Rationale**:
- `static performSave(url:title:in:)` は純関数 (input → bool output + context への副作用)、test しやすい
- in-memory ModelContainer + ModelContext で隔離、production App Group container を触らない
- App Intent struct (`perform()`) 自体の test は SwiftUI test framework での mock が複雑なので skip
- AppShortcutsProvider 自動登録は Shortcuts.app での手動確認 (実機検証)、unit test 不可

**Alternatives considered**:
- App Intent perform() の整合 test → AppIntents framework の mock 困難、static helper test で代替
- UI test で Setup Guide 遷移 → 実機検証で代替、本 spec で UI test 追加せず

## R11 — Personal Automation の制約と「実行前に通知」OFF

**Decision**: Setup Guide Step 2 description に「実行前に通知 OFF」案内を含める。

**Rationale**:
- iOS Personal Automation の default は「実行前に通知 ON」、ユーザーが毎回承認タップ必要
- ON のまま使うと constitution V「不安喚起 UI 禁止」と整合しない (毎回バナー)
- ユーザーに OFF にする方法を案内 (Setup Guide Step 2)
- iOS 17+ では Personal Automation の Settings で OFF 切替可能

**Alternatives considered**:
- ON のまま許容 → UX 悪化、不採用
- iOS から API で OFF 強制 → API なし、ユーザー操作必須

## R12 — Chrome x-callback-url の制約と現実的な解決

**Decision**: Chrome iOS の x-callback-url で「現在のタブ URL」を直接取得する API は存在しない。Setup Guide では「URL を Chrome の現在の URL に設定」と案内するが、実際の実現は iOS Shortcuts.app のアクション組み合わせ次第 (実機検証で確認)。

**実装方針**:
- 本 spec MVP では x-callback-url の詳細は研究せず、AppIntent + AppShortcutsProvider のみ実装
- ユーザーは Setup Guide Step 3 を見ながら Personal Automation を作成、URL 取得方法は Shortcuts.app 内で試行錯誤
- 実機検証で「Chrome の現在の URL を取得」アクションが動くか確認 → 動かなければ「クリップボード経由」or 「Share Sheet 経由」を将来 spec で改善

**Rationale**:
- Constitution II MVP 最小: 完璧な x-callback-url 実装は将来 spec、本 spec は基盤を提供
- Setup Guide は静的テキストで OK、ユーザーが iOS Shortcuts.app の UI で実装方法を選べる
- 仮に Chrome 自動 URL 取得が動かなくても、ユーザーが Shortcuts.app で「URL 入力 → 知積に保存」を手動 Shortcut として作れるので、価値ゼロにはならない

**Alternatives considered**:
- Chrome x-callback-url 詳細実装 → ドキュメント不明瞭、リスク高、将来 spec
- クリップボード経由を MVP 採用 → ユーザーが Chrome で URL コピー必要、操作増、却下

## DESIGN.md 整合確認

- 全 view が DS.Color.* 経由で Dark Mode (spec 017) auto adapt
- 単一 accent rule: actionBlue 1 色 (歯車 / Step Number Circle / setupCompleted checkmark / Setup ボタン全部)
- gradient / shadow / 多色 phase tint 全廃継続
- 通知 / バッジ / トースト 全廃 (constitution V)
- App Intent 完了は silent (dialog なし)
