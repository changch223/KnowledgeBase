# Research: Sprint 1 P0 出荷ブロッカー修正

各 P0 の修正方式を実コード照合で確定。行番号は 2026-05-30 main @ `c592654` 時点。

---

## R1: P0-1 EmptyStateView 文言修正 + xcstrings 化

**Decision**: `Views/EmptyStateView.swift:28` の `Text("Safari で記事を開いて「共有」→ アプリ名 で保存できます")` を xcstrings key `list.empty.instruction` に置換し、value で「アプリ名」→「iKnow」修正。

**Rationale**:
- 既に `list.empty.title` key が同 view (line 23) で使われており、命名規則 `list.empty.*` に揃う。
- 触る view なので xcstrings 化方針 (ユーザー確定)。127 empty key 全体整理 (P2-10) は別 spec。
- 既存 accessibilityIdentifier `articleListEmpty` (line 36) を UI test の label 検証に活用。

**Alternatives considered**:
- リテラル直接修正のみ (xcstrings 化なし) → ユーザーが「触る view は key 化」を選択したため却下。

**実装メモ**: 1 文言追加 + 1 行変更。`Text("list.empty.instruction")` (LocalizedStringKey 自動)。

---

## R2: P0-2 OnboardingView Page 4 書き換え + 4 ページ xcstrings 化

**Decision**: `Views/OnboardingView.swift:23-48` の `pages` 配列 (private struct `OnboardingPage`、title/body が String ハードコード) を xcstrings key 化。Page 4 の「学習タブ」案内を現行 3 タブ導線に書き換え。

**現状 (verified)**:
- Page 4 (`:42-47`): symbol `book.fill` / title「家庭教師と一緒に学ぶ」/ body「『学習タブ』では AI が次に深めるべきカードを 5 つ提案。タップで家庭教師と対話、『✓ わかった』で理解度が育ちます。」
- 学習タブは spec 056 V3.0 で廃止。現 3 タブ = 知識 Clip / ライブラリ / AI チャット。
- 家庭教師導線 (DeepDiveChatView) は現在 **知識 Clip タブの「続きが気になる」セクション**から到達。

**Page 4 新文言 (案)**:
- symbol: `book.fill` 維持 (or `sparkles`)
- title: 「家庭教師と一緒に学ぶ」維持 (タブ名に依存しないため OK)
- body: 「『知識 Clip』タブの『続きが気になる』から、AI 家庭教師と対話して理解を深められます。『✓ わかった』で理解度が育ちます。」

**Rationale**:
- タブ名「学習タブ」を現行導線の説明に置換すれば、新規ユーザーが存在しない機能を探さない。
- 全 4 ページを key 化することで OnboardingView 全体の文言が将来ローカライズ可能に (触る view 方針に合致)。

**実装メモ**:
- `OnboardingPage.title`/`.body` を `String` → `LocalizedStringResource` or 表示時 `Text(LocalizedStringKey)` 化。private struct なので影響局所。
- key: `onboarding.page1.title`/`.body` 〜 `onboarding.page4.title`/`.body` (8 文言)。「スキップ」「次へ」「はじめる」「ようこそ iKnow へ」等もこの機会に key 化 (触る view)。
- UI test 用に各ページ root に `accessibilityIdentifier("onboarding.page.\(index)")` 付与を検討。

**Alternatives considered**:
- Page 4 のみ書き換え + 他 3 ページはハードコード維持 → 「触る view は key 化」方針で全 4 ページ key 化に統一。

---

## R3: P0-3 SettingsView 旧 placeholder Section 削除

**Decision**: `Views/SettingsView.swift:198-216` の「近日対応」placeholder Section (`settings.icloud.placeholder` id 含む、spec 050 遺物) を削除。

**現状 (verified)**:
- 動作する toggle Section: `:54-101` (spec 051、`settings.icloud.toggle` / `settings.icloud.restartBanner`)。
- 確認 alert: `:311-329` (`showICloudEnableConfirm` / `showICloudDisableConfirm`)。
- 旧 placeholder: `:198-216` (「近日対応 — 複数の端末で同じ知識ベースを共有」「現在は全てこの端末内に保存されます。iCloud 同期は次のバージョンで予定しています。」)。

**Rationale**:
- spec 051 で iCloud sync が実装済 → placeholder は完全に矛盾する遺物。削除のみで解消。
- 動作する toggle / alert / banner は無改修で維持。

**実装メモ**: Section ブロック (`:198-216` 相当、`Section { ... } header/footer` 含む) を丸ごと削除。前後 Section の区切りが壊れないこと、関連する未使用文言が残らないことを確認。

**Alternatives considered**: placeholder を「実装済」案内に書き換え → 動作する toggle と重複するため削除が正。

---

## R4: P0-4 Chat 引用リンク navigation 配線 ★設計の肝

**Decision**: `ChatMessageRow` に `var onArticleLinkTap: ((Article) -> Void)? = nil` callback を追加。OpenURLAction 内で article lookup 成功時に `onArticleLinkTap?(article)` を呼んでから `.handled` を返す。`ChatTabView` が ChatMessageRow に `onArticleLinkTap: { navigationPath.append($0) }` を注入。

