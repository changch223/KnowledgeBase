# KnowledgeTree Full Code Audit - 2026-05-28

## Scope And Method

This audit covered the app code under:

- `KnowledgeTree`
- `KnowledgeTreeShareExtension`
- `KnowledgeTreeSafariExtension`
- `iKnowWidget`
- `KnowledgeTreeTests`
- `KnowledgeTreeUITests`

Source-like files checked: 269 files (`.swift`, `.js`, `.html`, `.css`, `.json`, `.plist`, `.entitlements`).

Approximate audited source/config size: 37,414 lines.

Audit method:

- Enumerated all source/config files with `rg --files` and `find`.
- Reviewed file sizes and high-complexity files.
- Scanned every target for crash patterns, placeholders, stale product language, force unwraps, `try?`, full-store fetches, `@Query`, background tasks, timers, UserDefaults keys, hard-coded UI strings, accessibility identifiers, and extension/native-message wiring.
- Read the app entry point, schema/models, major services, major SwiftUI flows, Safari/Share extensions, Widget, build settings, entitlements, localization file, and UI tests in detail.
- Ran `xcodebuild -list -project KnowledgeTree.xcodeproj`; project listing succeeded but emitted sandbox/CoreSimulator/DerivedData permission warnings, so full build/test execution was not performed in this audit.

## Executive Summary

The codebase is unusually feature-rich for its size: SwiftData persistence, Share Extension, Safari Web Extension, Widget, background extraction, local AI/RAG, concept synthesis, graph extraction, linting, CloudKit opt-in, and broad unit-test coverage are all present.

The biggest risks are not "missing features"; they are drift and integration gaps after several redesign phases:

- Current product navigation is 3-tab V3, but tests/copy/legacy components still refer to removed Learning/AIBrain tabs.
- Safari Extension wiring contains placeholder/native-message remnants and a Hello World popup.
- Settings exposes iCloud sync twice with contradictory messaging.
- Chat answers ask the model to emit inline article links, but the UI consumes the link without navigating.
- URL normalization exists but is not used for primary deduplication.
- Many operations intentionally fail silently, which keeps the UI calm but makes production diagnosis hard.

## P0 Findings

### P0-1: Safari native messaging uses placeholder application id

Evidence:

- `KnowledgeTreeSafariExtension/Resources/background.js:21`
- `KnowledgeTreeSafariExtension/Resources/background.js:45`
- `KnowledgeTreeSafariExtension/Resources/background.js:57`

The extension calls `browser.runtime.sendNativeMessage("application.id", ...)`. If this is not rewritten by Safari/Xcode packaging, manual save and auto-save can fail at the most important ingestion path.

Recommendation:

- Replace the placeholder with the actual native messaging app identifier expected by Safari.
- Add a user-visible failure path or badge state for toolbar save failures.
- Add a UI/integration test checklist for manual save and auto-save.

### P0-2: Chat inline citation links are handled but do not navigate

Evidence:

- `KnowledgeTree/Services/ChatService.swift:517`
- `KnowledgeTree/Views/ChatMessageRow.swift:64`

The model is instructed to emit `[title](article-id://UUID)` links, and `ChatMessageRow` parses them. However, the `OpenURLAction` only checks that the article exists and returns `.handled`; it never opens `ArticleDetailView`.

Recommendation:

- Move article lookup/navigation state to `ChatTabView`.
- Pass an `onArticleLinkTap(UUID)` callback into `ChatMessageRow`.
- Push `ArticleDetailView(article:embedNavigationStack:false)` via `NavigationPath` or set a sheet item.

### P0-3: Settings shows two iCloud sync sections with contradictory states

Evidence:

- Active opt-in sync UI: `KnowledgeTree/Views/SettingsView.swift:54`
- Old placeholder: `KnowledgeTree/Views/SettingsView.swift:198`

The user sees "iCloud sync" as a working toggle and later "coming soon". This undermines trust and can lead to wrong support reports.

Recommendation:

- Delete the old placeholder section.
- Keep one CloudKit section with status, restart-required message, and data behavior.

### P0-4: UI tests target removed tabs and stale identifiers

Evidence:

- `KnowledgeTreeUITests/UnderstandingTabUITests.swift:25` expects `tab.learning`.
- `KnowledgeTreeUITests/AIBrainTabUITests.swift:43` expects `tab.aibrain`.
- Current tabs are `tab.knowledgeClip`, `tab.library`, and `tab.chat` in `KnowledgeTree/KnowledgeTreeApp.swift:91`, `:98`, `:105`.

These UI tests no longer validate the shipped product. They will either fail or be skipped around old assumptions.

Recommendation:

