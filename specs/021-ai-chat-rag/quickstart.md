# Quickstart — AI Chat (RAG) 検証シナリオ

**spec**: 021 / **target**: 実機 (Apple Intelligence 端末) + Simulator (Fallback)

## 12 シナリオ

### SC-001 — 4 タブ目表示

1. アプリ起動
2. 下部 TabView に「AI チャット」(`bubble.left.and.bubble.right.fill`) が 4 番目に表示される
3. タップ → ChatTabView 起動

**期待**: 既存 3 タブ (ライブラリ / 知識 Clip / AI ブレイン) と並んで 4 タブ目が出現

### SC-002 — 初回 Empty state

1. 新規インストール直後 (記事 0、session 0)
2. AI チャットタブ → ContentUnavailableView (chat.empty.title)

### SC-003 — 質問 → 引用付き回答 (Apple Intelligence 端末)

1. 記事を 5 件以上保存 (Swift 6 関連を含む)
2. AI チャットタブで「Swift 6 で何が変わったの?」と質問
3. 5 秒以内に assistant message 表示
4. message に引用記事 DisclosureGroup (1 件以上)
5. 引用 DisclosureGroup 展開 → 該当記事の title

**期待**: SC-002 (5 秒以内回答)、SC-003 (引用 1 件以上)

### SC-004 — 引用タップで詳細

1. SC-003 後、引用記事の row をタップ
2. NavigationStack push で ArticleDetailView 起動

### SC-005 — 履歴永続化

1. 質問 + 回答後、アプリ強制終了
2. 再起動 → AI チャットタブ → 過去 message 復元

### SC-006 — ハルシネーション抑止

1. 「火星の重力は?」(保存記事に存在しない情報) と質問
2. 「分かりません。保存された記事の中に該当する情報が見つかりませんでした。」と回答
3. 引用 DisclosureGroup 非表示 (cited = 0)

### SC-007 — Fallback 端末

1. Apple Intelligence 不可端末 (Simulator default 等)
2. 質問 → 2 秒以内に「以下の記事が参考になります」+ KeyFact 並べ回答
3. 質問 latency > 5s ならフリーズと判定

### SC-008 — 50 セッション FIFO

1. 50 セッション作成 (テスト用 helper)
2. 51 番目を作成
3. 最古セッション削除、count = 50

### SC-009 — チャット履歴全削除

1. SettingsView →「チャット履歴を全削除」
2. 確認 alert →「削除する」
3. 全 ChatSession + ChatMessage 削除、AI チャットタブ Empty state

### SC-010 — 同時タブ操作

1. 質問送信中 (isThinking)
2. 別タブに切替 → 戻る
3. message 状態が保持される (回答完了済みなら表示)

### SC-011 — 引用記事削除追従

1. 質問 → 引用付き回答
2. ライブラリタブで引用元記事を swipe 削除 (spec 022)
3. AI チャットに戻る → DisclosureGroup の cited 数が減る (削除分を skip)

### SC-012 — 既存タブ回帰

1. ライブラリ / 知識 Clip / AI ブレイン全タブ動作確認
2. 既存 SC (spec 011-018) で破綻なし

## 完了条件

SC-001〜SC-009 全 PASS、SC-010〜SC-012 ベスト努力。

実機 (Apple Intelligence 対応端末) + Simulator (Fallback) の 2 経路で検証。
