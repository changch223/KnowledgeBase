# 07 — Risk Register

## Status: Skeleton (Phase 4 で詳細化予定)

## このファイルの目的

iKnow 移行で予想されるリスクを列挙し、各リスクに mitigation を割り当てる。

---

## リスク一覧 (8 個、重要度順)

### R1: spec 049 (Understanding Chat) の遅延 ★ 最大

- **重要度**: 🔴 高
- **発生確率**: 高 (4 週見込み、新規 UX、未知パターン多)
- **影響**: V1 全体が遅延、リリーススケジュール狂う
- **mitigation**:
  - 早期に Phase A 完了後すぐ着手 (M2 で着手、M4 で完了目標)
  - 1.0 / 1.5 分割の余地を最後まで残す (もし大幅遅延なら 1.5 で投入)
  - 内部 dogfooding を spec 049 完了後すぐ開始、user feedback 収集

### R2: 既存ユーザー喪失リスク

- **重要度**: 🟡 中
- **発生確率**: 中
- **影響**: Re-engage failure、評価低下、レビュー悪化
- **mitigation**:
  - bundle ID 継承 (= App Store 評価累積継承)
  - データ完全保持 (lightweight migration)
  - Onboarding overlay で「進化」を ポジティブに伝える
  - リリース noteで「破壊的変更なし、追加が中心」明示
  - 既存タブを 1 つだけ削除 (AI ブレイン) なので影響限定

### R3: SwiftData migration 失敗

- **重要度**: 🟡 中
- **発生確率**: 低
- **影響**: 起動阻害、ユーザーデータ消失 (重大!)
- **mitigation**:
  - 全 migration を lightweight (Schema 追加 + optional field のみ)
  - 各 spec で migration test 必須
  - TestFlight ベータで実機 update テスト (既存知積から iKnow へ)
  - リリース前に複数デバイス + iOS バージョンで verify

### R4: Foundation Models 制約による機能未達

- **重要度**: 🟡 中
- **発生確率**: 中
- **影響**: ConceptPage synthesis / Community 命名 / Compound moment 等の品質不足
- **mitigation**:
  - 各 service で hallucination post-process (引用なし → 「分かりません」)
  - chunked + meta-summary パターン (spec 010 流用)
  - 失敗時の graceful fallback (silent degrade、Calm UX)
  - WWDC 26 で Foundation Models 強化があれば即活用

### R5: V1 ビッグバンの全体遅延

- **重要度**: 🟠 中-高
- **発生確率**: 中
- **影響**: 5 ヶ月 → 7-8 ヶ月になるリスク
- **mitigation**:
  - Phase A-D の各 milestone (M1-M8) で確実に検証
  - 大型 spec 049 が遅延する場合、1.5 分割で V1 リリースを早める選択肢
  - 並行作業 (spec 045 + 050 並行、spec 051 + 052 並行 等)

### R6: リブランディング (iKnow) 混乱

- **重要度**: 🟢 低-中
- **発生確率**: 低
- **影響**: 「アプリが変わった」混乱、user 離反
- **mitigation**:
  - Onboarding overlay で進化説明
  - リリース blog で背景説明
  - 既存ユーザーには push 通知 (任意) で 1 回案内
  - 名前変更だけで機能削除は最小限なので、影響限定的

### R7: 写真 / AI 会話入力 (spec 050) の OCR 精度

- **重要度**: 🟢 低
- **発生確率**: 中
- **影響**: 写真からの抽出失敗、user 体験低下
- **mitigation**:
  - Vision framework は安定 (Apple 標準)
  - OCR 失敗時は user が「テキスト編集」可 (任意 UI)
  - AI 会話構造判定が失敗 → 通常記事として扱う fallback

### R8: Apple Intelligence 自体の停止 / 不可

- **重要度**: 🔴 高 (確率は低だが影響大)
- **発生確率**: 低
- **影響**: アプリの core 機能停止
- **mitigation**:
  - availability check で graceful degrade (既存 知積 既に対応)
  - 抽出 / chat 不可時の UI (「Apple Intelligence を有効化してください」案内)
  - 既に保存済データの閲覧 / 検索は LLM 不要で動く

---

## リスク マトリクス (確率 × 影響)

```
          影響 →
          ↓
        低           中           高
発  低 |            |           |
生  ──┼────────────┼───────────┼───────────
確  中 | R7         | R5        | R1, R4
率  ──┼────────────┼───────────┼───────────
↓  高  |            |           |
       |            | R2, R3    | R8

(低/中/高 で 9 grid、現状リスクは中-高に集中)
```

→ **最優先対策: R1 (spec 049 遅延) + R8 (Apple Intelligence 停止)**

---

## モニタリング

- spec 045-054 の進捗を週次で確認 (Phase 0 完了後)
- 各 milestone (M1-M8) で実機検証 + user feedback
- 遅延 兆候があれば即 plan 修正 (V1.5 分割 等)

---

## 次のステップ

Phase 4 で詳細化:
- 各 risk の発生 trigger 早期検知
- mitigation の具体 plan
- 緊急時 escalation (例: M4 で spec 049 が 1 ヶ月遅延 → どうする)
