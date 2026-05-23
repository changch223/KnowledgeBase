# Quickstart: ConceptPage 実機検証シナリオ

**Feature**: spec 042 ConceptPage
**Phase**: 1 (Design & Contracts)
**Date**: 2026-05-23
**Audience**: ユーザー (実機検証担当)

本ドキュメントは spec.md の SC-001〜SC-010 を実機検証用の手順に展開した 10 シナリオ
セット。Apple Intelligence 有効の iPhone (iOS 26+、iPhone 15 Pro 以降) で実施する。
各シナリオは独立して実行可能、所要時間は合計 30-45 分目安。

事前準備:
- Xcode で `KnowledgeTree` scheme を実機 build & install
- App 起動 1 回 (bootstrap で BGTask register + 初期 backfill 起動)
- Apple Intelligence on (設定 → Apple Intelligence & Siri → on)
- iCloud sync 等は OFF (本検証は単一端末で完結)

---

## SC-001: 同名 entity 2 件で ConceptPage 自動生成 (P1, US1)

**目的**: 同名 entity が 2 件目の記事に登場した時点で ConceptPage が自動生成されることを確認。

**手順**:
1. ライブラリタブで既存 ConceptPage を確認 (なければ skip → Step 2)
2. Safari で「Apple Vision Pro」関連の Web 記事を 1 件保存 (Share Sheet → 知積)
3. ProcessingMonitor の表示が消えるまで待つ (通常 30-60 秒)
4. 知識 Clip タブを開く → 「あなたが追っている人物・モノ」セクションは **まだ表示されない** ことを確認 (entity 1 件のみ)
5. 別の「Apple Vision Pro」関連記事を 1 件追加保存
6. ProcessingMonitor の表示が消えるまで待つ
7. 知識 Clip タブを開く → 「あなたが追っている人物・モノ」セクションに **「Apple Vision Pro」カード** が出現することを確認 (30 秒以内)

**期待結果**:
- カード上に「Apple Vision Pro」の名前、関連記事 2 件、最終更新「今日」または「N 分前」
- summary は最初「整理中…」表示、BGTask 完了後 (1-10 分以内、または app を background → foreground で trigger) に AI 合成 summary に更新

**Pass criteria**: 2 件目記事保存から 30 秒以内に ConceptPage カード出現 (FR-001, SC-001)

---

## SC-002: AI 合成 summary が 200-400 字日本語 (P1, US1)

**目的**: AI 合成 summary が制約 (200-400 字、日本語、断定調、推測なし) を満たすことを確認。

**手順**:
1. SC-001 で生成された「Apple Vision Pro」ConceptPage が isStale=false になるまで待つ (5-10 分、または app foreground 復帰で trigger)
2. 知識 Clip タブから「Apple Vision Pro」カードをタップ → ConceptPageDetailView 表示
3. 「今わかっていること」セクションの summary 本文を確認

**期待結果**:
- summary は日本語 200-400 字 (1 ページ内に収まる程度)
- 断定調 (「である」「する」「だ」)、です・ます調なし
- 2 件記事の要点を統合した内容、推測 / 一般知識からの補強なし
- 「整理中…」 placeholder は消えている

**Pass criteria**: summary が SC-002 要件を全て満たす (FR-007, FR-031, SC-002)

---

## SC-003: crossSourceInsights が最大 7 件 bullet (P1, US1)

**目的**: 横断的知見が複数記事を統合した bullet 形式で表示されることを確認。

**手順**:
1. SC-002 と同じ ConceptPage 詳細画面
2. 「横断的知見」セクションを scroll で表示
3. bullet 各項目を確認

**期待結果**:
- 0〜7 件の bullet (記事が 2 件だと 0-2 件のことも多い、3+ 件保存後に再合成すると insights 増)
- 各 bullet 50-150 字、「単一記事だけでは見えない発見」を含む
  - 例: 「2024 年と 2026 年で価格戦略が変化」
- セクション自体は insights が 0 件なら非表示 (R8 仕様)

**Pass criteria**: bullet が複数記事の比較知見になっている (SC-003)、推測がない

---

## SC-004: 新記事 ingest で既存 ConceptPage が isStale (P1, US1)

**目的**: 新記事 ingest が完了すると関連 ConceptPage が 5 分以内に isStale = true でマークされることを確認。

