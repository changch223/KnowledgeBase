# Quickstart: 知識抽出 + 要約 — 手動検証ガイド

**Feature**: spec 004 — 知識抽出 + 要約 (Knowledge Extraction + Summarization)
**Date**: 2026-05-04

実装完了後、本ドキュメントの手順に従って **すべての user story と edge case** を Apple Intelligence 対応端末上で検証する。検証結果を PR description に貼付し、Constitution Per-PR ゲートの一部とする。

## 前提

- spec 001 / 002 / 003 が merge 済み
- **Apple Intelligence 対応端末** (iPhone 15 Pro 以降、iPad mini A17 Pro、iPad Pro M1 以降) または対応シミュレータ
- iOS 26+ / iPadOS 26+
- Xcode 17+
- 端末で **Apple Intelligence が有効化済** (設定 → Apple Intelligence と Siri → Apple Intelligence ON)
- 端末がオンライン (Foundation Models のモデルダウンロードが完了している必要あり)
- spec 004 用ブランチに切り替え済 (実装フェーズで作成)

## ビルド & 自動テスト

```bash
xcodebuild test \
  -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0'
```

期待:
- 既存テスト + `KnowledgeExtractorTests` (Mock で 6 ケース)、`KnowledgeExtractionServiceTests` (9 ケース)、`SwiftDataArticleKnowledgeStoreTests` (8 ケース) が全 pass
- 実 Foundation Models のテストは含まない (Mock のみ、Constitution テストゲート / 決定論的)

## User Story 1: 自動抽出 + 一覧表示 (P1)

### 手順

1. Apple Intelligence 対応端末でアプリを起動 → Safari で記事ページ (例 `https://www.apple.com/jp/newsroom/`) を共有 → KnowledgeTree → 「保存しました」。
2. アプリを開いて enrichment + 本文抽出 + 知識抽出 が完了するまで **5〜10 秒程度** 待機 (合計時間: spec 002 enrichment ~5s + spec 003 body ~1s + spec 004 knowledge ~6s)。
3. 一覧の該当行に以下が表示されることを確認:
   - サムネイル (spec 002)
   - canonical タイトル (spec 002)
   - **essence の 1 行プレビュー** (spec 004 / FR-010)
   - **Entity チップ 上位 3 つ** (例: 「Apple」「iOS 26」「WWDC」、spec 004 / FR-010)
   - **「AI 生成」ラベル** (FR-012)
4. **Pass: FR-001 / FR-010 / FR-012 / Acceptance Scenario 1 + 2 + 3**

### 60 fps スクロール確認

5. 100 件以上 enrichment + body + knowledge 完了状態の seed をシミュレータに作成 (debug スイッチ等)。
6. 一覧をスクロール → Instruments の Time Profiler / SwiftUI Profiler で 60 fps 維持を確認。
7. **Pass: SC-005**

## User Story 2: Reader View で知識を構造表示 (P2)

### 手順

1. 一覧で ExtractedKnowledge .succeeded (または .partiallySucceeded) の記事をタップ → Reader View が開く。
2. Reader 最上部に **「知識サマリ (AI 生成)」セクション** が表示され、以下の順で構成されていることを確認:
   - **essence** (太字 1 行)
   - **summary** (説明的 2-3 文の段落)
   - 「重要な事実」見出し + key facts list (種別アイコン付き bullet、例: 🗓️ event、💬 quote、📊 statistic)
   - 「登場するもの」見出し + entity chips (種別アイコン付き)
   - **区切り線** (細線または余白)
   - 「本文」見出し
   - 本文 (spec 003 の plain text)
3. **Pass: FR-011 / Acceptance Scenario 1**

### Dynamic Type 検証

4. OS 設定 → アクセシビリティ → 文字サイズを最大に → 同記事を Reader で開く → 知識セクションも本文と同じく追従、layout 崩れなし。
5. **Pass: Acceptance Scenario 2 / SC-007**

### Dark Mode 検証

6. OS 設定 → 画面表示と明るさ → ダーク → Reader を開く → 暗背景でテキスト・chip すべて視認可能。
7. **Pass: Acceptance Scenario 2**

### 部分成功 (.partiallySucceeded) の表示

8. .partiallySucceeded の記事 (例: essence + summary はあるが key facts / entities が空) を seed → Reader を開く → essence + summary は表示される、空の key facts / entities サブセクションは表示されない。
9. **Pass: Acceptance Scenario 4 / FR-014**

### 知識なし記事のフォールバック

10. ExtractedKnowledge .failed または不在の記事 → Reader を開く → 知識セクションは出ず、本文が冒頭から始まる。
11. **Pass: Acceptance Scenario 3 / FR-016**

## User Story 3: Apple Intelligence 不可能時のフォールバック (P3)

### 手順 (Apple Intelligence OFF)

