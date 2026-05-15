# Plan: 用語のやさしさ整理

**Spec**: [spec.md](./spec.md)

## Technical Context

- Localizable.xcstrings の value のみ変更 (key 名 / 参照は不変)
- 既存 view コード変更最小 (ハードコード発見時のみ移行)
- 規模: 中 (~200-300 行)、リスク低

## Architecture

```
[現状]
  view → Text("KeyFact") or Text("aibrain.stats.facts") → xcstrings: "ファクト"

[改善後]
  view → Text("aibrain.stats.facts") → xcstrings: "事実"
                                              ↑ value だけ修正
  ハードコード分は xcstrings に移行
```

## Implementation Outline

### Phase 1: 棚卸し (調査)
- T001 xcstrings 全 key を抽出 → 用語マッピング表と照合 → 修正候補リスト作成
- T002 ハードコード文字列を grep (`Text("[^a-z]"`) → 移行候補リスト

### Phase 2: xcstrings 修正
- T003 value 修正 (用語マッピング表の通り、~50-100 文言)
- T004 spell check / 文末統一 (「ます」「ません」確認)

### Phase 3: ハードコード移行
- T005 ハードコード Text を xcstrings 経由に書き換え (発見した分のみ)

### Phase 4: DESIGN.md
- T006 Vocabulary セクション追加 + コード型名はそのままルール明記

### Phase 5: 検証
- T007 build 警告ゼロ
- T008 既存テスト全回帰 PASS
- T009 アプリ全画面 navigate して用語チェック (実機 + Simulator)
- T010 CLAUDE.md / ROADMAP 更新

## 主要研究項目

1. **既存 key 名と新 value のマッピング精度**: 「KeyFact」を value で使う key が複数あるはず、すべて「事実」に統一できるか
2. **ハードコード文字列の数**: grep 結果次第で工数変動、過去 spec で xcstrings 徹底済なら少ない
3. **「Foundation Models」 → 「Apple Intelligence」**: ブランドガイドライン的に問題ないか
4. **VoiceOver 影響**: accessibility label と xcstrings value の整合
5. **iOS 標準 alert 等での用語**: confirmAction 等で標準ボタン文言の整合

## MVP 範囲外

- コード型名のリネーム (`KeyFact` 型 → `Fact` 型) → リスク高、別 spec で検討
- 多言語 (en_US 等) → 別 spec
- 画面ガイド / オンボーディング新設
- 用語の用法をチェックする lint rule
