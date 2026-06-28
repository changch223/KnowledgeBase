# あなたがやること（出荷までの人手タスク）

コード側の準備は完了しています。ここに残るのは **人間（あなた）にしかできない作業** だけ。
上から順に進めれば App Store 提出まで行けます。

> 凡例: ⏱️ 目安時間 / 🔗 参照ドキュメント

---

## ✅ こちら（コード側）で完了済み

- バージョン `1.0` / ビルド `1` 設定
- 暗号輸出申告 `ITSAppUsesNonExemptEncryption = false`
- Privacy Manifest（`PrivacyInfo.xcprivacy`、データ収集なし）
- アプリ名 `Knowledge Base`、最小 iOS 26.4
- 死蔵コード削除・退役モデルの整理メモ（公開リポジトリの体裁）
- 掲載文・チェックリスト・スモークテスト・note記事 一式
- [x] GitHub URL を `KnowledgeTree → KnowledgeBase` に一括更新
- [x] `CategoryLearning.store` CloudKit 競合エラー修正（毎起動の `Code=134060` ノイズ解消）
- [x] DEBUG ビルドの `EXC_BREAKPOINT` (assertionFailure) 削除

---

## 0. PR #56 をマージ（先にやること）⏱️ 1分

上記バグ修正 + URL 更新がすべて PR #56 に入っています。  
**先に main にマージしてから、以降のステップへ進んでください。**

---

## 1. 実機スモークテスト ⏱️ 60〜90分 🔗 `docs/release-smoke-test.md`

- [ ] クリーンインストールした実機（Apple Intelligence 対応機）で **P0 を全部通す**
- [ ] **特に確認**: 本文訂正（詳細画面の「訂正」ボタン）/ 音声文字起こし / 英語記事の日本語化
- [ ] 不具合が出たら Xcode ログ（操作手順付き）を添えて連絡。P0 であればここで止める

## 2. スクリーンショット作成 ⏱️ 60〜120分

- [ ] **記事を20〜30件保存して"育った状態"**を作ってから撮影
- [ ] 必須サイズ: **6.9"**（iPhone 16 Pro Max 等）と **6.5"** 系、各 3〜5 枚
- [ ] 推奨5画面: ①iKnow フィード（概念まとめ）②取り込み（＋ボタン各モード）③概念ページ（要点+出典）④AIチャット（番号引用）⑤本文訂正 or 整理設定
- [ ] note 記事用の画像もここで一緒に撮ると効率的

## 3. App Store Connect 入力 ⏱️ 60分 🔗 `docs/app-store-listing.md`

- [ ] App 作成（名前 `Knowledge Base` / SKU / Bundle ID `app.KnowledgeTree`）
- [ ] 概要・キーワード・プロモーションテキストを `app-store-listing.md` から貼り付け
- [ ] カテゴリ: プライマリ=**Productivity** / セカンダリ=**Reference**
- [ ] URL 設定:
  - サポート: `https://github.com/changch223/KnowledgeBase/blob/main/docs/support.md`
  - プライバシー: `https://github.com/changch223/KnowledgeBase/blob/main/docs/privacy-policy.md`
- [ ] **Appのプライバシー**: 「**データを収集していません**」を選択
- [ ] **年齢評価アンケート**: 基本4+。Web 取得機能が「無制限 Web アクセス」扱いになると 17+ になり得る。アンケートの実回答に従う
- [ ] スクリーンショットをアップロード

## 4. アーカイブ & 検証 ⏱️ 30分

- [ ] Xcode → **Product → Archive**（Generic iOS Device）
- [ ] Organizer → **Validate App**（署名・証明書・provisioning のエラーがないこと）
- [ ] **Distribute App → App Store Connect** にアップロード
- [ ] 初回は Distribution 証明書 + App Store provisioning の作成が必要（自動署名でも可）

## 5. TestFlight（任意だが推奨）⏱️ 適宜

- [ ] アップロードしたビルドを TestFlight で実機に配布
- [ ] 保存 → 整理 → チャット → 本文訂正 の主要フローを最終確認

## 6. 提出 ⏱️ 15分

- [ ] App Store Connect でビルドを選択 → 審査に提出
- [ ] レビューメモに記載: 「中核 AI（要約・抽出・チャット・翻訳・文字起こし）は Apple Intelligence / Foundation Models / Speech フレームワークによる完全端末内動作。アカウント不要・サーバーなし・データは端末＋ユーザーの iCloud private DB のみ。」

---

## 任意（やると良いが必須でない）

- [ ] **GitHub Pages** でサポート/プライバシーをホスト（URL を `changch223.github.io/...` に変更）
- [ ] **note 公開**（`docs/app-intro-note.md` / `docs/dev-story-note.md`、画像差し込み後）
- [ ] ハードコード文言の xcstrings 化（英語直書きの掃除、必要なら依頼）

---

## 困ったら

- スモークテストで P0 不具合 → ログを添えて連絡（私が修正）
- 提出でリジェクト → リジェクト理由を貼ってもらえれば対応を一緒に考えます
