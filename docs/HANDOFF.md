# 引き継ぎドキュメント — 別環境の次セッション向け

> 作成: 2026-07-09。前環境 (Mac) のローカルメモリは移行されないため、進行状態と次タスクの設計知見をここに固定する。
> **2026-07-11 更新**: v1.1 多言語対応(4 言語)の実装が完了し、提出素材も作成済み。§1・§2 を更新。

---

## 1. 現在地

- **App Store v1.0 リリース済み** 🎉 — Knowledge Base(2026-07-09 時点で公開中)
- **v1.1(多言語対応)の実装が完了**(2026-07-11 時点、`main` ブランチ HEAD `7c572ce`、PR #66〜#70 マージ済み)。
  UI とAI が生成する知識(要約・概念ページ・チャット回答・カテゴリ)の両方が **日本語 / 简体中文(zh-Hans) /
  繁體中文(zh-Hant) / English** の 4 言語に対応した:
  - **PR #66 (zh Phase A)**: `PipelineLanguage` 基盤 + UI ローカライズ(`Localizable.xcstrings` に zh-Hans/zh-Hant 注入)
  - **PR #67 (zh Phase B)**: 生成言語のパイプライン化(翻訳先動的化・17 の prompt を言語パラメタライズ・
    embedding 言語追従・`CategorySeed` zh シード)
  - **PR #68 (Apple Intelligence 可用性ガイド)**: AI が使えない/使えなくなった時に全タブ共通バナー + 理由別
    ガイドシート(非対応端末 / 未有効化 / モデル準備中 / 不明)で気づかせる
  - **PR #69 (AI 復旧)**: AI が再び使えるようになった時、止まっていた要約・概念ページ・タグ付けの処理を
    自動で再開する(`AIRecoveryRunner`、`ConceptPage.synthesizedWithoutAI` で劣化ページを追跡・救済)
  - **PR #70 (en)**: `PipelineLanguage.en` 追加 + 英語シード + UI 英訳(744 キー)で 4 言語対応完成
  - 生成言語は**初回起動時の端末言語から自動決定**され、設定 > 生成言語 からいつでも変更できる(変更後は
    アプリの再起動が必要)。既存ユーザーは保存値優先ロックで回帰なし
- **v1.1 の App Store 提出素材も作成済み**(本セッション、2026-07-11、`appstore-v1.1-materials` ブランチ、未コミット):
  - `docs/app-store/RELEASE-MATERIALS.md` §1-J — zh-Hans / zh-Hant / en-US の App 名・サブタイトル・
    プロモーションテキスト・キーワード・説明文フル版・What's New、ja の What's New v1.1、審査メモ更新版
    (対応言語 4 つ・生成言語の仕組み・言語別テスト手順を明記)。文字数はすべて上限内で確認済み
  - `ScreenShot/appstore/build.py` — v3 多言語対応(`CAPTIONS` にロケール別キャプション、`ScreenShot/<locale>/`
    の実機画像を優先探索・無ければ ja 実機にフォールバック、出力を `<locale>/*.html` + `output/<locale>/*.png`
    に分離)。zh/en の実機スクショはまだ無いため、現状は ja 実機画像 + 各言語キャプションのプレビュー状態
  - **未実施**: 実機での 4 言語動作確認(UI・生成言語とも)、zh/en 実機スクショの撮影・差し替え、
    翻訳レビュー(xcstrings は needs_review 状態)、App Store Connect への提出
- v1.0 提出時の構成・メタデータ(§1-A〜§1-I、変更していない):
  - `docs/app-store/RELEASE-MATERIALS.md` — 名前「Knowledge Base：AI第二の脳」/ サブタイトル「iPhoneのAIが育てる、第二の脳」/ プロモ / キーワード / §1-I 審査メモ(iPhone 17 実機テスト済み・Apple Intelligence 要件)
  - `docs/app-store/SCREENSHOT-DESIGN.md` — スクショ設計 v2(和紙+墨+藍、端末ブリード、チップ)
- 配布設定: **iPhone + Vision のみ**(iPad 対象外 `TARGETED_DEVICE_FAMILY=1,7`、Mac Catalyst 無効)
- 直近のコード改善: LLM 処理 P1+P2(overflow 本番計測 / preflight スキーマ選択 / RRF ハイブリッド検索 / WikiBody 品質下限 / 段落チャンク)= `docs/LLM_BEST_PRACTICES.md` 参照。P3(PCC 32K / 真ストリーミング)は iOS 27 GA(~2026年9月)待ち

