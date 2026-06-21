# App Store 提出チェックリスト — Knowledge Base

提出前に上から順に確認する。掲載文（アプリ名/概要/キーワード等）は `docs/app-store-listing.md` を参照。

## 1. ビルド設定（コード側・確認済み ✅）
- [x] **アプリ名**: `CFBundleDisplayName = "Knowledge Base"`（pbxproj）
- [x] **暗号輸出申告**: `ITSAppUsesNonExemptEncryption = false`（`KnowledgeTree/Info.plist`）→ 毎回の手動回答が不要
- [x] **Privacy Manifest**: `KnowledgeTree/PrivacyInfo.xcprivacy` 同梱（NSPrivacyTracking=false / 収集データなし / Required Reason API = UserDefaults CA92.1）
- [x] **最小 OS**: iOS 26.4（`IPHONEOS_DEPLOYMENT_TARGET`）→ Apple Intelligence 対応端末が前提
- [ ] **バージョン / ビルド番号**: `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` を 1.0 / 1 に
- [ ] **署名**: Distribution 証明書 + App Store provisioning（自動署名でも可）
- [ ] **アプリアイコン**: 1024×1024 を含む全サイズが Assets に入っているか

## 2. App Store Connect（Web 側）
- [ ] **App 情報**: 名前 / サブタイトル / プライマリ=Productivity・セカンダリ=Reference（`app-store-listing.md`）
- [ ] **概要 / キーワード / プロモーションテキスト**: `app-store-listing.md` から貼り付け
- [ ] **サポート URL**: `https://github.com/changch223/KnowledgeTree/blob/main/docs/support.md`
- [ ] **プライバシーポリシー URL**: `https://github.com/changch223/KnowledgeTree/blob/main/docs/privacy-policy.md`
- [ ] **App のプライバシー（Nutrition Label）**: 「**データを収集していません**」を選択
      - 理由: 全データは端末内 + ユーザー自身の iCloud private DB のみ。開発者送信ゼロ・トラッキングなし。
- [ ] **年齢評価アンケート**: 基本 4+。ただし「ユーザー指定の任意 Web ページを取得・表示」が
      **無制限 Web アクセス**に該当すると判断されると 17+ になり得る。アンケートの実回答に従う。

## 3. スクリーンショット（必須サイズ）
最低でも **6.9"（iPhone 16 Pro Max 等）** と **6.5"** 系を用意。撮影案:
1. iKnow フィード（概念中心のまとめ + 新着 + おすすめ）
2. 概念ページ（要点 + 本文 + 出典）
3. AI チャット（番号付き出典で回答）
4. 取り込み（＋ボタンの URL/メモ/ファイル/写真/音声）
5. 本文の見直し / 生成内容のカスタマイズ
- [ ] 各サイズ 3〜5 枚、文字が読める解像度
- [ ] キャプション例: 「保存するだけ。AI が整理する。」「あなたの知識から、AI が答える。」

## 4. レビュー対策メモ（App Review Information）
- [ ] 中核機能（要約・抽出・チャット・翻訳）は **Apple Intelligence / Foundation Models で端末内動作**。
      非対応端末では AI 機能は無効化され、保存・閲覧・検索は継続利用可、と明記。
- [ ] **アカウント不要**（ログインなし）。サーバーなし、データは端末＋ユーザーの iCloud のみ。
- [ ] 音声の文字起こしは Speech フレームワーク（オンデバイス）使用。

## 5. 最終確認
- [ ] Archive → Validate（App Store Connect）でエラーなし
- [ ] TestFlight で実機 1 台に配布し主要フロー確認（保存→整理→チャット→見直し）
- [ ] 申請 → 審査

> 注: GitHub Pages を有効化する場合、Support/Privacy URL を `https://changch223.github.io/...` 形式に差し替え推奨。