**手順**:
1. SC-001-003 で生成された ConceptPage の最終更新時刻をメモ
2. 同 entity (「Apple Vision Pro」) を含む 3 件目の記事を Share Sheet で保存
3. ProcessingMonitor 完了まで待つ
4. 知識 Clip カードの最終更新時刻が更新され、summary が「整理中…」に戻ることを確認 (Stale 状態)
5. 5 分以内に BGTask が走り (または app background → foreground で trigger)、summary が新内容で再合成される

**期待結果**:
- 3 件目記事保存後、ConceptPage カード上で「整理中…」表示が一時的に出る
- 5 分以内に新 summary に更新 (3 件全部を踏まえた統合内容)

**Pass criteria**: isStale → 再合成サイクルが 5 分以内 (FR-004, FR-005, SC-004)

---

## SC-005: 5+ 関連記事で hierarchical + meta-summary パス (P1, US1)

**目的**: 5+ 関連記事を持つ ConceptPage の再合成が hierarchical パスで動作することを確認 (内部分岐、UI からは見えない)。

**手順**:
1. 同 entity (例: 「Tim Cook」) を含む記事を 6-8 件保存 (時間がかかる、SC-001 と同手順を繰り返し)
2. 全 ingest 完了 + Stale 再合成完了まで待つ (15-30 分)
3. ConceptPage 詳細画面を開き、summary が空になっていないことを確認

**期待結果**:
- 6-8 記事から統合された summary が生成される
- crossSourceInsights が 3-7 件、複数チャンクから抽出された知見を含む
- Context window overflow エラーで失敗しない

**Pass criteria**: 5+ 件で正常に summary 生成 (FR-009, SC-005)

---

## SC-006: rename / merge / delete (P2, US4)

**目的**: ConceptPage 編集操作 (rename / merge / delete) が 1 秒以内に DB 反映 + UI 更新されることを確認。

**手順**:
1. 任意の ConceptPage 詳細画面 → toolbar の [編集 ⋯] タップ → ConceptPageEditSheet 表示
2. **rename**:
   - 名前変更 → "Apple Vision Pro 2" のような新名前を入力 → 保存
   - 1 秒以内に画面 title が更新、知識 Clip カードも新名前で表示
3. **rename validation**:
   - 名前を空欄で保存 → 「概念名を入力してください」alert
   - 名前を 31 字 (例: 「あ」を 31 個) で保存 → 「30 文字以内」alert
4. **merge**:
   - 2 つの近い概念 (例: 「Apple」と「Apple Inc.」) を準備
   - 一方の編集 sheet で [統合] → 統合先選択 (一覧から選ぶ) → 確認 alert → 統合実行
   - 1 つに統合、関連記事数が合算、片方は消える
5. **delete**:
   - 任意の ConceptPage → [削除] → 確認 alert → 削除実行
   - 1 秒以内に画面が pop、知識 Clip カードからも消える
   - **関連 Article は ライブラリタブに残っている** ことを確認

**期待結果**:
- 全操作が 1 秒以内に UI 反映
- merge 後 source は消滅、target は両方の relatedArticles を持つ
- delete 後 ConceptPage 消滅、Article は raw データとして残存

**Pass criteria**: SC-006 (FR-014/015/016/018)

---

## SC-007: 100+ ConceptPage で 60fps scroll (P1, US2)

**目的**: 大量 ConceptPage 状態でも知識 Clip タブが 60fps を維持。

**手順**:
1. テストデータとして 100+ Article を保存 (時間制約で省略可、または既存 spec 011 と同じく長期利用で蓄積)
2. ConceptPage が 50+ 件生成された状態で知識 Clip タブを開く
3. 「あなたが追っている人物・モノ」セクションは上位 5 件のみ表示、「+N すべて見る」リンクが出る
4. リンクタップ → 全 ConceptPage 一覧画面 (LazyVStack) → 高速 scroll
5. (任意) Instruments の SwiftUI template で 60fps 計測

**期待結果**:
- 知識 Clip タブ自体は 5 件 + リンクのみで軽い (frame drop なし)
- 全 ConceptPage 一覧画面の scroll が 60fps 維持

**Pass criteria**: scroll が滑らか (SC-007)、Instruments で frame drop 5% 未満 (任意)

---

## SC-008: Foundation Models 不可端末で Fallback (P1, edge case)

