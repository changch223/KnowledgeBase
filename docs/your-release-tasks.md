# あなたがやること（出荷までの人手タスク）

コード側の準備は概ね完了しています。ここに残るのは **人間（あなた）にしかできない作業** だけ。
上から順に進めれば App Store 提出まで行けます。関連する詳細は各ドキュメントへリンクしています。

> 凡例: ⏱️ 目安時間 / 🔗 参照ドキュメント

---

## ✅ こちら（コード側）で完了済み
- バージョン `1.0` / ビルド `1` 設定
- 暗号輸出申告 `ITSAppUsesNonExemptEncryption = false`
- Privacy Manifest（`PrivacyInfo.xcprivacy`、データ収集なし）
- アプリ名 `Knowledge Base`、最小 iOS 26.4
- 死蔵コード削除・退役モデルの整理メモ（公開リポジトリの体裁）
- 掲載文・チェックリスト・スモークテスト・note記事 一式

---

## 1. 実機スモークテスト ⏱️ 60〜90分 🔗 `docs/release-smoke-test.md`
- [ ] クリーンインストールした実機で、**P0 を全部通す**（落ちない・コア体験が動く）
- [ ] 今セッションの修正点（学習 local-only / 翻訳 override / overflow なし / ポップアップ）を確認
- [ ] 出た不具合はメモ（ログ＋操作手順）。P0 不具合があれば、ここで一旦止めて連絡を

## 2. スクリーンショット作成 ⏱️ 60〜120分 🔗 `docs/app-intro-note.md` の撮影チェックリスト
- [ ] **記事を20〜30件保存して“育った状態”**を作る
- [ ] 6.9"（iPhone 16 Pro Max 等）と 6.5" 系で、各3〜5枚
- [ ] 撮る画面: ①ナレッジ ②取り込み ③概念ページ ④AIチャット(出典) ⑤プライバシー（チェックリストの①〜⑦が流用できる）
- [ ] note記事用の画像もここで一緒に撮ると効率的

## 3. App Store Connect 入力 ⏱️ 60分 🔗 `docs/app-store-listing.md`
- [ ] App 作成（名前 `Knowledge Base` / SKU / Bundle ID）
- [ ] 概要・キーワード・プロモーションテキストを貼り付け（listing.md から）
- [ ] カテゴリ: プライマリ=Productivity / セカンダリ=Reference
- [ ] サポートURL / プライバシーポリシーURL を設定
      - 現状: `https://github.com/changch223/<repo>/blob/main/docs/support.md` 等
      - ⚠️ リポジトリ名が `KnowledgeTree` → `KnowledgeBase` に変わっている場合はURLを合わせる
- [ ] **Appのプライバシー**: 「**データを収集していません**」を選択
- [ ] **年齢評価アンケート**: 基本4+。「任意のWebページ取得・表示」が無制限Webアクセス判定だと17+になり得る → アンケートの実回答に従う
- [ ] スクリーンショットをアップロード

## 4. アーカイブ & 検証 ⏱️ 30分
- [ ] Xcode で実機/Generic iOS Device 向けに **Product → Archive**
- [ ] Organizer で **Validate App**（署名・証明書・provisioning のエラーがないこと）
- [ ] **Distribute App → App Store Connect** にアップロード
- [ ] （初回は署名証明書・App Store provisioning の作成が必要。自動署名でも可）

## 5. TestFlight（任意だが推奨）⏱️ 適宜
- [ ] アップロードしたビルドを TestFlight で自分の端末に配布
- [ ] 主要フロー（保存→整理→チャット→見直し）を最終確認

## 6. 提出 ⏱️ 15分
- [ ] App Store Connect でビルドを選択 → 審査に提出
- [ ] レビューメモに「中核AIは端末内動作・アカウント不要・サーバーなし」を明記（listing.md / checklist.md 参照）

---

## 任意（やると良いが必須でない）
- [ ] リポジトリ名変更に伴う **README 内リンクの `KnowledgeTree → KnowledgeBase` 一括更新**（私に頼めば対応）
- [ ] **GitHub Pages** でサポート/プライバシーをホスト（URL を `changch223.github.io/...` に）
- [ ] **note 公開**（`docs/app-intro-note.md` / `docs/dev-story-note.md`、画像差し込み後）
- [ ] ハードコード文言の xcstrings 化（残っている英語直書きの掃除。私に頼めば対応）

---

## 困ったら
- スモークテストで P0 不具合 → ログを添えて連絡（私が修正）
- 提出でリジェクト → リジェクト理由を貼ってもらえれば対応を一緒に考えます
