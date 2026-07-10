# 引き継ぎドキュメント — 別環境の次セッション向け

> 作成: 2026-07-09。前環境 (Mac) のローカルメモリは移行されないため、進行状態と次タスクの設計知見をここに固定する。

---

## 1. 現在地

- **App Store リリース済み** 🎉 — Knowledge Base v1.0(2026-07-09 時点で公開中)
- 提出時の構成・メタデータは main に記録済み:
  - `docs/app-store/RELEASE-MATERIALS.md` — 名前「Knowledge Base：AI第二の脳」/ サブタイトル「iPhoneのAIが育てる、第二の脳」/ プロモ / キーワード / §1-I 審査メモ(iPhone 17 実機テスト済み・Apple Intelligence 要件)
  - `docs/app-store/SCREENSHOT-DESIGN.md` — スクショ設計 v2(和紙+墨+藍、端末ブリード、チップ)
  - `ScreenShot/appstore/build.py` — スクショ自動生成ツール(6.9″ 1320×2868 / 6.5″ 1242×2688 両対応。実機スクショ PNG は git 管理外なので別 PC には無い。再生成には実機スクショを `ScreenShot/` に置く)
- 配布設定: **iPhone + Vision のみ**(iPad 対象外 `TARGETED_DEVICE_FAMILY=1,7`、Mac Catalyst 無効)
- 直近のコード改善: LLM 処理 P1+P2(overflow 本番計測 / preflight スキーマ選択 / RRF ハイブリッド検索 / WikiBody 品質下限 / 段落チャンク)= `docs/LLM_BEST_PRACTICES.md` 参照。P3(PCC 32K / 真ストリーミング)は iOS 27 GA(~2026年9月)待ち

## 2. 次タスク: 多言語対応(英語 → 中国語の順)

### 2-1. 調査済みの現状(2026-07-09 実測)

| 項目 | 現状 |
|---|---|
| `KnowledgeBase/Localization/Localizable.xcstrings` | **sourceLanguage = ja、702 キー、ja のみ**(en/zh なし) |
| pbxproj `knownRegions` | `en, Base` のみ |
| Views 内のハードコード日本語 `Text("…")` | **52 件残存**(AIBrainStatsRow / AIInsightCard / GraphNode 系など — 死蔵 view が多い可能性。キー化 or view 削除の監査が必要) |
| Usage description | `INFOPLIST_KEY_NSSpeechRecognitionUsageDescription` が **pbxproj に日本語直書き 2 箇所**。InfoPlist.xcstrings は存在しない → 新設が必要 |
| AI パイプライン | **日本語固定**: プロンプト「日本語で」直書き(ChatService / KnowledgeExtractor / LanguageModelSessionProtocol / LintEngine)+ @Guide 全部日本語 + `NLEmbedding.sentenceEmbedding(for: .japanese)` + spec 042/093 で外国語コンテンツを入口で日本語へ翻訳 |
| App Store 英語メタデータ | `RELEASE-MATERIALS.md` §1-H に下書きあり(Subtitle / Promo / Description 要約版) |

### 2-2. 最重要の設計判断(スペック作成時に最初に決める)

**「知識レイヤーの言語」をどうするか。** UI 翻訳(xcstrings)だけでは商品にならない — 英語ユーザーの要約・概念ページ・チャット回答が日本語で生成されてしまうため。

推奨アーキテクチャ = **「パイプライン言語 = アプリ言語」(ユーザーごとに固定)**:
- 入口翻訳(spec 042/093)の**翻訳先**を `ja` 固定 → アプリ言語に動的化
- プロンプト内「日本語で」→ 言語パラメタライズ(`PipelineLanguage` 的な enum を DI)
- `NLEmbedding.sentenceEmbedding(for:)` も言語追従(en は .english)。**言語が違う embedding は互いに比較不能**なので、既存 ja データと混在させない設計が必要(新規ユーザーは最初からその言語 / 既存ユーザーは ja のまま = 移行不要)
- CloudKit schema への影響ゼロ(言語はデータの中身の話)
- 段階案: **Phase 1 = UI 英語化のみ**(xcstrings en + ハードコード掃除 + InfoPlist.xcstrings)→ **Phase 2 = パイプライン言語化(en)** → **Phase 3 = zh-Hans 追加**(Phase 2 の仕組みに乗せるだけ)

### 2-3. Phase 1(英語 UI)の作業リスト目安

1. ハードコード日本語 52 件の監査(死蔵 view は削除、生きてる view はキー化)
2. `Localizable.xcstrings` に `en` localization 追加(702 キー。機械翻訳→レビューで OK、UI 崩れ注意: 英語は日本語より長くなりがち)
3. `InfoPlist.xcstrings` 新設(SpeechRecognition usage description ほか)+ pbxproj 直書きを移行
4. App 表示名の言語別対応(CFBundleDisplayName — en では "Knowledge Base" のままで良い)
5. Widget / ShareExtension / SafariExtension の文言も確認(各 target の Info.plist)
6. App Store Connect: en-US ロケール追加(§1-H の下書きを完成させる)+ 英語版スクショ(`build.py` の SLIDES を英語キャプションに差し替えて再生成)
7. 全 unit テスト回帰(テストは文言キー非依存のはずだが要確認)

### 2-4. 中国語(Phase 3)の追加メモ

- zh-Hans(簡体字)から。xcstrings に追加するだけの構造にしておく
- 音声認識(spec 093)は既に zh 検知対応済み。翻訳も `TranslationSession` が zh→ja 対応済 → パイプライン言語化ができていれば zh→zh も同じ仕組み
- 中華圏 App Store 展開はプライバシー説明の中国語化も必要

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
- What's New の更新は `RELEASE-MATERIALS.md` §1-G を更新してから提出
- iOS 27 GA 後: LLM P3(Private Cloud Compute 32K / 真ストリーミング)を v1.x で検討(`docs/LLM_BEST_PRACTICES.md` §5 Priority 3)
