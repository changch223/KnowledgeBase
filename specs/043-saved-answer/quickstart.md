# Quickstart: SavedAnswer 実機検証シナリオ

**Feature**: spec 043 SavedAnswer
**Phase**: 1 (Design & Contracts)
**Date**: 2026-05-23
**Audience**: ユーザー (実機検証担当)

spec.md SC-001〜SC-008 を実機検証手順に展開。Apple Intelligence 有効の iPhone (iOS 26+) で実施。所要時間 20-30 分。

事前準備:
- Xcode で `KnowledgeTree` scheme を実機 build & install
- App 起動 1 回 (bootstrap で SavedAnswerService 構築)
- Apple Intelligence on
- spec 042 ConceptPage が動作中 (2+ entity 含む記事を 5+ 件保存済 — 関連 ConceptPage が複数生成されている状態が望ましい)
- spec 021 AI Chat タブが利用可能

---

## SC-001: 答え自動保存 (P1, US1)

**目的**: AI Chat 答えに引用 2+ 件 + 50 字+ あれば SavedAnswer が 5 秒以内に自動保存されることを確認。

**手順**:
1. AI チャットタブで「Apple Vision Pro の特徴は?」(or 既存記事と関連する質問) を送信
2. 答えが返ってきたら、Xcode ログで以下を確認:
   - `captured: question=Apple Vision Pro の特徴は?... cited=N concepts=M` ログ出現 (5 秒以内)
3. アプリ → ConceptPage 詳細画面 (例: "Apple Vision Pro") を開き、「この概念についての質問と答え」セクションに当該質問が表示されることを確認

**期待結果**:
- 答え表示から SavedAnswer 永続化までユーザー通知一切なし (calm UX)
- 5 秒以内に DB 反映
- ConceptPage 詳細画面の「質問と答え」セクションに表示

**Pass criteria**: SC-001 (auto-save 5 秒以内 + UI 通知ゼロ)

---

## SC-002: 重複防止 (P1, US1)

**目的**: 同 question を 2 回送信しても SavedAnswer が 1 件しか作られないことを確認。

**手順**:
1. AI チャットタブで「Apple Vision Pro の特徴は?」を送信 → 答え受信 (SC-001 で確認済前提)
2. **同 question を再度送信** (大文字小文字 + 空白 完全一致)
3. ConceptPage 詳細画面に戻り、「質問と答え」セクションを確認

**期待結果**:
- 同 question の SavedAnswer は **1 件のみ** 表示 (2 件目作成されない)
- Xcode ログに `duplicate question skipped: ...` のような注記が出る (Service 実装で logger 出力)

**Pass criteria**: SC-002 (重複率 0%)

---

## SC-003: ConceptPage 詳細にセクション表示 (P1, US2)

**目的**: ConceptPage 詳細画面で関連 SavedAnswer が 1+ 件あればセクション表示、0 件なら非表示を確認。

**手順**:
1. SavedAnswer がまだ 1 件もない ConceptPage (例: 1 度も AI Chat で質問してない概念) の詳細画面を開く
2. 「質問と答え」セクションが **非表示** であることを確認
3. SavedAnswer が紐付いている ConceptPage の詳細画面を開く
4. 「この概念についての質問と答え (N)」セクションが表示され、関連 SavedAnswer row 一覧が新しい順 (ピン優先) で表示されることを確認

**期待結果**:
- 0 件で section 非表示 (空状態あえて出さない、calm UX)
- 1+ 件で section + row 表示、isPinned が上位

**Pass criteria**: SC-003 (1 秒以内表示 + 0 件で非表示)

---

## SC-004: SavedAnswer 詳細画面 + Article jump (P1, US3)

**目的**: SavedAnswer 詳細画面で 5 セクション表示 + 引用記事タップで Article Detail 1 秒以内遷移を確認。

**手順**:
1. ConceptPage 詳細 → 「質問と答え」 row タップ
2. **SavedAnswer 詳細画面** が表示:
   - header (保存日時 + 自動保存 + pin badge if any)
   - 質問
   - 答え
   - 引用された記事 (N)
   - 関連する概念ページ (N、relatedConceptIDs があれば)
3. 引用記事 row をタップ → ArticleDetailView が 1 秒以内に表示されることを計測

**期待結果**:
- 5 セクション全て表示 (relatedConceptIDs 空のみ section 非表示)
- 引用記事 jump 1 秒以内
- 関連概念ページ chip タップで他 ConceptPage 詳細遷移

**Pass criteria**: SC-004 (Article jump 1 秒以内)

---

## SC-005: 100+ 件履歴 60fps scroll (P1/P2, US4)