**目的**: Apple Intelligence 無効 / 未対応端末で Fallback service が essence 並べた summary を silent に生成し、ユーザーに失敗表示しないことを確認。

**手順**:
1. 設定 → Apple Intelligence & Siri → off に切替 (または非対応端末で実行)
2. App を再起動
3. 2 件の同 entity 記事を保存
4. 知識 Clip タブで ConceptPage カード出現を確認
5. 詳細画面で summary を確認

**期待結果**:
- ConceptPage は正常に生成される (Fallback で isStale=false)
- summary は essence 並べた簡易テキスト (200-400 字の AI 統合ではないが、表示可能)
- crossSourceInsights は essence 最初 3 件の冒頭文を bullet 化
- **「AI 失敗」「Apple Intelligence 必要」等の警告表示なし** (calm UX)
- 後で Apple Intelligence on にして再起動 → 新記事 ingest 時に上書きされる (Foundation 経路)

**Pass criteria**: SC-008 (FR-010, V Calm UX) — silent degrade、UI に失敗を見せない

---

## SC-009: 既存記事 backfill (P1, edge case)

**目的**: V1 リリース後 1 回起動時に既存 Article 群から ConceptPage 群が初期 backfill されることを確認。

**手順**:
1. (検証用 build) UserDefaults flag `ConceptPage.backfillCompleted` を手動で false にリセット
   - Xcode debug console: `UserDefaults.standard.removeObject(forKey: "ConceptPage.backfillCompleted")`
2. App を強制終了 → 再起動
3. App.task で backfillFromExistingArticles 起動 (silent)
4. 15-30 分待つ (既存 50+ 件 Article から ConceptPage 群が徐々に生成 + 再合成)
5. 知識 Clip タブで複数の ConceptPage カード出現を確認

**期待結果**:
- 24 時間以内に主要概念 (10-20 件) が surface 可能になる
- backfill 中も app は通常使用可能 (進捗バーなし、Constitution V)
- 2 回目以降の再起動では backfill 走らない (flag check)

**Pass criteria**: SC-009 (FR-013)

---

## SC-010: 関連記事タップ → ArticleDetailView 遷移 (P1, US3)

**目的**: ConceptPage 詳細から原典 Article への jump が 1 秒以内に遷移することを確認。

**手順**:
1. 任意の ConceptPage 詳細画面
2. 「関連記事」セクションを scroll
3. 関連記事の 1 件をタップ
4. 遷移時間を計測 (タップから ArticleDetailView 表示まで)
5. 戻る → 別の関連記事タップ → 同様確認

**期待結果**:
- 1 秒以内に ArticleDetailView 表示 (タイトル + 本文)
- 戻る gesture で ConceptPageDetailView に復帰
- 「つながる人物・モノ」セクションの chip タップで他 ConceptPageDetailView に再帰遷移

**Pass criteria**: SC-010 (FR-023, FR-024)

---

## 既存回帰 (V1 全体の最後に 1 回実施)

新規 spec 042 の実装が既存機能に regression を入れていないことを確認:

1. **記事保存 (spec 001)**: Share Sheet からの保存が以前と同様に動作
2. **AI チャット (spec 021)**: チャット画面で質問応答が動作
3. **知識ダイジェスト (spec 018)**: 知識 Clip タブの Digest セクションが正常表示
4. **Auto-Tag (spec 012)**: 新規記事に Tag が自動付与される
5. **Knowledge Graph (spec 040)**: GraphNode 抽出が動作 (本 spec が依存)
6. **Conflict Detection (spec 037)**: 衝突提案が知識 Clip タブに表示
7. **Search (spec 044)**: 既存検索が動作 (本 spec で SearchService 拡張する P3 部分は要 spec.md US6 検証)

各項目 1-2 分で動作確認、合計 10-15 分。

---

## 自動テスト確認 (Claude 側で実施済み、ユーザー実機検証前に PASS 必須)

```bash
# Simulator 全テスト
xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:KnowledgeTreeTests/ConceptSynthesisServiceTests \
    -only-testing:KnowledgeTreeTests/ConceptPageStoreTests \
    -only-testing:KnowledgeTreeTests/KnowledgeExtractionServiceTests
```

期待: 全 ~26 ケース PASS。fail があれば実機検証前に修正必須。
