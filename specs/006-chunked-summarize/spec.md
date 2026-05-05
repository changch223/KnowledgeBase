# Feature Specification: 長文記事の Chunked Summarization

**Feature Branch**: `006-chunked-summarize`
**Created**: 2026-05-05
**Status**: Draft
**Input**: User description: "長文記事の chunked summarization。本文が 1000 文字を超える場合、1000 文字単位の chunk に分割し、各 chunk から Foundation Models で essence / keyFacts / entities を生成。最終 chunk として全 chunk の essence をまとめた meta-summary を生成し、それを ExtractedKnowledge.essence + summary として保存。keyFacts と entities は全 chunk から重複排除して統合。Foundation Models の context window 4096 token 制限内で確実に走らせる目的。本文 1000 文字以下は従来通り 1 回の生成で完了。chunked 処理中も BottomStatusBar に chunk 1/N の進捗を表示。最大 chunk 数 10 (日本語 10000 文字までの記事をフルカバー、それ以上は冒頭 10 chunk のみ要約)。spec 005 で実装済の重複抑止ガード + Apple Intelligence availability チェック + 本文未取得時 skip は引き継ぐ。"

## User Scenarios & Testing

### User Story 1 - 長文記事を context window エラー無しで要約 (Priority: P1)

ユーザーが長文記事 (例: zenn の技術記事 5000 文字、ニュース連載 8000 文字) を保存したとき、現状は本文を 1200 文字に切り詰めて Foundation Models に渡しているため、後半の情報が抜け落ちる。さらに記事によっては 1200 文字でも token 上限を超えるケースがあった。chunked summarization により、本文を細かく分割して順次処理することで、長文記事の全体像を漏らさず要約に反映する。

**Why this priority**: 知識管理アプリの中核機能 (要約) が長文記事で破綻する/情報損失するのは深刻。直近の実機テストでもエラー報告が継続している。

**Independent Test**: 5000 文字の本文を持つ記事を保存し、知識サマリの essence + summary が後半の情報も反映していることを確認できる。

**Acceptance Scenarios**:

1. **Given** ユーザーが本文 5000 文字の記事を共有保存した状態、**When** body 抽出が succeeded になり知識抽出フェーズに入る、**Then** 5 つの chunk に分割されて順次 Foundation Models で処理され、最終的に統合された essence / summary / keyFacts / entities が ExtractedKnowledge に保存される
2. **Given** ユーザーが本文 800 文字の短い記事を保存した状態、**When** 知識抽出フェーズに入る、**Then** 従来通り 1 回の生成で完了し、chunked 処理は走らない (オーバーヘッド無し)
3. **Given** ユーザーが本文 15000 文字の超長文記事を保存した状態、**When** 知識抽出フェーズに入る、**Then** 冒頭 10 chunk (10000 文字相当) のみ処理され、それ以降は要約対象外として処理が完了する

---

### User Story 2 - chunk 進捗の可視化 (Priority: P2)

長文記事の知識抽出は chunk 数に比例して時間がかかる (1 chunk あたり 25 秒前後の実測 → 10 chunk で 4 分超)。ユーザーが「いつ終わるか」「今どこを処理中か」を画面下部の BottomStatusBar で把握できるようにする。

**Why this priority**: 処理時間が長くなる仕様変更なので、進捗が見えないと「アプリが固まったか」「失敗したか」の判断ができず、強制終了して再起動するリスクがある (これまでもライブ更新の問題でユーザーが閉じて再起動する習慣がある)。

**Independent Test**: 5 chunk 必要な記事を保存し、BottomStatusBar に「知識抽出中: 1/5」「2/5」... と進む表示が見えることを確認。

**Acceptance Scenarios**:

1. **Given** 本文 3500 文字の記事の知識抽出が始まった状態、**When** chunk 1 の処理が完了して chunk 2 が開始される、**Then** BottomStatusBar の表示が「知識抽出中 1/4」から「知識抽出中 2/4」に変わる
2. **Given** chunked 処理中の途中の状態、**When** ユーザーが Detail 画面を開く、**Then** 既に処理済みの chunk 部分の知識サマリは見える状態を保ち、残り chunk の処理が完了するごとに段階的に追加情報が表示される
3. **Given** 本文 800 文字 (chunked にならない) の記事の知識抽出中、**When** BottomStatusBar の表示を見る、**Then** 従来通り「知識抽出中: <タイトル>」のみで chunk 数は表示されない

---

### User Story 3 - chunk の部分的失敗に強い (Priority: P3)

10 chunk 中 1-2 chunk が Foundation Models のエラー (一時的な availability 問題、極端な入力等) で失敗しても、残りの chunk から得られた情報は最大限活用したい。

**Why this priority**: 完璧主義で「1 chunk でも失敗したら全失敗」では、長文記事ほど成功率が下がる。MVP として「partially succeeded」状態を活用し、得られた情報を表示する。

