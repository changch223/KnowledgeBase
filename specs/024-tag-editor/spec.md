# Feature Specification: Tag 編集 / 統合 / 削除 UI

**Feature Branch**: `024-tag-editor` (実装時に作成)
**Created**: 2026-05-08
**Status**: Draft (specify+plan)
**Vision**: [VISION.md](../VISION.md) — 「AI 自動 + ユーザー確認」原則の完成形

## なぜ (Why)

spec 012 (AI Auto-Tag) と spec 013 (Auto-Tag backfill) で AI が記事保存時に自動でタグを付けている。しかし以下のケースでユーザーが直したい:

- AI が **意図しないタグ** を付けた (例: 料理記事に「政治」タグ)
- **同義語タグの分散** (例: 「Swift」「swift」「SWIFT」が別タグになる)
- **誤字タグ** (例: 「プログラミング」「プログラミグ」)
- **不要タグ** (例: AI が文脈なしに付けた汎用タグ)
- **より良いタグ名に変更したい** (例: 「コード」→「プログラミング」)

VISION.md「AI 自動 + ユーザー確認」原則の完成形として、ユーザーが AI 出力を **訂正** できる手段を提供する。

## ゴール

- **タグ管理画面** (TagManagementView) で全 Tag 一覧を表示
- Tag タップで **編集 sheet** (rename / merge / delete)
- **rename**: Tag 名変更、既存タグ名と同じなら自動 merge
- **merge**: 別 Tag に統合 (source の articles を target に移動、source を削除)
- **delete**: Tag を完全削除 (articles の relationship 解除)
- AI ブレインタブから「タグ管理」エントリで遷移

## 非ゴール

- **Category 編集** (10 ジャンル固定の改編) → spec 036+ 候補
- **一括 Tag 編集** (multi-select で複数タグを同時操作) → 将来 spec
- **Tag 色設定** → 将来 spec、現状の DesignSystem で十分
- **Tag 並び順カスタマイズ** → 現状 article count desc 固定
- **AI Auto-Tag の prompt 調整** → spec 035+ で扱う
- **Tag に対するメモ / 説明文** → 将来 spec、scope 過大化を避ける

## ユーザストーリー

### US1 (P1) — タグ管理画面で Tag 一覧を見る

1. AI ブレインタブ → 「タグ管理」row tap (or Settings 経由)
2. TagManagementView 表示: 全 Tag を article count 降順で List
3. 各 row: Tag 名 + article count + Category 表示

### US2 (P1) — Tag を rename

1. Tag row tap → TagEditSheet (Form)
2. 「タグ名」field に現在名、編集して保存
3. 同じ名前の既存タグがあれば「**統合**しますか?」確認
4. 別名 → rename 完了、UI 反映

### US3 (P1) — Tag を別 Tag に統合 (merge)

1. TagEditSheet で「**他のタグに統合**」セクション
2. ターゲット Tag を Picker で選択
3. 「統合する」button tap → 確認 alert 「N 件の記事が ◯◯ タグに移動します」
4. 採用 → source タグの全 articles を target へ relationship 移動、source タグ削除

### US4 (P1) — Tag を削除

1. TagEditSheet で「**削除**」button (赤、destructive)
2. 確認 alert 「N 件の記事からタグが外れます」
3. 採用 → 全 articles の Tag relationship 解除 + Tag 削除

### US5 (P2) — タグ管理エントリ

1. AI ブレインタブ右上の歯車 → SettingsView → 「タグ管理」row
2. もしくは AI ブレインタブのジャンル別知識セクション付近に entry

### US6 (P2) — 空 Tag (孤児) の自動 cleanup

1. merge / delete 後、孤児 Tag (記事 0 件) は自動削除
2. 既存 TagStore.cleanupOrphans() を起動時 + 操作時に呼び出し

## 機能要件

### TagStore 拡張

