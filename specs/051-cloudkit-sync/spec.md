# Feature Specification: iCloud sync (SwiftData CloudKit private database)

**Feature Branch**: `051-cloudkit-sync`
**Created**: 2026-05-24
**Status**: Draft (v2.0、design 検討中)
**Risk**: 🔴 **HIGH** — schema migration + App Group との共存設計

## なぜ

V1.0 は完全 on-device で完結し、プライバシー / シンプルさで強い。しかし複数端末持ち (iPhone + iPad) のユーザーから「2 台でも同じ知識ベースが見たい」要望は確実に出る。V2.0 で **iCloud opt-in 同期** を導入し、Karpathy「knowledge that compounds」体験を端末を超えて拡張する。

## ゴール

- ユーザーが **Settings → 「iCloud で同期」 toggle ON** で、その後の保存記事 / 概念ページ / SavedAnswer / 学習履歴等を **同一 Apple ID の他端末** と自動同期
- Toggle OFF (default、既存ユーザーはこのまま) は完全 on-device 動作維持
- データの一方向 / 双方向の選択肢は不要 (Apple のベストプラクティス通り双方向 sync 一択)
- AI 抽出済みデータも同期される (essence / embedding / KeyFact 等)
- 既存ローカルデータは toggle ON 時に自動 CloudKit に push (migration)

## 非ゴール

- 共有 (CloudKit shared zone、他ユーザーへ公開) — v3.0+
- バックアップ / リストア (端末初期化からの完全復元) — Apple の iCloud バックアップ任せ
- 端末別の 部分 sync (一部 entity だけ sync) — 全 schema 一括 sync
- conflict resolution UI (CloudKit の last-write-wins に任せ、ユーザー介入不要)

## 🚨 重大な技術的制約と方針

### 制約 1: SwiftData CloudKit の schema 要件
- **全 relationship が optional** (現状 `var citedArticles: [Article] = []` は default 空配列 OK だが、`var session: ChatSession?` のような optional 化が必要なものあり、要 audit)
- **`@Attribute(.unique)` 不可** — `@Attribute(.unique) var id: UUID` を使用している全 @Model でこの constraint を **削除** + application-level dedup ロジック追加
- **全 attribute が default value 必須** (Article.url 等の non-optional に default 追加必要)

### 制約 2: App Group container と CloudKit の共存
- 現状: `ModelConfiguration(schema: ..., groupContainer: .identifier(AppGroup.identifier))`
- CloudKit 追加: `ModelConfiguration(schema: ..., groupContainer: ..., cloudKitDatabase: .private("iCloud.app.iKnow"))`
- **検証必要**: App Group + CloudKit private 同時指定が iOS 26 で正しく動くか (Apple docs は別々の例しかない)
- 代替: App Group は廃止 → Share Extension は XPC or NotificationCenter 経由でデータ受け渡し (大規模 refactor、避けたい)

### 制約 3: 既存ユーザーのデータ migration
- toggle ON 時、ローカルの全 @Model を CloudKit に push
- 50 件 / 200 件 / 1000 件規模での初回 push 時間 (10 秒〜数分) → progress UI
- migration 中はアプリ使用可、background sync

### 方針: 段階的アプローチ
- **Phase A** (本 spec): Schema audit + opt-in toggle + 基本 sync 動作 (実装規模 ~1.5 週)
- **Phase B** (spec 054): 既存データ migration UI + progress 表示 (実装規模 ~0.5 週)
- **Phase C** (spec 055): conflict resolution + offline indicator + sync error UI (実装規模 ~1 週)

本 spec は **Phase A のみ** に focus、B/C は別 spec で別 release もあり得る。

## ユーザストーリー

### US1 (P1) — Settings で iCloud sync を ON にできる

1. ユーザーが Settings を開く
2. 「iCloud で同期」 toggle (現状 placeholder を実 toggle に置き換え)
3. ON にすると確認 alert「現在の知識ベースを iCloud に同期します (初回は数分かかります)」
4. 「OK」で sync 開始、SettingsView 下部に「同期中…」progress 表示

### US2 (P1) — 他端末で同じデータが見える

1. 端末 A (iPhone) で記事を保存 → iCloud に push
2. 端末 B (iPad) でアプリ起動 → CloudKit から pull → ライブラリに同じ記事が表示
3. 概念ページ / SavedAnswer / 学習履歴も同期

### US3 (P1) — Sign-in 不要

1. iCloud at OS level (Settings App → ユーザー名 → iCloud) を ON にしてあれば、アプリ内で sign-in 不要
2. iCloud OFF / 別 Apple ID の場合は Settings で「iCloud にサインインしてください」warning

### US4 (P2) — Toggle OFF で local 専用に戻れる

