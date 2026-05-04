# Spec 005 Quickstart — 手動検証手順

## 前提

- spec 001-005 を込んだビルドがシミュレータ / 実機にインストール済
- App Group が provisioning profile に有効化されている
- Wi-Fi 環境 (オフラインケースは別途確認)

## US1: タップで詳細画面が開く

1. Safari で `https://www.kfc.co.jp/coupon/` を開き、共有 → KnowledgeTree → 投稿
2. アプリに戻る → 一覧に行が出ている
3. **すぐ** その行をタップ → ArticleDetailView (sheet) が即座に開く
4. 画面内に以下が見えるはず:
   - サムネ (まだ取れてないなら無し or プレースホルダ)
   - タイトル
   - 「AI が記事を解析中...」プレースホルダ
   - 「本文を取得中...」プレースホルダ
   - 「元記事を開く」ボタン
5. 「元記事を開く」を押す → SVC が起動して KFC の元 URL が開く
6. 「完了」を押す → sheet が閉じる
7. ❌ 一覧で行をタップしたときに SVC が直接開いてはいけない

## US2: 下部ステータスバーが見える

1. 連続して 3-5 件の Web 記事を共有保存
2. 一覧画面下部に半透明の `BottomStatusBar` が現れる
3. テキストが「メタデータ取得中」「本文抽出中」「知識抽出中」のいずれかに変わっていく
4. 並列で複数走っているとき `+N` バッジが見える
5. 全処理完了後、`BottomStatusBar` が滑らかにフェードアウトする (isIdle 時非表示)

## US3: Shift-JIS の文字化けが解消

1. Safari で `https://atmarkit.itmedia.co.jp/ait/spv/2604/27/news012.html` を開く
2. 共有 → KnowledgeTree → 投稿
3. アプリに戻る → 一覧に行が出る (この時点では Share-time の title)
4. 数秒待つ (enrichment 完了まで)
5. ✓ 行に表示される追加情報 (summary) が日本語として読める
6. 行をタップして ArticleDetailView を開く
7. ✓ サムネが取得できれば表示される
8. ✓ canonicalTitle / summary が日本語で表示される
9. ❌ `ã€...` のような ASCII 化けの羅列が見えてはいけない

## US4: タイトルが上書きされない

1. KFC のクーポンページを共有保存 (Share-time のタイトルは「クーポン...」のような長い文字列)
2. アプリ完全終了 (App Switcher で swipe up)
3. アプリを再起動
4. 一覧の KFC 行のタイトルを確認
5. ✓ Share-time のタイトルが維持されている
6. ❌ 「KFC」だけに短縮されてはいけない

## エッジケース確認

### EC-1: knowledge が skipped

1. iPhone Settings → Apple Intelligence をオフ
2. 記事を共有保存
3. ArticleDetailView を開く
4. 知識サマリ欄に「Apple Intelligence が利用できないためスキップしました」と出る

### EC-2: body 抽出失敗

1. JS 多用の SPA サイト (例: 動画専用サイト) を保存
2. body 抽出が失敗
3. ArticleDetailView の本文欄に「本文を抽出できませんでした。元記事を開いてください。」と出る
4. 「元記事を開く」を押すと SVC で開ける

### EC-3: 機内モード

1. 機内モード ON
2. 記事を共有保存 → 一覧に行は出る
3. BottomStatusBar に「メタデータ取得中」が見える
4. ArticleDetailView を開いて確認 → プレースホルダのみ
5. 機内モード OFF → 自動で enrichment が再開、BottomStatusBar が動き出す
6. 完了したら自動で詳細画面の中身も差し替わる (画面を開きっぱなしでも更新される)
