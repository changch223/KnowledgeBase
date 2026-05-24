# Quickstart: Agentic Chat 実機検証

**Branch**: `056-uiux-redesign-v3` | **Date**: 2026-05-24

spec.md SC-001〜SC-012 を実機検証手順化した 12 シナリオ。

## 事前準備

- iPhone 17 Simulator または実機 (iOS 26+、Apple Intelligence 利用可能)
- 既存データ: Article 5+ 件、ConceptPage 3+ 件 (うち 1+ 件は「Tim Cook」等の人物 entity を含む)
- spec 056 (V3.0 redesign) は既に適用済 (同 branch)

---

## SC-001: 明確な質問で即答 (clarification なし)

**手順**:
1. AI チャットタブを開く
2. 「Tim Cook って誰?」と入力 → 送信

**期待結果**:
- 3 秒以内に answer 表示
- clarification chip なし
- 引用 chip なし (Foundation Models 一般知識答え)
- 答えに「Apple の CEO」等の正確な情報

---

## SC-002: 曖昧な質問で clarification + chips

**手順**:
1. 「Apple について」と入力 → 送信

**期待結果**:
- 1-3 秒以内に聞き返し質問 + 3 つの chip 表示
- chip 例: 「Tim Cook の経歴」「Vision Pro」「株価」 (LLM 生成、内容は変動)
- 各 chip は 30 字以内、tap 可能

---

## SC-003: chip tap で auto-fill + 即答

**手順**:
1. SC-002 後、chip 1 つ tap
2. 入力欄に auto-fill 確認 → 自動送信されることを確認

**期待結果**:
- 入力欄に chip text auto-fill
- 自動的に送信される (user 操作なし)
- 3 秒以内に answer 表示

---

## SC-004: 記事関連質問で embedding 検索 + 引用 chip

**手順**:
1. 事前準備: 「Tim Cook」を含む記事を 1+ 件保存済
2. 「保存記事に Tim Cook の話あった?」と入力 → 送信

**期待結果**:
- 5-8 秒以内に answer 表示
- 引用 chip + ConceptPage chip (spec 047) 表示
- answer に該当記事のタイトル / essence が反映

---

## SC-005: max 3 round clarification 後の最善努力答え

**手順**:
1. 「これどう思う?」と入力 → 送信 (極めて曖昧)
2. clarification 表示 → 同じく「うーん」と返す
3. もう一度 clarification → 「分からない」と返す
4. 3 round 完了

**期待結果**:
- 3 round 目で必ず answer 生成
- 答えに「私の理解では…」「一般的には…」等の hedge phrase 含まれる
- 「分かりません」「答えられません」が答え本文に含まれない (post-process filter)

---

## SC-006: 「分かりません」が出力に含まれない

**手順**:
1. 答えにくい質問を 10 種類試す (「火星の人口は?」「宇宙の年齢の正確な値は?」等)
2. 各答え text に banned keyword が含まれるかチェック

**期待結果**:
- 全 10 答えで「分かりません」「答えられません」「情報がありません」未含
- 代わりに hedge phrase が登場

---

## SC-007: session 内で mode 切替

**手順**:
1. 同 session 内で:
   - Turn 1: 「Apple について」(一般会話 → clarification or immediate)
   - Turn 2: 「保存記事から Tim Cook の情報」(RAG → 引用 chip)
   - Turn 3: 「もっと一般的に教えて」(一般会話 → immediate)

**期待結果**:
- 各 turn で mode が自然に切替
- multi-turn context 保持 (3 turn 目の「もっと一般的に」が前文脈解決)

---

## SC-008: long press → 保存 → SavedAnswer 作成

**手順**:
1. assistant 答えを long press
2. context menu「保存 / コピー / 共有」表示
3. 「保存」tap

**期待結果**:
- haptic feedback (light impact)
- Settings → SavedAnswer 履歴に新エントリ追加 (引用なしでも保存可能)

---

## SC-009: long press → コピー

**手順**:
1. assistant 答えを long press
2. 「コピー」tap
3. 別アプリ (Notes) で paste 確認

**期待結果**:
- pasteboard に answer text がコピーされる

---

## SC-010: long press → 共有

**手順**:
1. assistant 答えを long press
2. 「共有」tap

**期待結果**:
- iOS standard ShareSheet 表示
- AirDrop / Notes / Mail 等の共有先選択可能

---

## SC-011: 既存 spec 021/033/047 動作維持

**手順**: 既存機能を順に確認:
- spec 021: ChatService.send で通常 RAG 動作 (内部 agent loop でも引用 chip 出る)
- spec 033: 左上 sidebar tap → session 履歴表示、session 切替動作
- spec 033: 擬似 streaming (15ms/文字) 動作
- spec 047: 引用記事から関連 ConceptPage chip 表示

**期待結果**: 全機能が V3.0 (spec 056) + agent loop (spec 057) 経由でも動作維持

---

## SC-012: error 時 retry button

**手順**:
1. Foundation Models を意図的に fail させる (例: 非常に長文 input で token overflow)
2. error UI + retry button 表示
3. retry button tap

**期待結果**:
- error 時に「⚠️ もう一度試してください」+ [再試行] button
- retry tap で同 question 再送信、agent loop 再開

---

## 既存機能 Regression

- spec 056 V3.0: 3 タブ + 知識 Clip 3 section 動作維持
- spec 042: ConceptPage 詳細 → 「学習する」→ DeepDiveChatView (spec 044) 動作
- spec 044: DeepDiveChatService 動作維持 (本 spec とは独立)
- spec 051: CloudKit sync 動作維持
- spec 043: SavedAnswer 既存データ閲覧維持 (履歴画面で表示)

---

## 実機検証フロー (推奨)

1. **基本動作** (30 分): SC-001 / SC-002 / SC-003 / SC-004 / SC-005
2. **「分かりません」 排除** (15 分): SC-006 (10 質問 sample)
3. **mode 切替 + multi-turn** (15 分): SC-007
4. **長押し menu** (15 分): SC-008 / SC-009 / SC-010
5. **regression** (30 分): SC-011 (spec 021/033/047 動作)
6. **edge case** (15 分): SC-012 (error retry)

---

## Acceptance Criteria

12 シナリオ全てが ✅ PASS で V3.0 release 可能。
1 つでも ❌ FAIL なら原因分析 + 修正 + 再検証。
