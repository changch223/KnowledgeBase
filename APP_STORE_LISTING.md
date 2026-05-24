# iKnow — App Store Listing Draft

## アプリ名 (CFBundleDisplayName)
**iKnow**

## サブタイトル (30 字以内、Japanese 場合は ~20 文字)
**あなた専用の AI が育てる第二の脳**

## キャッチフレーズ候補
1. 「読んだ知識を AI が自動で整理。必要な時だけ開けば最新の自分が見える。」
2. 「保存するほど、賢くなる。AI 家庭教師つきの知識ノート。」
3. 「Share Sheet で保存するだけ。あとは AI が概念ページにまとめてくれる。」

## 説明文 (App Store description、4000 字以内)

```
iKnow は、あなたが読んだ記事を AI が自動で整理し、必要なときに思い出せる「あなた専用の第二の脳」です。

■ こんな悩みはありませんか？
・あとで読もうと保存した記事が、結局読み返さないまま埋もれる
・同じトピックの情報を複数の記事で読んだけど、要点を統合して覚えていない
・気になった記事を保存しても、関連する以前の知識と結びつけられない

iKnow は、ただの記事ストックアプリではありません。AI が記事を「読んで」「分類して」「統合して」、あなたの理解を時間と共に深めるツールです。

■ 4 つの核機能

【1. Share Sheet でどこからでも保存】
Safari / Chrome / X / 他のアプリの共有メニューから「iKnow」を選ぶだけ。記事の本文と知識を端末内で自動抽出します。PDF にも対応。

【2. AI が概念ページを自動生成】
人物・モノ・概念ごとに「概念ページ」を AI が自動作成。複数記事を横断した最新の理解が常に手元にあります。新しい記事が増えると概念ページも自動更新されます。

【3. AI チャット (RAG)】
保存した記事の内容について AI に質問できます。AI は引用元の記事を必ず示し、根拠のない回答はしません。良い質問と答えは「保存された答え」として概念ページに紐付きます。

【4. 家庭教師モード (学習タブ)】
AI が「今あなたが深めるべき概念」を 5 つ surface。タップすると AI 家庭教師と対話を始め、「✓ わかった」で理解度が育っていきます。Karpathy「思考は外注できても、理解は外注できない」原則に基づく設計です。

■ プライバシー

・データは すべて あなたの端末内に保存
・外部サーバーへの送信ゼロ (利用解析もしない)
・AI 処理は Apple Intelligence (on-device) で完結
・Apple や OpenAI 等の外部 AI サーバーには一切送信しません

■ 静かな UX (calm UX)

・未読バッジ・ストリーク・push 通知 一切なし
・「読まなきゃ」というプレッシャーを与えない設計
・必要な時だけ開けば、最新の自分が見える

■ 動作環境

・iOS 26.0 以降
・Apple Intelligence 対応端末 (iPhone 15 Pro 以降 / M1 以降の iPad) で AI 機能を利用可能
・非対応端末でも記事保存・閲覧は可能

■ オープンソース

ソースコードは GitHub で公開しています:
https://github.com/changch223/KnowledgeTree
```

## キーワード (100 字以内、カンマ区切り)

```
読書,記事保存,知識管理,AI要約,概念ページ,RAG,メモ,後で読む,ナレッジベース,オフライン
```

## 年齢制限
**4+** (暴力 / 不適切表現 / 課金 一切なし)

## カテゴリー
**Primary**: Productivity (生産性)
**Secondary**: Reference (リファレンス)

## What's New (初回 1.0.0)
```
iKnow 初回リリース。

・Share Sheet からの記事保存 (PDF 対応)
・AI による概念ページの自動生成
・AI チャット (RAG) — 引用元付き
・家庭教師モード (学習タブ) — Karpathy「理解は外注できない」原則
・全データ on-device、外部送信ゼロ
```

## Privacy Nutrition Label (App Store Connect)

**Data Not Collected** — 一切のデータを収集しません。

すべて「No data collected」を選択。

## Support URL
https://github.com/changch223/KnowledgeTree/issues

## Marketing URL (optional)
https://github.com/changch223/KnowledgeTree

## Privacy Policy URL
https://github.com/changch223/KnowledgeTree/blob/main/PRIVACY.md

## Screenshots 撮影シナリオ (実機で 6 枚)

1. **学習タブ** — 5 カード並んだ状態 (「Apple Vision Pro」「Foundation Models」等)
2. **DeepDiveChat** — 家庭教師と対話中の画面、下部に ✓/🤔/✗ 3 ボタン
3. **知識 Clip タブ** — 概念ページカードが複数並んだ状態、「確認が必要な答え」セクションも見える
4. **ConceptPageDetail** — 「Apple」の概念ページ、AI 合成 summary + 関連記事 + 関連質問
5. **AI チャットタブ** — 質問と答え + 引用記事 + 関連概念 chips
6. **ライブラリタブ** — 記事一覧、長押しで削除メニュー

各画面で iPhone 6.7" (iPhone 15 Pro Max) + iPad 12.9" 必須、6.5" + 5.5" は optional。
