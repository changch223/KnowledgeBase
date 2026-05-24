# spec 058+ Paper Plans — V3.0 後の方向性メモ

**Created**: 2026-05-24
**Status**: Paper plans (specify 未実施、方向性メモ)
**Context**: V3.0 (spec 056 + 057) 完成後の次の 3-6 ヶ月の候補 spec を整理。

---

## V3.0 で達成したこと (基準点)

```
✅ V2.5 spec 051 CloudKit sync (merge 済 main)
✅ V3.0 spec 056 UIUX redesign (3 タブ + 知識 Clip 3 section + Library 日付 grouping)
✅ V3.0 spec 057 Agentic Chat (LLM が考えて聞いて調べて答える、max 3 round)
   - 「分かりません」廃止
   - clarification chips
   - long press menu (保存/コピー/共有)
   - on-device Foundation Models 維持
```

「気になったものが、勝手に整理される」 + 「ChatGPT 的な何でも答える」体験が両立。

---

## 次の候補 spec (優先度順)

### Tier 1: V3.0 release 後の小さい改善 (各 1-3 日)

#### **spec 058: 「分かりません」filter 強化 + 高度な hedge 学習**
- 現状: 8 phrase の hard-coded banned set
- 拡張: ユーザーが「これ分からなくていい (＝ hedge 不要)」と feedback する機能
- 「私の理解では」「一般的には」を文脈に応じて使い分ける improvement
- ~200 行、1-2 日

#### **spec 059: clarification chip スタイル改善 + 履歴 chip**
- 現状: 3 chip 縦並び、tap で auto-fill
- 拡張: 「最近こう聞かれた」履歴を chip として提示 (cache)、よく使うパターンの suggestion
- ~150 行、1-2 日

#### **spec 060: 長押し menu 拡張 (引用元へ jump / 別 session で続き)**
- 現状: 保存 / コピー / 共有 の 3 アクション
- 拡張: 「引用元の記事を開く」(citedArticleIDs が複数なら sheet で選択)、「この答えを起点に新 session」
- ~100 行、1 日

#### **spec 061: AI Chat 検索機能** (session 内検索 + 全 session 横断検索)
- 現状: session sidebar のみ
- 拡張: 「過去のチャットから keyword 検索」「特定 ConceptPage 言及した chat だけ」
- ~250 行、3 日

---

### Tier 2: 中規模、3-7 日

#### **spec 062: Web 検索 tool** (agent loop 拡張)
- 現状: agent action は immediate / askClarification / searchArticles / finalAnswer の 4 つ
- 拡張: `.searchWeb(query)` を追加、保存記事に無い情報を Apple Search Foundation / SafariViewController 経由で取得
- 「Privacy first」原則と整合性確認必要 (Apple の APIs のみ、外部 API 不使用前提)
- ~500 行、3-5 日

#### **spec 063: 真 Streaming API 統合** (擬似 streaming 置換)
- 現状: spec 033 で擬似 streaming (15ms/文字)
- 拡張: iOS 26 で Apple Intelligence streaming API (`session.streamResponse`) が安定したら置換
- ~200 行、2-3 日
- 待ち時間 + API release 状況依存

#### **spec 064: AI Chat 答えの品質評価 + 自動改善**
- 現状: ユーザーが ★ 保存するだけ
- 拡張: 「👍 / 👎」feedback で agent loop の prompt を A/B test、品質向上に活用
- 永続化: AgentFeedback @Model (action / outcome / userRating)
- ~400 行、5 日

#### **spec 065: 知識 Clip タブの Memories 機能**
- 現状: 「最近の記事」セクションのみ
- 拡張: Apple Photos For You 風「1 年前のあなた」「先月のまとめ」セクション (差分ゼロ時のみ表示)
- ~200 行、3 日

---

### Tier 3: 大規模、1-2 週間

#### **spec 066: iPad UI 専用最適化**
- 現状: NavigationSplitView は使用済だが iPhone 中心 layout
- 拡張: iPad で sidebar + detail + inspector の 3 column layout、Drag & Drop で article 整理
- ~800-1000 行、1-2 週間

#### **spec 067: Apple Sign In** (旧 spec 053)
- 現状: anonymous CloudKit private DB
- 拡張: Apple ID 連携で「アカウント」概念導入、複数端末跨ぎ統一識別
- 既存 spec 053 paper plan あり、再活用可能
- ~600 行、1 週間

#### **spec 068: 多言語対応** (英語 UI、現状日本語のみ)
- 現状: Localizable.xcstrings は ja のみ
- 拡張: en / zh-Hans / es 等の翻訳追加、locale 切替対応
- ~翻訳作業中心 ~500 文言、UI 改修最小
- 1-2 週間

#### **spec 069: 公開 sharing (CloudKit public DB)**
- 現状: private DB のみ
- 拡張: 特定 ConceptPage を公開リンクで共有 (read-only)
- privacy implication 大、慎重 design 必要
- ~1000 行、2 週間

---

### Tier 4: 永久 non-goal (Constitution V calm UX)

- ❌ Streak / バッジ / 連続学習日数表示
- ❌ Push 通知 (リマインダー / 知らせ)
- ❌ ChatGPT/Gemini API 統合 (Privacy first 違反、Q5 で永久 non-goal 確定)
- ❌ Vision / Audio / File 添付 multimodal (現状 use case で必要なし)

---

## ROADMAP 推奨順序 (V3.0 release 後)

### Phase X (V3.0 release → 1 ヶ月)
- V3.0 release 後の **ユーザーフィードバック収集**
- 緊急 bug fix のみ
- spec 058-060 の中から 1-2 個を選んで polish patch (V3.0.1)

### Phase Y (1-3 ヶ月)
- spec 061 (AI Chat 検索) or spec 064 (品質評価) を MVP として 1 つ
- spec 062 (Web 検索) は Apple の APIs 状況見て判断

### Phase Z (3-6 ヶ月)
- spec 066 (iPad UI) or spec 068 (多言語) のどちらかで V4.0 を目指す
- spec 067 (Apple Sign In) は CloudKit 運用データで判断 (anonymous で十分なら delay)

---

## 注意 (V3.0 release 直後)

- V3.0 = 大規模 UI 変更 + agent loop 変更 = ユーザー混乱の可能性
- 1-2 週間は新機能追加せず、**ユーザー反応を見る期間** にする
- 「タブ減って良くなった」「ChatGPT みたいになった」ポジ反応 → spec 058+ 着手
- 「前の方が良かった」「分かりにくくなった」ネガ反応 → V3.0.1 で部分 revert 検討

---

## 関連 docs

- VISION.md (プロダクトビジョン確定版)
- ROADMAP.md (詳細実行計画、本 paper plan で update 予定)
- spec 056-uiux-redesign-v3 / spec 057-agentic-chat (V3.0 実装の詳細)
- CLAUDE.md (実装済 spec のステータスサマリ)