1. Toggle OFF → 確認 alert「同期を停止しますが、iCloud 上のデータは残ります」
2. OFF 後はローカル動作、新規保存は他端末に同期されない
3. 再 ON で再 sync 開始 (差分 push)

### US5 (P2) — 同期エラーの表示

1. iCloud quota 不足 / network 不通等で sync 失敗
2. Settings の同期 entry に「⚠️ 同期エラー — ストレージ不足」warning 表示
3. tap で iCloud 設定アプリへ deep link

### US6 (P3) — 同期インジケーター

1. 現在 sync 中かどうかが microscopic indicator で見える (現状は Settings 内のみ、将来 toolbar 等)

## 機能要件

- **FR-001**: `ModelConfiguration` に `cloudKitDatabase: .private(.identifier("iCloud.app.KnowledgeTree"))` を toggle ON 時に切替
- **FR-002**: Settings に「iCloud で同期」toggle (`@AppStorage("icloud_sync_enabled")`) を実 toggle 化
- **FR-003**: toggle ON で確認 alert + sync 開始
- **FR-004**: 全 @Model から `@Attribute(.unique)` を削除 (Article.id / Tag.id / ConceptPage.id / SavedAnswer.id / UnderstandingInteraction.id 等 約 15 model)
- **FR-005**: 全 @Relationship の optional 化 audit + 修正 (ChatMessage.session 等)
- **FR-006**: 全 attribute に default value 設定 (Article.url = "" 等、空文字列 default で OK)
- **FR-007**: application-level dedup: `@Model` insert 前に id 一意性チェック (ArticleStore / TagStore / 各 Store に追加)
- **FR-008**: iCloud アカウント未設定 / OFF 時の warning 表示
- **FR-009**: Sync エラーハンドリング (CKError → ユーザー文言変換)
- **FR-010**: Apple Developer Account で CloudKit container 作成 + Capabilities 追加 (`com.apple.developer.icloud-services` + `iCloud.app.KnowledgeTree`)
- **FR-011**: Info.plist / entitlements 更新
- **FR-012**: App Group container + CloudKit private 同時指定の動作検証 (技術 spike が plan で必要)
- **FR-013**: Toggle OFF で sync 停止 (ModelConfiguration を `cloudKitDatabase: nil` で再構築 → アプリ再起動が必要かもしれない、要検証)
- **FR-014**: 同期データの量制限: AppGroup local DB は無制限、CloudKit private は 1 ユーザー 1 GB 上限 — 超過時の挙動定義
- **FR-015**: Calm UX: sync 通知 / バッジ / 効果音ゼロ (Constitution V 維持)

## 成功基準

- SC-001: Settings で toggle ON → 確認 alert 表示
- SC-002: OK で sync 開始、3 秒以内に「同期中…」progress 表示
- SC-003: 初回 push (50 件記事 + 関連データ) が 3 分以内に完了 (LTE 環境想定)
- SC-004: 他端末でアプリ起動 → 1 分以内に同期データが見える (LTE)
- SC-005: 同 ID で複数端末間で記事編集 / 削除 / 学習履歴記録が双方向同期
- SC-006: Toggle OFF → 既存ローカルデータ維持、新規操作は他端末に行かない
- SC-007: iCloud quota 不足で sync 失敗 → Settings に warning 表示
- SC-008: Constitution V 維持 (push 通知 / バッジ / 効果音ゼロ)

## アサンプション + リスク

- ユーザーは iCloud at OS level を ON にしている (アプリ内で sign-in 不要)
- SwiftData CloudKit (iOS 17+) の API が iOS 26 でも安定
- 全 @Model の schema を改修してもデータ loss しない (test 必須)
- `@Attribute(.unique)` 削除でアプリケーション層 dedup が漏れたら同 id duplicate 発生 → audit 必須

**最大リスク**: 実装着手後に「App Group + CloudKit が iOS 26 で正しく動かない」「schema migration で既存ユーザーデータが壊れる」「Share Extension が CloudKit 経由で動かない」等の発覚。Phase A 前半で **technical spike** (1-2 日) して実機検証する手順を plan で組む。

## 規模見込み

- schema audit + 修正: 15+ model × 平均 30 行 = ~450 行
- store layer dedup: 8+ store × 10 行 = ~80 行
- Settings UI 改修: ~100 行
- Migration UI: ~150 行 (Phase B)
- Error handling: ~80 行
- Tests: ~300 行
- 合計 **~1100 行**、tasks 20-30、期間 **2-3 週間** (Phase A のみ)

## 依存

- iOS 26+ (SwiftData CloudKit 安定版)
- Apple Developer Account (CloudKit container 作成権限)
- 既存 SharedSchema 全 entity (Article / Tag / ConceptPage / SavedAnswer / UnderstandingInteraction / 等)