**Independent Test**: 一部の chunk 生成が失敗するシナリオ (例: モックで 3 chunk 中 1 chunk を throw させる) を再現し、残り 2 chunk の essence / keyFacts / entities が ExtractedKnowledge に保存されることを確認。

**Acceptance Scenarios**:

1. **Given** 5 chunk 中 chunk 3 の生成が失敗した状態、**When** chunked 処理が完了する、**Then** ExtractedKnowledge.status は `.partiallySucceeded` となり、残り 4 chunk から得た essence / keyFacts / entities が保存される。failureReason に「chunk 3 失敗」のようなログが残る
2. **Given** meta-summary 生成 (最終統合 chunk) が失敗した状態で個別 chunk は成功している、**When** 処理が完了する、**Then** chunk 1 の essence をそのまま ExtractedKnowledge.essence の fallback として使う。summary は全 chunk の essence を文字列連結したものになる
3. **Given** すべての chunk 生成が失敗した状態、**When** 処理が完了する、**Then** ExtractedKnowledge.status は `.failed`、failureReason には「全 chunk 失敗」が記録される (再試行ボタンが Detail 画面に表示される)

---

### Edge Cases

- **本文がちょうど 1000 文字**: chunked パスではなく単発 1 回生成 (閾値は >1000 文字で chunked、<=1000 文字で単発)
- **本文が 10001 文字以上**: 冒頭 10 chunk = 10000 文字のみ処理し、後半は要約対象外。Detail 画面に「※ 本文が長いため冒頭 10000 文字のみを要約しています」のような注記を表示
- **Apple Intelligence が途中で利用不能になった**: 残り chunk は skip 扱い、完了済 chunk の情報で `.partiallySucceeded` 保存
- **chunk 境界が単語/文の途中で切れる**: 句点 (`。`) または改行 (`\n`) で graceful に切り、なければ 1000 文字 hard cut
- **重複する keyFacts**: 異なる chunk で同じ statement (まったく同じ文字列、trim 済比較) が生成された場合は 1 件のみ保存
- **重複する entities**: 同じ name (大文字小文字無視) は 1 件のみ。salience は最大値、type は多数決
- **本文に含まれる引用符などで chunk 分割が破綻**: 文字数優先で機械的に切る (構文を保つ努力はしない)
- **複数記事が同時に長文記事**: ProcessingMonitor は 1 記事ずつ表示する仕様 (spec 005 既存)。長文記事処理中は他記事の処理が後ろ倒しになる
- **Detail 画面を chunked 処理中に閉じる**: バックグラウンドで処理続行。完了後の表示は次回開いたときに live update で見える

## Requirements

### Functional Requirements

- **FR-001**: システムは本文 (ArticleBody.extractedText) が **1000 文字を超える** 場合、chunked summarization パスを採用する
- **FR-002**: chunk サイズは **1000 文字**。境界は句点 (`。`) または改行を優先し、見つからなければ 1000 文字 hard cut
- **FR-003**: 1 記事あたりの最大 chunk 数は **10**。本文 10000 文字以上は冒頭 10000 文字のみ処理
- **FR-004**: 各 chunk は **逐次** Foundation Models に渡され、`essence` / `keyFacts` / `entities` を生成する (並列不可、進捗 UX のため)
- **FR-005**: 全 chunk の処理完了後、各 chunk の `essence` をまとめた **meta-summary** を 1 回追加で Foundation Models に生成依頼し、その結果を ExtractedKnowledge.essence + summary として保存
- **FR-006**: keyFacts は全 chunk から **statement の trim 済完全一致で重複排除** して統合
- **FR-007**: entities は全 chunk から **name の case-insensitive 一致で重複排除**。salience は最大値を採用、type は多数決
- **FR-008**: BottomStatusBar は chunk 処理中に「知識抽出中 N/M」(例: 「知識抽出中 3/5」) と表示する。本文 1000 文字以下の単発処理時は従来通り「知識抽出中」のみ
- **FR-009**: ExtractedKnowledge には新たに「処理済 chunk 数」「総 chunk 数」「skipped tail chars」(超長文時の対象外文字数) の追加メタデータ列を持たせる (将来 spec で再生成判定や UI 表示に活用)
- **FR-010**: 本文 **1000 文字以下** の場合は従来 (spec 004) の単発生成パスをそのまま使う (chunked 処理オーバーヘッド無し)
- **FR-011**: spec 005 で実装済の **重複抑止ガード** (同 article への並行 extract 呼び出しを既存 task 待機で吸収) を chunked パスでも維持する
- **FR-012**: spec 005 で実装済の **Apple Intelligence availability チェック** を chunked パスでも維持。利用不可なら従来通り `.skipped` で保存
- **FR-013**: spec 005 で実装済の **本文未取得時 skip** を chunked パスでも維持
- **FR-014**: 個別 chunk が 1-2 件失敗しても残り chunk から得た情報を `.partiallySucceeded` として保存する。**全 chunk 失敗時のみ** `.failed`
- **FR-015**: meta-summary 生成のみ失敗した場合、個別 chunk の `essence` を連結したものを `summary` として保存し、`essence` は最初の chunk のものを採用
- **FR-016**: 1 記事あたりの最大処理時間は緩く 5 分以内 (10 chunk × 25 秒 + meta-summary 25 秒 ≒ 4 分 25 秒)。タイムアウトは MVP では実装せず、ユーザーが Detail 画面で再試行ボタンから手動 cancel できる動線で対応
- **FR-017**: 超長文記事 (10001 文字以上) の場合、Detail 画面の知識サマリ末尾に「本文が長いため冒頭 10000 文字のみを要約対象としています」のような注記を表示する
- **FR-018**: chunked 処理中の途中状態 (例: chunk 3/5 完了時点) では ExtractedKnowledge.status を `.extracting` に保ち、最終 chunk + meta-summary が完了するまで `.succeeded` / `.partiallySucceeded` にしない (中間状態を Detail に出さない)