- Replace Learning/AIBrain UI tests with V3 tests:
  - Knowledge Clip loads.
  - Add Article sheet opens.
  - Library tab navigates to tag list.
  - Chat tab opens sidebar and sends disabled/empty-state behavior.
  - Settings opens from Avatar menu.

### P0-5: Onboarding still teaches a removed "Learning tab"

Evidence:

- `KnowledgeTree/Views/OnboardingView.swift:45`

The app removed the Learning tab but onboarding says "学習タブ". This is a high-friction first-run issue.

Recommendation:

- Rewrite page 4 around current behavior: "知識Clipの『続きが気になる』から家庭教師チャットを開く".
- Add a UI test that onboarding copy does not contain old tab names.

## P1 Findings

### P1-1: URL normalization exists but is not used for deduplication

Evidence:

- URL normalizer: `KnowledgeTree/Services/URLNormalization.swift:21`
- Main save uses raw `absoluteString`: `KnowledgeTree/Services/ArticleSavingService.swift:49`
- App Intent uses raw trimmed string: `KnowledgeTree/AppIntents/ArticleSavingActor.swift:51`

Tracking params, fragments, trailing slashes, and `www.` variants can create duplicate Articles.

Recommendation:

- Add `normalizedURL` to `Article` or normalize before `exists(url:)`.
- Preserve original URL separately if needed for display/opening.
- Backfill existing duplicates with a lint step.

### P1-2: Production persistence failures are too often silent

Evidence examples:

- `KnowledgeTree/Views/ArticleListView.swift:212`
- `KnowledgeTree/Views/ChatHistorySidebar.swift:99`
- `KnowledgeTree/Services/ArticleEnrichmentService.swift:106`
- `KnowledgeTree/Services/KnowledgeExtractionService.swift:224`
- `KnowledgeTreeSafariExtension/SafariWebExtensionHandler.swift:56`

The calm UX principle is good, but the current implementation often loses diagnostics.

Recommendation:

- Add a lightweight `AppErrorReporter` using `Logger`.
- Use it wherever UI intentionally suppresses the error.
- For user-initiated destructive actions, show a quiet inline failure state or alert.

### P1-3: `KnowledgeTreeApp.bootstrap()` owns too much startup orchestration

Evidence:

- `KnowledgeTree/KnowledgeTreeApp.swift:153`
- Long startup job sequence: `KnowledgeTree/KnowledgeTreeApp.swift:388`

Service graph construction, background scheduler binding, migrations/backfills, and recurring jobs are all in the App type.

Recommendation:

- Extract `ServiceGraphBuilder`.
- Extract `StartupJobRunner`.
- Run non-essential jobs after first paint with progress/logging.
- Make startup jobs idempotent and independently testable.

### P1-4: ModelContainer failure crashes the app

Evidence:

- `KnowledgeTree/KnowledgeTreeApp.swift:76`
- `KnowledgeTree/KnowledgeTreeApp.swift:79`

If local store creation fails, the app hard-crashes. For a data-centric app, a recovery screen is better.

Recommendation:

- Replace release `fatalError` with a `StoreRecoveryView`.
- Offer retry, local-only fallback, and support log export.
- Keep `assertionFailure` in debug if desired.

### P1-5: RAG trust boundary is inconsistent

Evidence:

- RAG prompt forbids general knowledge: `KnowledgeTree/Services/ChatService.swift:514`
- Zero-result fallback requests general knowledge: `KnowledgeTree/Services/ChatService.swift:282`

The app mixes "answer from saved articles" and "general assistant" behavior without explicit UI mode. Users may over-trust unsupported answers.

Recommendation:

- Add a visible answer mode:
  - "保存記事から回答"
  - "一般知識も使う"
- Label uncited answers clearly.
- Keep cited answers and general answers visually distinct.

### P1-6: Row-level `@Query` in chat can scale poorly

Evidence:

- `KnowledgeTree/Views/ChatMessageRow.swift:23`
- `KnowledgeTree/Views/ChatMessageRow.swift:191`
- `KnowledgeTree/Views/ChatMessageRow.swift:241`

Every message row can attach queries for all articles/concept pages.

Recommendation:

- Fetch article/concept dictionaries once in `ChatTabView`.
- Pass lightweight data or lookup closures to rows.
- Keep row views render-only where possible.

### P1-7: Article detail uses 1-second polling

Evidence:

- `KnowledgeTree/Views/ArticleDetailView.swift:42`

The polling exists as a SwiftData observation fallback, but it can cause unnecessary rebuilds and battery/workload cost.

Recommendation:

- Replace with explicit progress/status publisher from stores/services.
- Keep a low-frequency fallback only for active processing states.

