# Quickstart: Understanding Chat 実機検証シナリオ

**Feature**: spec 044 Understanding Chat
**Phase**: 1 (Design & Contracts)
**Date**: 2026-05-23
**Audience**: ユーザー (実機検証担当)

spec.md SC-001〜SC-010 を実機検証手順に展開。Apple Intelligence 有効の iPhone (iOS 26+) で実施。所要時間 25-35 分。

事前準備:
- Xcode で `KnowledgeTree` scheme を実機 build & install
- App 起動 1 回 (bootstrap で 3 新 service 構築 + tab default migration)
- Apple Intelligence on
- spec 042 ConceptPage が動作中 (5+ ConceptPage 既存、userUnderstanding=0 〜 5 が混在)
- spec 043 SavedAnswer が動作中 (3+ SavedAnswer 既存、うち 1 件は isStale=true)
- spec 040 GraphNode/GraphEdge が動作中 (optional、なくても波及スキップで成立)

---

## SC-001: 学習タブ 1 秒以内表示 (P1, US1)

**目的**: 学習タブを開いてから上位 5 カードが 1 秒以内に表示されること確認。

**手順**:
1. アプリ起動 (初回 or 再起動)
2. 学習タブ (左端、`book.fill` icon) を tap
3. 1 秒以内に 5 カードが表示されることを目視
4. (任意) Xcode Instruments の Time Profiler で実測

**期待結果**:
- 5 カード並ぶ (or 候補不足なら少数 + 「+N すべて見る」なし or 空状態)
- 各カードに label badge (「新しい知識」「更新が必要」「理解が浅い」「深掘り余地あり」「復習」) と lastInteractedAt 相対時刻 (あれば)
- ProgressView は最初の 100ms 程度のみ

**Pass criteria**: SC-001 (1 秒以内)

---

## SC-002: カードタップ → AI 初期発話 3 秒以内 (P1, US2)

**目的**: カードタップで DeepDiveChatView 起動 + AI 家庭教師調の初期発話が 3 秒以内に表示。

**手順**:
1. 学習タブで任意の ConceptPage カード (例: 「Apple Vision Pro」) を tap
2. 画面遷移直後「家庭教師を起動中…」ProgressView 表示確認
3. 3 秒以内に AI 初期発話 (家庭教師調の逆質問、例:「Apple Vision Pro について、何が一番気になりますか?」) が表示

**期待結果**:
- 画面 title が「Apple Vision Pro を深掘り」
- 下部 3 ボタン (✓ わかった / 🤔 もっと / ✗ 違う) sticky 表示
- AI 初期発話が家庭教師調 (答えではなく質問形式)

**Pass criteria**: SC-002 (3 秒以内 + 家庭教師調 prompt)

---

## SC-003: 「✓ わかった」で +1 1 秒以内 (P1, US3)

**目的**: 「✓ わかった」タップで userUnderstanding +1 + DB 永続化 + 1 秒以内に UI 反映。

**手順**:
1. 学習タブで userUnderstanding=0 の ConceptPage を選択 → deep dive chat 起動 (SC-002 と同)
2. 下部「✓ わかった」を tap
3. Xcode debug console で DB peek (or 学習タブに戻ってカードが下位 or 入れ替わるか確認)

**期待結果**:
- 触覚 fb (light haptic) のみ、効果音 / 通知 / バッジゼロ
- UnderstandingInteraction 1 件 insert (action="understood")
- ConceptPage.userUnderstanding が 1 に更新
- 1 秒以内に DB 反映

**Pass criteria**: SC-003 (1 秒以内 + UI 通知ゼロ)

---

## SC-004: 1-hop 波及 2 秒以内 (P1, US3)

**目的**: 「✓ わかった」で関連 ConceptPage (graph 1-hop neighbor) に波及伝播が 2 秒以内。

**手順** (graph 既存条件下):
1. spec 040 で graph が構築済 ConceptPage A (1-hop neighbor 5-10 件) を選択 → deep dive chat
2. 「✓ わかった」を tap
3. Xcode log で `propagated: N neighbors updated` 確認
4. (任意) 該当 neighbor ConceptPage 詳細を開き、userUnderstanding が前回より +1 (累積 2 件目で +1) を確認

**期待結果**:
- 2 秒以内に neighbor 更新完了 (log 出力)
- propagated action が UnderstandingInteraction に記録

**Pass criteria**: SC-004 (2 秒以内、graph 5-10 node)

**Skip 条件**: graph が空 or 既存対象に neighbor がない場合 → 「graph 不存在で silent degrade」を確認すれば OK (本体 +1 のみ)

---

## SC-005: 起動 default タブが学習タブ 100% (P1, US5)

**目的**: アプリ完全終了 → 再起動で必ず学習タブが選択されている。

**手順**:
1. 学習タブ以外 (例: 知識 Clip) を選択した状態でアプリを App Switcher から完全終了
2. アプリ再起動
3. 学習タブが選択されていることを目視

**期待結果**:
- 起動完了後の最初の画面が学習タブ (左端、book.fill)
- migration 1 回限り (UserDefaults `spec044_learningTabMigrated`=true)

**Pass criteria**: SC-005 (100%)

**注**: 既存ユーザー (spec 035 で .knowledgeClip default 設定済) は初回 spec 044 起動で強制 .learning。2 回目以降は session 内タブ選択保持 (FR-002 シナリオ 2)。

---

## SC-006: 100+ 件 UnderstandingCard で 60fps (P2, US6)