## 2. 次タスク: v1.1 提出(実機検証 → 翻訳レビュー → 提出)

多言語対応の実装とメタデータ作成は完了した。残りは検証と提出フローのみ。

### 2-1. 実機検証(優先度順)

1. **4 言語での UI・生成言語の動作確認**(PR #66〜#70 の実機検証項目、各 PR 本文にチェックリストあり):
   - 端末言語を 简体中文 / 繁體中文 / English に切り替えて起動 → UI がその言語になるか
   - 記事保存 → 要約・概念ページ・カテゴリ・チャット回答がその言語で生成されるか(ja・zh・en いずれも回帰なし)
   - 設定 > 生成言語 のピッカーが 4 択になっているか、変更 → 再起動バナー → 反映されるか
2. **Apple Intelligence 可用性ガイド**: 4 理由別(非対応端末 / 未有効化 / モデル準備中 / 不明)でバナーが出るか、
   バナー tap → 詳細ガイドシートの「設定 App を開く」が正しいペインに飛ぶか
3. **AI 復旧**: AI 不可 → 復活で「AI 復旧中」ステータスが出て、止まっていた処理が自動再開するか
4. 上記が PASS したら `docs/app-store/RELEASE-MATERIALS.md` の該当チェック欄を更新

### 2-2. 翻訳レビュー

- `KnowledgeBase/Localization/Localizable.xcstrings` の zh-Hans / zh-Hant / en は **needs_review 状態**
  (機械翻訳 + glossary 統一済みだが、ネイティブレビュー未実施)。Xcode の String Catalog エディタで開き、
  不自然な訳がないか確認する
- Widget catalog(`iKnowWidget/Localizable.xcstrings`)に Xcode 自動抽出の未翻訳ベアキーが数件残っている
  (実描画は `widget.label.*` 経由のため実害はないと判定済み、PR #67/#70 本文参照)。磨きラウンドで対応可

### 2-3. zh/en 実機スクショの撮影・差し替え

1. 端末言語 / 生成言語を対象ロケールに切り替えてデモデータ(記事 15〜20 本)を保存・AI 整理を完走
2. `SLIDE_LAYOUT` にある 5 画面(ナレッジフィード / Wiki 詳細 / AI チャット / 記事詳細 / ライブラリ)を撮影
3. `ScreenShot/<locale>/`(例: `ScreenShot/en/`)に ja と同じファイル名で配置
4. `cd ScreenShot/appstore && python3 build.py` で再生成 → ヘッドレス Chrome で PNG 化(`README.md` 参照)

### 2-4. App Store Connect への提出

1. App Store Connect でロケールを 4 つ追加(日本語 / 简体中文 / 繁體中文 / English)
2. `docs/app-store/RELEASE-MATERIALS.md` §1-J の各ロケールのメタデータ(名前・サブタイトル・プロモ・
   キーワード・説明文・What's New)をそのまま貼る
3. §1-J J-5 の審査メモ更新版を Notes 欄に貼る
4. 各ロケールのスクリーンショット(6.9″ / 6.5″)をアップロード
5. バージョンを v1.1 に上げて審査に提出

## 3. 開発環境セットアップ(別 PC)

```bash
git clone https://github.com/changch223/KnowledgeBase.git
cd KnowledgeBase
# Xcode 26+ で KnowledgeBase.xcodeproj を開く
# ビルド:  xcodebuild build -scheme KnowledgeBase -destination 'platform=iOS Simulator,name=iPhone 17'
# テスト:  xcodebuild test  -scheme KnowledgeBase -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:KnowledgeBaseTests
```

- scheme は `KnowledgeBase`(全 6 target 共有)。実機 AI 機能は Apple Intelligence 対応機(iPhone 15 Pro+)が必要
- リポジトリ規約・進行履歴の詳細は **`CLAUDE.md`**(spec 001〜095 の要約)と `.specify/memory/constitution.md`
- **マージ事故の教訓**: 連続 spec は前段が main にマージされてから main で新ブランチを切る(積み重ねブランチ禁止)

## 4. 恒常タスク(リリース後運用)

- 審査後の実機フィードバック・クラッシュレポートの監視(App Store Connect)
- What's New の更新は `RELEASE-MATERIALS.md` §1-G(v1.0)/ §1-J(v1.1 以降、4 言語分)を更新してから提出
- iOS 27 GA 後: LLM P3(Private Cloud Compute 32K / 真ストリーミング)を v1.x で検討(`docs/LLM_BEST_PRACTICES.md` §5 Priority 3)