1. 端末の OS 設定 → Apple Intelligence と Siri → Apple Intelligence を **OFF** に切替。
2. アプリを再起動 → 記事を新規共有保存 → 一覧に表示される (spec 001-003 の機能は動く)。
3. 数秒待つ → 一覧の該当行に **essence や entity chip が表示されない** ことを確認 (知識セクションなし)。
4. 一覧の該当行をタップ → Reader View が開くが **知識サマリセクションが表示されず、本文が冒頭から** 表示される (spec 003 の Reader はそのまま動く)。
5. **Pass: FR-003 / FR-016 / Acceptance Scenario 1 + 3**

### Apple Intelligence ON 切替後の backfill

6. 上記の状態でアプリを完全終了 → 設定で Apple Intelligence を **ON** に戻す → アプリを再起動。
7. 起動時 backfill が動き、過去 OFF だった記事の知識が順次抽出される (1 件 6 秒程度)。
8. 数十秒〜数分待つ → 一覧の該当行に essence + entity chip が現れる。
9. **Pass: FR-018 / Acceptance Scenario 2**

### Apple Intelligence 非対応端末 (シミュレータ A17 Pro 非対応プロファイル等)

10. iPhone 14 シミュレータプロファイル (Apple Intelligence 非対応) で実行 → 知識抽出ジョブはサイレントに skip → spec 001-003 の機能は完全動作。
11. **Pass: SC-002**

## Edge Cases 検証

| ケース | 手順 | 期待 |
|---|---|---|
| extractedText 短すぎ (< 200 字) | 短い記事を保存 | 知識抽出ジョブ起動せず、ExtractedKnowledge 作成されず、UI 表示なし |
| safety filter blocked | 過激なコンテンツの記事を保存 (テスト用) | ExtractedKnowledge.status = .failed、UI 表示なし、Principle V |
| ハルシネーション疑い | 任意記事を抽出後、Reader で本文と key facts を見比べる | 80% 以上の facts が本文に存在 (SC-009、手動 sampling) |
| Article 削除時 cascade | 知識持ち記事をスワイプ削除 → SwiftData inspector で確認 | ExtractedKnowledge + KeyFact + KnowledgeEntity すべて削除、孤児なし |
| 同 entity 複数回 | 「Apple」が key fact 内 + entity 両方に出る記事 | MVP では deduplication しない、両方表示される |

## パフォーマンス検証

- **SC-001**: ArticleBody .succeeded → ExtractedKnowledge .succeeded まで median 6 秒以内 (Apple Intelligence 対応端末で 10 サンプル測定 → `specs/004-summarize/perf-results.md` に記録、PR に貼付)。
- **SC-004**: 抽出ジョブ実行中の一覧スクロール → main thread 占有 ≤ 100 ms (Instruments)。
- **SC-005**: 100 件 ExtractedKnowledge 持ち一覧 60 fps スクロール (Instruments)。
- **SC-006**: 一覧タップから Reader View 表示まで 300 ms 以内 (知識セクション追加でも spec 003 と同等)。

## ハルシネーション率 sampling (SC-009)

任意 20 記事をサンプリングし、各記事の key facts (3-5 件 × 20 = 60-100 件) を本文と見比べて:
- **本文に明示的に書かれている (ほぼ literal match)**: ✓
- **本文に書かれているが言い換え (semantic match)**: ✓ (許容)
- **本文に書かれていない / 推測 / 常識補完**: ✗ (ハルシネーション)

**80% 以上が ✓ なら SC-009 達成**。結果を `specs/004-summarize/hallucination-sampling.md` に記録。

## 一貫性 sampling (SC-010)

任意 20 記事の essence と summary を見比べて:
- **essence の主題が summary 冒頭の主題と一致 / 矛盾しない**: ✓
- **矛盾している (同じ記事を読んでいるとは思えない)**: ✗

**95% 以上が ✓ なら SC-010 達成**。

## ネットワーク監視 (Principle I 遵守確認)

Charles Proxy / Console.app で本 spec の動作中に観察:

- 本 spec 起因の **新規ネットワークリクエスト = 0** (Foundation Models on-device のため)
- spec 002 の enrichment fetch は別途あって良い
- 第三者 AI サーバー (OpenAI / Anthropic / Google 等) への接続: **0**

`specs/004-summarize/network-audit.md` に記録 (Principle I 完全維持の証跡)。

## アクセシビリティ検証

- **VoiceOver**: 知識サマリセクションの essence / summary / key fact / entity が日本語で正しく読み上げられる。
- **Dynamic Type**: 文字サイズ最大でも知識セクション + 本文の layout が崩れない。
- **Dark Mode**: 暗背景で知識セクション + entity chips が視認可能、種別アイコンの色も適切。
- **「AI 生成」ラベルの可視性**: 全表示箇所 (一覧、Reader 各セクション) で grep audit (T031 等で実施)。

## 検証完了の判定

すべての user story が "Pass"、edge case が期待通り、network 監視で本 spec 起因の送信ゼロ、ハルシネーション率 80% 以上、一貫性 95% 以上 → PR を merge 可能と判定。

不足した項目があれば spec 004 にフィードバックして再生成プロンプト調整 / 制約強化 (将来 spec 候補)。