### P1-8: Safari auto-save preferences are split between standard and App Group defaults

Evidence:

- App UI storage: `KnowledgeTree/Views/SafariSetupView.swift:16`
- Manual sync to App Group: `KnowledgeTree/Views/SafariSetupView.swift:214`
- Extension reads App Group: `KnowledgeTreeSafariExtension/SafariWebExtensionHandler.swift:67`

The view does sync changes, but the state has two sources of truth. Initial values or future settings UI can drift.

Recommendation:

- Introduce `SafariExtensionSettingsStore`.
- Read/write only the App Group suite for extension-visible settings.
- Keep `@AppStorage` only for purely in-app UI state.

### P1-9: Localization file contains many extracted-but-empty localizations

Evidence:

- `KnowledgeTree/Localization/Localizable.xcstrings`
- Audit query found 127 keys with empty localization dictionaries.

Recommendation:

- Decide whether these are extraction placeholders or intended keys.
- Add CI check for empty localization entries before release.
- Move hard-coded Japanese strings from Graph/Settings/Widget/Onboarding/DeepDiveChat into `.xcstrings`.

### P1-10: Legacy/deprecated views and services remain in active target

Evidence:

- `KnowledgeTree/Views/PowerGaugeCard.swift`
- `KnowledgeTree/Views/KnowledgeMapView.swift`
- `KnowledgeTree/Views/RecentActivityCards.swift`
- `KnowledgeTree/Views/ReaderView.swift`
- `KnowledgeTree/Services/DeepDiveChatStarter.swift`
- `KnowledgeTree/DesignSystem.swift:64`

Some are explicitly marked deprecated/legacy. They may still compile through file-system-synchronized target membership, adding maintenance drag.

Recommendation:

- Move legacy code behind a `Legacy/` folder with clear ownership or remove it.
- Delete old localization keys and UI tests at the same time.

## P2 Findings

### P2-1: Safari extension logs page URLs to console

Evidence:

- `KnowledgeTreeSafariExtension/Resources/content.js:21`
- `KnowledgeTreeSafariExtension/Resources/content.js:75`
- `KnowledgeTreeSafariExtension/Resources/content.js:101`

Useful during development, but noisy and privacy-sensitive in release.

Recommendation:

- Add a debug flag.
- Suppress URL logging in production builds.

### P2-2: Safari popup still says Hello World

Evidence:

- `KnowledgeTreeSafariExtension/Resources/popup.html:9`
- `KnowledgeTreeSafariExtension/Resources/popup.js:1`

Even if toolbar click is the intended UX, this is a polish/release readiness issue.

Recommendation:

- Remove the popup files if unused.
- Or build a minimal status popup: "Saved", "Auto-save on/off", "Open settings".

### P2-3: Widget opens CloudKit-disabled read-only container

Evidence:

- `iKnowWidget/WidgetCardSnapshot.swift:57`

This may be intentional for App Group/local reads, but with iCloud sync enabled it can lag or miss CloudKit-only data until the main app has materialized it locally.

Recommendation:

- Document the behavior.
- Add a fallback placeholder explaining "open app to refresh" when no cards are available but sync is enabled.

### P2-4: Add Article sheet lacks completion affordances

Evidence:

- `KnowledgeTree/Views/AddArticleSheet.swift:46`

Save starts a task and dismisses on success, but the user gets little feedback. Duplicate only shows an alert.

Recommendation:

- Show `ProgressView` while saving.
- On duplicate, offer "既存記事を開く".
- On success, show a toast or navigate to the article.

### P2-5: UI strings mix localized keys and hard-coded copy

Evidence examples:

- `KnowledgeTree/Views/GraphNodeEditSheet.swift:49`
- `KnowledgeTree/Views/GraphEdgeEditSheet.swift:38`
- `KnowledgeTree/Views/SettingsView.swift:62`
- `iKnowWidget/LearningCardsWidgetView.swift:42`
- `KnowledgeTree/Views/DeepDiveChatView.swift:65`

Recommendation:

- Finish localization for all user-facing strings.
- Add a lint rule that flags Japanese text in `Text`, `Button`, `Label`, `.alert`, `.navigationTitle`, and Widget config.

### P2-6: Test suite is broad but product-flow coverage is stale

Evidence:

- Unit/UI test declarations: 487 test declarations.
- UI tests still target removed tabs.
- `KnowledgeTreeUITests/KnowledgeTreeUITests.swift:20` is the default template smoke test.
- `KnowledgeTreeUITests/SaveArticleUITests.swift:10` says important share flows are still manual.

Recommendation:

- Add seeded UI fixtures via launch arguments.
- Cover Add Article, Knowledge Clip, Chat citation navigation, Settings sync section, Safari setup, and deep links.
- Keep old unit tests, but align UI tests to current V3 product.

### P2-7: Full-store fetches are common in services

Evidence examples:

- `KnowledgeTree/Services/ChatService.swift:449`
- `KnowledgeTree/Services/ConceptSynthesisService.swift:476`
- `KnowledgeTree/Services/TopicClusteringService.swift:73`
- `KnowledgeTree/Services/SavedAnswerService.swift:173`
- `KnowledgeTree/Services/LintEngine.swift:115`

Recommendation:

- Add fetch limits where possible.
- Cache or index concept/page/article relationships.
- Move expensive maintenance jobs to scheduled background work with progress and cancellation.

## UI/UX Improvement Roadmap

### 1. First-run flow

Problems:

- Onboarding references old navigation.
- Empty library tells the user what to do but does not offer an in-app action.

Recommendations:

- Update onboarding to V3.
- Add CTA buttons to empty state:
  - "URLを追加"
  - "Safari連携を設定"
  - "サンプルで試す" (optional demo mode)
- After first save, show processing timeline instead of leaving the user to guess.

### 2. Ingestion UX

Problems:

- Share/Safari/URL paths are separate mental models.
- Safari failures are silent.
- Duplicates do not lead to the existing article.

Recommendations:

- Create one "Save status" model:
  - saved
  - duplicate
  - invalid URL
  - extension unavailable
  - processing queued
- Reuse this model in Add Article, Share Extension, Safari Extension, and App Intent.

### 3. Library UX

Recommendations:

- Add filter chips: all, processing, failed, obsolete, untagged, PDF, recently added.
- Add undo for delete.
- Add "retry failed processing" batch action.
- Add sort modes: saved date, last processed, title, category.

### 4. Article detail UX

Recommendations:

- Replace hidden polling with visible progress:
  - saved
  - fetching
  - extracting body
  - generating knowledge
  - indexing graph/concepts
- Make failure recovery obvious with "retry" and reason.
- Move generated knowledge provenance closer to citations/source article metadata.

### 5. Chat UX

Recommendations:

- Fix citation link navigation first.
- Add a citation drawer showing source snippets.
- Add answer mode selector: saved articles vs general knowledge.
- Add stop/regenerate controls.
- Add "save answer" feedback and pin state.

### 6. Knowledge Clip UX

Recommendations:

- Make "why this card" visible for Interesting Next items.
- Distinguish stale/following/review states with consistent badges.
- Add a single "Today" surface with clear sections:
  - New knowledge
  - Needs refresh
  - Keep following
  - Continue learning

### 7. Graph UX

Recommendations:

- Add legend for node size/color/edge confidence.
- Add filters for category, confidence, relation label, stale/uncertain.
- Add review queue for uncertain AI edges.
- Add a "why connected" explanation based on shared articles/key facts.

### 8. Settings UX

Recommendations:

- Group sections as:
  - Health
  - Sync
  - Extensions
  - Data management
  - Display
  - Help/about
- Keep dangerous actions at the bottom.
- Remove duplicate iCloud placeholder.
- Show sync status, not only a toggle.

### 9. Widget UX

Recommendations:

- Localize Widget copy.
- Add empty state that tells user to open the app if sync/local data is unavailable.
- Consider a medium widget with one primary card plus one "needs update" badge.

## Suggested Implementation Order

1. Replace Safari native message placeholder and remove Hello World popup.
2. Fix Chat citation navigation.
3. Remove duplicate iCloud placeholder and update onboarding copy.
4. Apply URL normalization to save/dedup paths.
5. Replace stale UI tests for Learning/AIBrain with V3 UI tests.
6. Add logging/error reporter for silent failures.
7. Split bootstrap into service graph and startup jobs.
8. Refactor row-level `@Query` in chat and reduce polling in article detail.
9. Complete localization/hard-coded string cleanup.
10. Add richer first-run, empty-state, and Add Article feedback.

## Verification Notes

Commands run:

- `rg --files ...`
- `find ... wc -l`
- `rg` high-risk scans across all source/config targets
- `jq` validation/counting for `Localizable.xcstrings`
- `plutil -p` / `plutil -lint` for plists and entitlements
- `xcodebuild -list -project KnowledgeTree.xcodeproj`

Known limitation:

- Full `xcodebuild test` was not run in this audit. `xcodebuild -list` succeeded, but the local environment emitted CoreSimulator and DerivedData permission warnings, so test execution should be run in Xcode or with a writable DerivedData path in a follow-up pass.