- **FR-001**: `TagStore.rename(_ tag: Tag, to newName: String) throws -> Tag` — 重複なら merge
- **FR-002**: `TagStore.merge(source: Tag, into target: Tag) throws` — source の articles を target に append、source を delete
- **FR-003**: `TagStore.delete(_ tag: Tag) throws` — articles の relationship 解除 + Tag 削除
- **FR-004**: rename で名前正規化 (lowercase + trim、既存ロジック踏襲)
- **FR-005**: merge / delete で article 数 0 の孤児 Tag を cleanup
- **FR-006**: 全操作で context.save() + RefreshTrigger 通知

### UI

- **FR-007**: `TagManagementView` 新規:
  - List(allTags、article count desc)
  - 各 row: Tag.name + article count + Category 表示
  - 検索 (TextField で Tag name フィルタ、optional)
  - tap で TagEditSheet
- **FR-008**: `TagEditSheet` 新規 (sheet):
  - Form 形式
  - section 1: 「タグ名」TextField + 保存ボタン
  - section 2: 「他のタグに統合」Picker + 「統合する」ボタン
  - section 3: 「削除」destructive ボタン (article count caption)
- **FR-009**: 確認 alert は ChatService deleteAllSessions と同パターン

### Entry

- **FR-010**: SettingsView に「タグ管理」row を追加
  - NavigationLink → TagManagementView
- **FR-011**: 後方互換: 既存の AI ブレインタブのカテゴリ別知識から direct 遷移は **しない** (Settings 経由のみ、混乱回避)

## 成功基準

- SC-001: Tag 数 N 件の状態で TagManagementView を開く → N 件表示 (article count desc)
- SC-002: Tag rename → UI 反映、同名既存タグあれば自動 merge
- SC-003: Tag merge → source 削除、target に articles 移動
- SC-004: Tag delete → 全 articles から relationship 解除
- SC-005: 操作後、ライブラリタブ / Tag フィルター画面で UI 反映 (RefreshTrigger 経由)
- SC-006: 既存 TagStore テスト全 PASS (回帰なし)
- SC-007: 操作の cancel で何も変わらない

## アサンプション

- Tag 名は最大 50 字 (TagNormalizer 既存ロジック)
- merge 時の循環 (A → B → A) は UI で防ぐ (Picker で source 自身を除外)
- 1000 Tag 規模でも List Lazy 描画で性能問題なし

## 依存・前提

- spec 008 (Tag @Model + TagStore + TagNormalizer)
- spec 012 (AI Auto-Tag 経路、本 spec で訂正対象)
- spec 015 (Tag.categoryRaw)
- spec 005 (RefreshTrigger)

## 想定実装規模

- 新規 2 ファイル:
  - `Views/TagManagementView.swift` (~120 行)
  - `Views/TagEditSheet.swift` (~150 行)
- 改修 2 ファイル:
  - `Services/TagStore.swift` (~80 行追加 — rename/merge/delete)
  - `Views/SettingsView.swift` (~10 行追加)
- 新規テスト 1 ファイル:
  - `TagStoreEditTests.swift` (~7 ケース、rename/merge/delete + 重複 + 孤児 cleanup)
- xcstrings (~12 文言)
- 合計 ~370 行、~10 タスク

## Constitution

- I (privacy): SwiftData ローカル操作のみ、外部送信ゼロ
- II (MVP): rename/merge/delete のみ、一括 / 色 / 並び替えは将来
- III (source 追跡): articles の relationship は merge で正しく移動、追跡可能
- IV (実現可能性): SwiftUI Form + Picker、SwiftData @Relationship 標準操作
- V (calm UX): 確認 alert あり (削除は破壊的なので Constitution V の例外として許容、Settings 削除と同様)
- VI (architecture): TagStore protocol を維持、UI は Service 経由
- VII (日本語): 全 UI / 確認 alert 日本語

## 状態

📝 specify+plan 完了 (2026-05-08)、`/speckit-tasks` + `/speckit-implement` は本セッションで実施。
