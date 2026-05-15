# Feature Specification: 用語のやさしさ整理 (機能 W)

**Feature Branch**: `038-friendly-terms` (実装時に作成)
**Created**: 2026-05-08
**Status**: Draft (specify+plan のみ)
**Vision**: [VISION.md](../VISION.md) 機能 W

## なぜ (Why)

VISION.md コア価値「**完全な非エンジニアでも使えるシンプルさ**」を実現する横断的改善。

ユーザー要望 (2026-05-08):
- ターゲット拡大: **完全な非エンジニアでも使えるシンプルさが欲しい**
- 用語マッピングの優先度: **全部やる**

現状の UI 文言は技術用語 (KeyFact / entity / Category / Auto-Tag / Digest) が混在し、エンジニア以外に不親切。

## ゴール

- 全 UI 文言を **やさしい日本語** に統一
- xcstrings 全 review、ハードコード文字列も対応
- DESIGN.md に **用語ガイドライン** セクション追加
- コード上の internal 名 (`KeyFact` 型名等) は **そのまま維持** (UI 文言のみ対応)

## 非ゴール

- コード型名 / クラス名のリネーム (例: `KeyFact` → `Fact`) → リスク高、ユーザーには見えない
- 多言語対応 (en_US 等) → 別 spec、本 spec は日本語のみ
- アイコン / illustration の追加 → UI 大改修、別 spec
- 用語の help / glossary 画面新規作成 → 必要なら spec 化、本 spec は文言置換のみ

## 用語マッピング表 (確定)

| カテゴリ | 現状 | 改善後 | 理由 |
|---|---|---|---|
| 知識 | KeyFact / ファクト | **事実** or **ポイント** | 「ファクト」は外来語、「事実」「ポイント」が直感的 |
| 知識 | entity | **人物・場所・モノ** | 「entity」「エンティティ」は技術用語、概念を直接説明 |
| 知識 | Category | **分野** or **ジャンル** | 「カテゴリ」は OK だが「分野」がより自然 |
| 知識 | Tag | タグ (そのまま) | 一般的に認知済 |
| 知識 | essence | 要点 (そのまま) | 既に和訳済 |
| 機能 | Knowledge Digest | **この分野のまとめ** | 「ダイジェスト」は外来語 |
| 機能 | Auto-Tag | **AI タグ** | 「自動」は固い、AI を全面に |
| 機能 | Auto-Category | **AI 分類** | 同上 |
| 機能 | Embedding (内部のみ、UI 表示なし) | (内部用語、UI 出さない) | 露出させない |
| 機能 | Foundation Models | **Apple Intelligence** or **AI** | Foundation Models は技術名、ユーザーには Apple Intelligence |
| 状態 | enrichment / fetching | **ページを取得中** | 専門用語回避 |
| 状態 | extraction / extracting | **AI 解析中** | extraction は技術用語 |
| 状態 | succeeded / partiallySucceeded / failed | **完了** / **一部完了** / **失敗** | (現状日本語、確認のみ) |
| AI | retrieval (Chat) | (内部用語、UI 出さない) | 露出させない |

## ユーザストーリー

### US1 (P1) — 全 UI が日本語の自然文

1. アプリ全画面 (5 タブ + Settings + Detail) を navigate
2. 「KeyFact」「Entity」「Category」等の技術用語が **どこにも出ない**
3. 「事実」「人物・場所・モノ」「分野」「AI タグ」等の自然文に統一

### US2 (P2) — VoiceOver でも自然

1. VoiceOver で読み上げ
2. 技術用語ではなく、人間が話すような日本語

## 機能要件

### xcstrings 全 review

- **FR-001**: `KnowledgeTree/Localization/Localizable.xcstrings` の全 key を review
- **FR-002**: 用語マッピング表に基づき value を更新
- **FR-003**: 既存 key 名は維持 (e.g., `aibrain.stats.facts` の value だけ「ファクト」→「事実」に)
- **FR-004**: 新規 key 追加なし (既存 value 修正のみ)、参照箇所も触らない

### View 内のハードコード対応

- **FR-005**: ハードコード文字列 (例: `Text("ファクト")`) を grep して全件 xcstrings 経由に
  - 現状で xcstrings 経由化を徹底済の view は対象外
- **FR-006**: ハードコードがあった場合は xcstrings に key 追加 (横断 grep で発見次第)

### DESIGN.md 更新

- **FR-007**: `DESIGN.md` に新セクション「**Vocabulary (用語ガイド)**」を追加
- **FR-008**: 用語マッピング表をそのまま転記
- **FR-009**: 「コード上の型名は技術用語のまま、UI 文言のみ和訳」のルールを明記
- **FR-010**: 新規 view / 機能追加時の用語チェックリストを書く

### tests / lint

- **FR-011**: build 警告ゼロ
- **FR-012**: 既存テスト全回帰 PASS (UI 文言は test に影響しないが念のため確認)

## 成功基準

- SC-001: アプリ全画面で「KeyFact」「Entity」「Category (UI 表示)」「Auto-Tag」「Digest」が出てこない
- SC-002: 「事実」「人物・場所・モノ」「分野」「AI タグ」「この分野のまとめ」が定着
- SC-003: VoiceOver 読み上げで自然な日本語
- SC-004: DESIGN.md に Vocabulary セクション
- SC-005: xcstrings の key 名 / 参照は変わっていない (回帰なし)

## アサンプション

- xcstrings の value 変更は SwiftUI が auto-reload (再起動不要)
- 既存テストは UI 文言を expect していない (現状確認、もし依存していれば test 修正)
- iOS 標準コンポーネント (Form / List section header 等) は影響なし

## 想定実装規模

- 改修 1 ファイル:
  - `KnowledgeTree/Localization/Localizable.xcstrings` (~50-100 文言の value 修正)
- 改修 N view:
  - ハードコード文字列を xcstrings に移行 (grep ベースで実数推定)
  - 推定 5-10 view 改修
- 改修 1 ファイル:
  - `DESIGN.md` (Vocabulary セクション追加、~50 行)
- 合計 ~200-300 行 (大半は xcstrings 内文字列変更)、~5-7 タスク

## Constitution

- I (privacy): 該当なし
- II (MVP): 既存機能の文言改善のみ、新機能なし
- III (source 追跡): 該当なし
- IV (実現可能性): xcstrings は確立、影響範囲限定
- V (calm UX): やさしい用語で安心感向上
- VI (architecture): 既存構造維持、value のみ変更
- VII (日本語): まさに本 spec の核

## 状態

📝 specify+plan 完了 (2026-05-08)、`/speckit-tasks` + `/speckit-implement` は次セッションで。
