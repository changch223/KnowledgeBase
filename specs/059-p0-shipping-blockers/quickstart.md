# Quickstart: Sprint 1 P0 出荷ブロッカー修正 検証

spec SC-001〜SC-007 の検証手順。実機シナリオ + build/test コマンド。

## ビルド & unit test (このセッション担保)

```bash
cd /Users/changchiawei/Desktop/KnowledgeTree
# SC-006: clean build, 本 spec 由来 warning ゼロ
xcodebuild clean build -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 17'
# SC-007: 全 unit test regression
xcodebuild test -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO
```

## 静的検証 (grep で確認可能)

```bash
# SC-001: 「アプリ名」placeholder が EmptyStateView から消えた
rg "アプリ名" KnowledgeTree/Views/EmptyStateView.swift   # → 0 hit
# SC-002: onboarding に廃止タブ名が無い
rg "学習タブ|AIブレイン" KnowledgeTree/Views/OnboardingView.swift   # → 0 hit
# SC-003: 旧 iCloud placeholder が消えた
rg "settings.icloud.placeholder|近日対応" KnowledgeTree/Views/SettingsView.swift   # → 0 hit
# SC-005: UI test に廃止タブ参照が無い
rg "tab.learning|tab.aibrain" KnowledgeTreeUITests/   # → 0 hit
```

## 実機検証シナリオ (ユーザー後追い)

| SC | シナリオ | 期待 |
|---|---|---|
| SC-001 | 新規インストール → ライブラリ空状態 | 「Safari で記事を開いて「共有」→ **iKnow** で保存できます」、「アプリ名」無し |
| SC-002 | 新規インストール → onboarding 4 ページ通読 | 「学習タブ」「AIブレイン」無し、Page 4 が知識 Clip → 続きが気になる → 家庭教師を案内 |
| SC-003 | Settings 開く | iCloud Section 1 つ (動作 toggle)、「近日対応」placeholder 無し |
| SC-003b | iCloud toggle 切替 | 確認 alert → 再起動 banner (既存挙動維持) |
| SC-004 | AI チャットで引用付き回答 → 引用リンク tap | 該当記事の ArticleDetailView へ遷移 |
| SC-004b | 引用先記事を削除後 → 同リンク tap | 遷移せず、クラッシュなし |
| SC-005 | UI test (V3RedesignUITests) 実機実行 | 3 タブ基本導線 5 シナリオ PASS |

## UI test (compile のみ、実行はユーザー)

```bash
# compile 確認 (build に含まれる)。実行は sandbox 制約で本セッション不可
xcodebuild build-for-testing -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## 既存回帰チェック

- Chat: streaming 表示 / CitedArticlesSection / RelatedConceptsChips / ClarificationChipsView が無改修で動作
- Onboarding: スキップ / 次へ / はじめる、完了 flag 永続化
- Settings: iCloud toggle / 確認 alert / restartBanner / 健全性スコア / 整理ログ
- ライブラリ: 空状態 entrance animation / bob