**目的**: SavedAnswer 100+ 件状態でも履歴画面 scroll が 60fps を維持。

**手順** (本格的な負荷試験は時間制約で省略可、目視確認で OK):
1. SavedAnswer を 20-50 件作成済の状態で、Settings → 「保存された答えの履歴」を開く
2. リスト全体を勢いよく scroll してカクつきがないか確認
3. (任意) Instruments の SwiftUI template で FPS 計測

**期待結果**:
- LazyVStack で smooth scroll、frame drop なし

**Pass criteria**: SC-005 (60fps 維持)

---

## SC-006: ピン / 削除 1 秒以内反映 (P2, US5)

**目的**: SavedAnswer ピン / 削除 が 1 秒以内に DB + UI 反映。

**手順**:
1. 任意 SavedAnswer 詳細画面 → toolbar 📌 タップ → 状態変化を確認
2. 履歴画面に戻る (背景にあれば自動更新) → ピン済が上位にきていることを確認
3. 再度 detail 画面で 📌 off → 履歴で順序戻ることを確認
4. detail 画面で 🗑️ → 確認 alert で「削除」 → SavedAnswer 削除、自動で履歴画面に戻る (live check で auto pop)
5. **ライブラリタブで引用元 Article が残っている** ことを確認 (raw データ保護)

**期待結果**:
- ピン / 削除 1 秒以内に UI 反映
- 削除後 navigation pop 自動 (crash なし)
- Article は残る

**Pass criteria**: SC-006 (FR-014/015/016/018)

---

## SC-007: 新記事 ingest で isStale 連鎖 (P2, US6)

**目的**: 新記事 ingest → 関連 ConceptPage → SavedAnswer.isStale=true の連鎖を確認 (本 spec では DB のみ、UI 影響なし)。

**手順**:
1. 既存 SavedAnswer (relatedConceptIDs に "Apple Vision Pro" を含む) を 1 件確認
2. 「Apple Vision Pro」関連の新記事を Share Sheet で保存
3. 5 分以内に Xcode ログで以下を確認:
   - `markStale: 1 answers affected by article ...`
4. (debug でしか確認できないが) Xcode debug console から該当 SavedAnswer の isStale プロパティを peek、true になっていること

**期待結果**:
- 5 分以内に DB 反映
- UI には何も変化なし (Constitution V calm UX、WikiLint で別 spec)

**Pass criteria**: SC-007 (5 分以内 + UI 影響なし)

---

## SC-008: 検索 (P3, US7)

**目的**: SavedAnswer 検索が question / answer / 引用記事 title の substring match で動作。

**手順**:
1. Settings → 履歴 → 検索バーに「Vision」と入力
2. question / answer / 引用記事 title に「Vision」を含む SavedAnswer のみ表示されることを確認 (1 秒以内)
3. 検索バーをクリア → 全件表示に戻る

**期待結果**:
- query 一致 SavedAnswer のみ表示 (score 順、savedAt desc tiebreak)
- ヒット 0 件なら「検索結果が見つかりません」 ContentUnavailableView

**Pass criteria**: SC-008 (1 秒以内、100+ 件中の query 一致)

---

## 既存回帰 (合計 5-10 分)

新 spec 043 で既存機能が壊れていないことを確認:

- [ ] **AI Chat (spec 021)**: ChatTabView で従来通り質問応答動作、SavedAnswer hook が hung しても会話継続
- [ ] **ConceptPage (spec 042)**: 概念ページの自動生成 / 詳細 / 編集 (rename/merge/delete) が引き続き動作、特に **merge 後に SavedAnswer.relatedConceptIDs の source→target 置換**が正しく走ること (R6 検証、DB peek)
- [ ] **記事保存 (spec 001)**: Share Sheet 経由保存正常 (spec 043 hook 追加で latency 増えてないこと)
- [ ] **知識ダイジェスト (spec 018)**: 知識 Clip タブ正常
- [ ] **検索 (spec 044)**: 既存 Article 検索動作

各 1-2 分で動作確認、合計 10-15 分。

---

## 自動テスト確認 (Claude 側で実施済み、ユーザー実機検証前に PASS 必須)

```bash
xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:KnowledgeTreeTests/SavedAnswerServiceTests \
    -only-testing:KnowledgeTreeTests/ChatServiceTests \
    -only-testing:KnowledgeTreeTests/ConceptPageStoreTests
```

期待: SavedAnswerServiceTests 8-10/10 PASS + ChatServiceTests 既存 + 新規 hook 検証 PASS + ConceptPageStoreTests 既存 + 新規 merge 連動検証 PASS。fail があれば実機検証前に修正必須。
