# Quickstart: Sprint 2 信頼性改善 4 件 検証

## ビルド & unit test (このセッション担保)

```bash
cd /Users/changchiawei/Desktop/KnowledgeTree
xcodebuild clean build -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO
```

## 静的検証

```bash
# P1-3: 対象 7 箇所の try? が do/catch + AppErrorReporter に置換
rg "AppErrorReporter|reporter.report" KnowledgeTree/Views/ KnowledgeTree/Services/AppErrorReporter.swift
# P1-6: fatalError が in-memory fallback に (最終段以外)
rg "isStoredInMemoryOnly|spec061_storeLoadFailed" KnowledgeTree/KnowledgeTreeApp.swift
# P1-7: async let で並列化
rg "async let" KnowledgeTree/KnowledgeTreeApp.swift
# P1-2: pending state
rg "pendingICloudToggle" KnowledgeTree/Views/SettingsView.swift
```

## 実機検証シナリオ (ユーザー後追い)

| SC | シナリオ | 期待 |
|---|---|---|
| SC-001 | Settings で iCloud トグル tap | スイッチが弾き返らない / cancel で元位置 / OK で反転 + 再起動 banner |
| SC-002 | (CloudKit 競合等で) チャット削除が失敗 | Xcode ログに `user action failed [...]` 記録 + 削除系は error 表示 |
| SC-003 | (再現困難) store 構築失敗 | crash せず起動 + 「データ読み込みに問題」banner |
| SC-004 | 多数記事で cold start | 整理処理が同時進行、起動完了 (Instruments で TTI 改善確認) |

## 既存回帰チェック

- iCloud toggle: 確認 alert / restartBanner / 健全性スコア
- 削除/タグ/ピン/フォロー: 成功時は従来通り反映
- 起動: 全 backfill 完了 + BGTask 予約
