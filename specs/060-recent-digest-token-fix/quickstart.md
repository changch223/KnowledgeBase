# Quickstart: RecentDigest token 超過修正 + SchemaLoader bundle 同梱 検証

## ビルド & unit test (このセッション担保)

```bash
cd /Users/changchiawei/Desktop/KnowledgeTree
# SC-004: clean build, warning ゼロ
xcodebuild clean build -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 17'
# SC-003 (bundle 同梱): app に iknow-schema.md が入ったか
find ~/Library/Developer/Xcode/DerivedData/KnowledgeTree-*/Build/Products/Debug-iphonesimulator/KnowledgeTree.app -name "iknow-schema.md"
# SC-005: 全 unit test regression
xcodebuild test -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO
```

## 静的検証

```bash
# Resources に schema.md が置かれた
ls -la KnowledgeTree/Resources/iknow-schema.md
# RecentDigestService に上限定数が入った
rg "promptArticleLimit|promptCharBudget" KnowledgeTree/Services/RecentDigestService.swift
```

## 実機検証シナリオ (ユーザー後追い)

| SC | シナリオ | 期待 |
|---|---|---|
| SC-002 | 30+ 件記事保存 → 知識 Clip タブを開く | 「最近の記事」に AI 生成ヘッドライン + テーマ chips 表示 |
| SC-002b | 上記時の Xcode ログ | `recent digest LM failed: exceededContextWindowSize` が**出ない** |
| SC-003 | アプリ起動時の Xcode ログ | `SchemaLoader: loaded iknow-schema.md from bundle (N chars)` が出る、`not in bundle` が**出ない** |

## 既存回帰チェック

- RecentDigest: 4 tier fallback (cache / single article / empty) / AI 不可 fallback / 30 件 truncate (articleCount=30)
- SchemaLoader: section(named:) / fallback 経路
