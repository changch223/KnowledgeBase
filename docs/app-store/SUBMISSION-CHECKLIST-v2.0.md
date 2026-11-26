# App Store Connect 提出チェックリスト — v2.0

前提: 公開中は v1.0（日本語のみ、2026-07-09）。v1.1 は提出しておらず、その内容をすべて含めて **2.0** として出す。
文言はすべて `docs/app-store/APP-STORE-METADATA-v2.0.md` からコピーする。上から順にやれば終わる。

---

## 1. ビルド（Xcode）

- [ ] main を最新にする（`git switch main && git pull`）
- [ ] `KnowledgeBase` ターゲット → General で **Version `2.0` / Build `4`** を確認（pbxproj 設定済み。全 target 同値）
- [ ] 実行先を **Any iOS Device (arm64)** にして **Product → Archive**
- [ ] Organizer → **Distribute App → App Store Connect → Upload**
- [ ] App Store Connect の TestFlight にビルド 4 が出るまで待つ（数分〜数十分）
- [ ] （推奨）TestFlight で実機に入れて、英語・繁體中文の生成言語で 1 記事保存 → トピック・AI 回答がその言語で出るか確認

## 2. 新しいバージョンを作る

- [ ] App Store Connect → アプリ → **「＋」→ iOS → バージョン `2.0`**
- [ ] 「ビルド」欄で **ビルド 4** を選ぶ

## 3. ローカリゼーション（7 つ）

v1.0 は日本語だけなので、「App 情報」→ ローカリゼーションで次を追加する（v1.1 で予定していた分）:
简体中文 / 繁體中文 / English (U.S.) / 한국어 / Español (España または México) / Deutsch

各ロケールで、メタデータ文書の該当セクションを各欄に貼る:

| App Store Connect の欄 | 文書の見出し |
|---|---|
| 名前（App 情報タブ） | 1. 名前 |
| サブタイトル（App 情報タブ） | 2. サブタイトル |
| プロモーション用テキスト | 3. プロモーションテキスト |
| 概要 | 4. 概要 |
| このバージョンの最新情報 | 5. このバージョンの最新情報 |
| キーワード | 6. キーワード |
| サポート URL / マーケティング URL | 共通表 |

共通（全ロケール同じ）: 著作権 `© 2026 Chia-Wei Chang`、プライバシーポリシー URL（App 情報タブ）、ユーザプライバシー選択 URL は空欄。

> 注意: サポート URL・プライバシーポリシー URL は GitHub の main の Markdown を指している。
> v2.0 向けに更新した `docs/support.md` / `docs/privacy-policy.md` は、**この PR を main にマージした時点で反映**される。

## 4. スクリーンショット

生成物: `ScreenShot/appstore/output/<locale>/`（5 枚 × 4 サイズ）

| App Store Connect のスロット | 使うファイル | サイズ |
|---|---|---|
| iPhone 6.9 インチ | `01-knowledge.png` … `05-library.png` | 1320 × 2868 |
| iPhone 6.5 インチ | `*-65.png` | 1242 × 2688 |
| iPhone 6.3 インチ | `*-63.png` | 1206 × 2622 |
| iPhone 6.1 インチ | `*-61.png` | 1179 × 2556 |

- 6.9″ を入れれば小さいサイズは自動縮小で流用されるので、**最低限は 6.9″ の 5 枚**。6.3″ スロットを個別に指定したい場合は `-63` を使う。
- ロケールごとに `output/<locale>/` のものを、そのロケールのページにドラッグ＆ドロップ（順番は 01→05）。
- App プレビュー（動画 1920×886 / 886×1920）は任意。今回は用意していない（無くても審査は通る）。

作り直す場合:
```bash
./ScreenShot/capture.sh                       # シミュレータでデモデータを表示して 35 枚撮影 (DEBUG ビルド)
cd ScreenShot/appstore && python3 build.py && ./render.sh   # 枠・見出しを合成して PNG 化
```

## 5. App のプライバシー / 審査情報

- [ ] 「App のプライバシー」は **データを収集していません** のまま（変更なし）
- [ ] 年齢制限は v1.0 と同じ（変更なし）
- [ ] 暗号化: 申告不要（Info.plist に `ITSAppUsesNonExemptEncryption = false`）
- [ ] サインイン情報: 不要（アカウント機能なし）
- [ ] 審査メモ（App Review Information → メモ）に下を貼る:

```
This app requires Apple Intelligence for its AI features (topic generation, answering questions, summaries, translation, auto-tagging). Please review on an iPhone that supports Apple Intelligence, with Apple Intelligence turned on. All AI processing runs on-device; no account or server is involved.

How to try it:
1. In Safari, open any news or blog article, tap Share, and choose the app (or tap + in the app and paste a URL).
2. Wait about a minute while the app organizes the article in the background.
3. Open the Knowledge tab to see topics with key points. Open the Search tab and ask a question about the article to get an answer with numbered citations.

Without Apple Intelligence, the app still saves, searches, and displays articles, and shows a banner explaining why AI is unavailable.

本アプリの AI 機能には Apple Intelligence が必要です。対応 iPhone で Apple Intelligence を ON にしてご確認ください。AI 処理はすべて端末内で行われ、アカウントやサーバーは使いません。
```

## 6. 提出

- [ ] リリース方法を選ぶ（審査通過後に手動リリース / 自動リリース）
- [ ] **審査に提出**