**目的**: 学習タブで「+N すべて見る」遷移先 LazyVStack で 100+ 件 scroll が 60fps 維持。

**手順** (本格負荷試験は時間制約で省略可、目視 OK):
1. ConceptPage 50+ 件 + SavedAnswer 30+ 件存在の状態で学習タブを開く
2. 「+N すべて見る」tap → UnderstandingCardListView 表示
3. リスト全体を勢いよく scroll してカクつき確認

**期待結果**:
- LazyVStack で smooth scroll、frame drop なし
- (任意) Instruments SwiftUI template で FPS 計測

**Pass criteria**: SC-006 (60fps 維持)

---

## SC-007: 空状態 placeholder 1 秒以内 (P1, US1 Edge)

**目的**: ConceptPage / SavedAnswer 共に 0 件で学習タブを開いた時、空状態 placeholder が 1 秒以内に表示。

**手順**:
1. 新規インストール状態 or 全 ConceptPage / SavedAnswer 削除済状態
2. 学習タブを tap
3. 1 秒以内に「まだ学ぶカードがありません。記事を保存したり AI チャットで質問してみましょう」表示

**期待結果**:
- 空状態 view が表示 (loading spinner が長く回らない)
- 「+N」link 非表示
- 1 秒以内

**Pass criteria**: SC-007 (1 秒以内)

---

## SC-008: 「✓ わかった」後 surface 入れ替わり (P1, US3)

**目的**: 「✓ わかった」した ConceptPage が直後の学習タブ再表示で上位 5 件から外れる or 表示位置が下がる。

**手順**:
1. 学習タブで上位 5 件のうち userUnderstanding=0 の ConceptPage A を選択
2. deep dive chat → 「✓ わかった」tap
3. ナビゲーション戻る (or アプリを background → foreground)
4. 学習タブを再表示 → A が消えている or 下位に下がっていることを目視

**期待結果**:
- A の userUnderstanding=1 で newKnowledge → shallow に label 変化、または別の高 score カードに入れ替わる
- 学習体験が連続的 (同じカード何度も surface されない)

**Pass criteria**: SC-008 (入れ替わり実現)

---

## SC-009: streak / バッジ / 通知 ゼロ (P1, FR-022〜024)

**目的**: 1 セッション通じて streak / バッジ / 通知 / 効果音 が **一切発生しない** ことを確認 (calm UX)。

**手順**:
1. 学習タブで 3-5 件 deep dive chat を実施、各「✓ わかった」or「🤔 もっと」or「✗ 違う」を選ぶ
2. アプリを background → foreground 数回
3. AI ブレインタブ / 知識 Clip タブ / ライブラリタブ を巡回

**期待結果**:
- アプリ icon に未読 badge 一切なし
- push 通知 / アプリ内 banner 一切なし
- 「連続学習日数」「今日のストリーク」等の表示 ゼロ
- 効果音 ゼロ (haptic light のみ許容)

**Pass criteria**: SC-009 (binary check、何かあれば fail)

---

## SC-010: AI ブレイン統計 0 件で非表示 (P3, US10)

**目的**: AI ブレインタブの「学習統計」セクションが 0 件で非表示 (calm UX、空セクション出さない)。

**手順 A** (0 件状態):
1. 新規インストール状態 (UnderstandingInteraction = 0 件)
2. AI ブレインタブを開く
3. 「学習統計」セクションが **非表示** であることを確認

**手順 B** (1+ 件状態):
1. 学習タブで「✓ わかった」を 2-3 件タップ済状態
2. AI ブレインタブを開く
3. 「今月 N 件『わかった』」「最近深掘り N 概念」表示確認

**期待結果**:
- 0 件で section ごと描画スキップ
- 1+ 件で section 表示 + 数値正確

**Pass criteria**: SC-010 (0 件非表示 + 1+ 件表示)

---

## 既存回帰 (合計 10-15 分)

新 spec 044 で既存機能が壊れていないことを確認:

- [ ] **AI Chat (spec 021)**: AI チャットタブで従来通り質問応答動作、ChatService 無改修なので影響ゼロ想定
- [ ] **ConceptPage (spec 042)**: 知識 Clip タブで ConceptPage 詳細表示 + rename/merge/delete 動作、toolbar「学習する」Button 追加で他 toolbar item に影響なし
- [ ] **SavedAnswer (spec 043)**: ConceptPage 詳細「質問と答え」セクション + 履歴画面 動作
- [ ] **記事保存 (spec 001)**: Share Sheet 経由保存正常、KnowledgeExtractionService hook 改修ゼロ
- [ ] **検索 (spec 044 既存)**: 既存 Article 検索動作
- [ ] **タブ移動**: 4 タブ全て自由に行き来可、session 内では選択タブ保持

各 2 分で動作確認、合計 12-15 分。

---

## 自動テスト確認 (Claude 側で実施済み、ユーザー実機検証前に PASS 必須)

```bash
xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:KnowledgeTreeTests/UnderstandingCardSurfaceServiceTests \
    -only-testing:KnowledgeTreeTests/UnderstandingTrackerServiceTests \
    -only-testing:KnowledgeTreeTests/DeepDiveChatStarterTests
```

期待: 23 ケース全 PASS (10 + 8 + 5)。fail があれば実機検証前に修正必須。

```bash
xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:KnowledgeTreeUITests/UnderstandingTabUITests
```

期待: 3 ケース PASS。pre-existing flaky 8 件は本 spec と分離。