**現状 (verified)**:
- `ChatMessageRow.swift:64-71`: OpenURLAction が `extractArticleID` → `allArticles.first(where:)` で lookup 成功するが `_ = article` で discard、`.handled` 返却 → 遷移しない。
- `ChatTabView.swift:32`: `@State private var navigationPath = NavigationPath()` **既存**。
- `ChatTabView.swift:44`: `NavigationStack(path: $navigationPath)` **既存**。
- `ChatTabView.swift` (~:114-116): `.navigationDestination(for: Article.self) { ArticleDetailView(article:, embedNavigationStack: false) }` **既存**。
- `ChatTabView.swift:63`: `ChatMessageRow(message:, streamingTextOverride:)` call site。

**→ navigation 基盤は完全に揃っている。callback を 1 本通すだけで遷移が成立する。**

**Rationale**:
- 既存 `navigationPath.append(article)` が `.navigationDestination(for: Article.self)` を発火 → ArticleDetailView push。新規 navigation 基盤不要。
- callback DI はプロジェクト既存パターン (spec 044 等)。
- streaming 中は `streamingTextOverride` で plain Text にフォールバックする既存挙動 (link 無効) を壊さない。streaming 完了後の AttributedString 表示時のみ callback が効く。

**実装メモ**:
- ChatMessageRow: prop 追加 + OpenURLAction を
  ```swift
  .environment(\.openURL, OpenURLAction { url in
      if let id = Self.extractArticleID(from: url),
         let article = allArticles.first(where: { $0.id == id }) {
          onArticleLinkTap?(article)
          return .handled
      }
      return .systemAction
  })
  ```
- ChatTabView: call site に `onArticleLinkTap: { navigationPath.append($0) }` 追加。
- 該当記事なし → callback 呼ばず `.systemAction` (既存)、クラッシュなし (FR-009)。

**Alternatives considered**:
- `@Binding NavigationPath` を ChatMessageRow に渡す → row が path を直接触るのは責務過多。callback の方が疎結合。
- NotificationCenter / PassthroughSubject (既存 `clarificationTapNotificationPublisher` パターン) → callback の方が型安全でシンプル。clarification は複数 row → 1 受信なので publisher、article tap は親が直接 path 操作で十分。

---

## R5: P0-5 UI test 刷新

**Decision**: 削除済タブを参照する `UnderstandingTabUITests.swift` (`tab.learning`) と `AIBrainTabUITests.swift` (`tab.aibrain`) をファイルごと削除し、pbxproj から参照除去。現行 3 タブを検証する `V3RedesignUITests.swift` を新規追加。

**現状 (verified)**:
- 現行タブ id: `tab.knowledgeClip` (KnowledgeTreeApp:92) / `tab.library` (:99) / `tab.chat` (:106)。
- `UnderstandingTabUITests.swift` (77 行、`tab.learning` 期待)、`AIBrainTabUITests.swift` (`tab.aibrain` 期待) は削除済タブ前提 → 全体が無効。
- `SaveArticleUITests.swift` の pre-existing flaky 1 件は対象外 (維持)。

**新 V3RedesignUITests 5 シナリオ**:
1. Knowledge Clip タブが起動 default で load される (`tab.knowledgeClip` 存在)
2. Add Article sheet が開く (FAB or toolbar の追加導線)
3. Library タブへ切替できる (`tab.library` tap → 一覧 or tag list)
4. Chat タブが開き empty-state を表示 (`tab.chat` tap)
5. Settings が Avatar menu から開く

**Rationale**:
- 削除済タブの test はリネームでなく削除が正 (該当機能が存在しない)。
- 新 suite は現行 3 タブの基本導線を最小限カバーし CI シグナルを回復。
- 既存 accessibilityIdentifier を最大限活用、不足分は実装側に最小限追加。

**実装メモ**:
- pbxproj 編集: `PBXFileReference` / `PBXBuildFile` / UITests target `Sources` から旧 2 ファイル除去、新 1 ファイル追加 (spec 042/043 同手順)。
- launch arguments / setUp は既存 `SaveArticleUITests` の流儀踏襲。
- **制約**: sandbox で UI test 実行不可 → compile 通過まで Claude 担保、実行はユーザー実機。

**Alternatives considered**:
- 旧 test の id だけ書き換えて維持 → test 内容が学習/AIブレイン機能前提なので意味をなさない。削除が正。

---

## R6: テスト戦略

**Decision**:
- 本 spec は UI 文言 + navigation 配線 + UI test refactor が主。新規 **unit** test は最小限。
- P0-4 の `extractArticleID(from:)` は `private static` → 必要なら `static` (internal) 昇格で `@testable import` から `article-id://UUID` パースを 1-2 ケース検証 (任意、UI 寄りなので必須ではない)。
- xcstrings 追加による既存 localization 系 test の regression 確認。
- 最後に全 unit suite serial regression 1 回。

**Rationale**: ロジック追加がほぼ無い (callback 配線 + 文言) ため、過剰な unit test より既存 regression 担保 + UI test compile を重視。

**検証コマンド**:
```bash
xcodebuild clean build -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO
```