### Key Entities

- **Chunk**: 本文の連続した部分文字列 (最大 1000 文字)、index (0-9)、total。永続化しない (処理中の transient データ)
- **ChunkResult**: 1 chunk 分の生成結果 (essence, keyFacts, entities)。永続化しない
- **MetaSummaryInput**: 全 chunk の essence を箇条書きで列挙したもの。Foundation Models への入力。永続化しない
- **ExtractedKnowledge** (既存): chunked 処理の出力先。新規追加列 = 処理済 chunk 数 / 総 chunk 数 / skipped tail chars

## Success Criteria

### Measurable Outcomes

- **SC-001**: 5000 文字の本文を持つ記事の知識抽出が 100% 成功する (context window エラーで一切失敗しない)
- **SC-002**: 10000 文字の本文を持つ記事の知識抽出も 100% 成功する (10 chunk + meta-summary)
- **SC-003**: 1 chunk 処理ごとに BottomStatusBar の N/M 表示が 0.5 秒以内に更新される
- **SC-004**: 800 文字の短い記事は従来通り単発処理で完了し、chunked 処理オーバーヘッドが 0 (処理時間が spec 004 と同等)
- **SC-005**: 5000 文字記事の総処理時間は 3 分以内 (5 chunk + meta-summary = 6 回の生成 × 25 秒 ≒ 2 分 30 秒)
- **SC-006**: keyFacts の重複が 1 件以下 (5000 文字記事を 5 chunk で処理、各 chunk から 3-5 件の keyFacts 生成、重複排除後 10-15 件に収まる)
- **SC-007**: 1 chunk 失敗時、残り chunk から得た情報が ExtractedKnowledge.status `.partiallySucceeded` として保存される (全失敗ではない)
- **SC-008**: Detail 画面で chunked 処理中の記事を開いても、live update で各 chunk 完了ごとに段階的に情報が増えていく (画面を閉じる必要無し)

## Assumptions

- **chunk 数上限 10 は MVP の妥協点**: 平均的な日本語 web 記事は 2000-5000 文字、技術記事や連載は 5000-15000 文字。冒頭 10000 文字でも記事の主題と主要な事実は捕捉できる前提
- **chunk 間の文脈共有は行わない**: 各 chunk は独立して Foundation Models に渡される (前 chunk の essence を次 chunk の prompt に含める等の高度化は将来 spec)
- **meta-summary は逐次的な統合のみ**: 個別 chunk の essence をリストにして「これらをまとめて 150 字以内で」と指示する単純な集約。階層的要約 (全 chunk → 中間 5 chunk → 最終 1 chunk) は実装しない
- **言語は日本語前提**: spec 004 と同じく Generable type の `@Guide` 説明文も日本語、本文も日本語想定。英語混在記事は対象だが純英語記事の最適化は対象外
- **chunk 処理は逐次**: 並列化すると Foundation Models のセッション競合 + 進捗表示が複雑になるため MVP は逐次。並列化は将来 spec 候補
- **削除済み記事の chunked 処理キャンセル**: ユーザーが Detail 画面以外 (例: スワイプ削除) で article を消した場合、進行中の chunk 処理は次の chunk 開始前にチェックして中断する (現状の `Task.isCancelled` チェックを継続)
- **Foundation Models の context window 上限は今後拡張される可能性**: その場合 chunk サイズを 1000 → 2000 等に上げる調整が必要だが、当面 1000 で固定
- **実機 Apple Intelligence 対応端末でのみ動作**: シミュレータで利用不可な場合は spec 005 と同じく `.skipped` 表示
