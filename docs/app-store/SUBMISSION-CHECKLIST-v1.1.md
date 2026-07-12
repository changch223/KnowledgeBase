# App Store Connect 提出チェックリスト — v1.1

作成日: 2026-07-11 / 対象: v1.1（7 言語対応 + Apple Intelligence 可用性ガイド + AI 復旧 + 言語ズレ検知バナー +
ja のみ「まとメモ」改名）/ 前提: v1.0 は 2026-07-09 に日本語のみで公開済み

このドキュメントは App Store Connect で v1.1 を提出するときに**上から順に実行**すれば終わる手順書。
文言そのものは書き写さず、必ず `docs/app-store/RELEASE-MATERIALS.md` の該当セクションからコピー＆ペーストする
（本チェックリストの表は「どのセクションを・どのフィールドに」対応させるかのマップと文字数の実測値のみ持つ）。

> 本チェックリスト作成にあたり `RELEASE-MATERIALS.md` の全フィールドを python3 の `len()` で再実測し、
> ドキュメント内の記載値と一致することを確認済み（差異ゼロ）。実測コマンドは本ファイル末尾の付録を参照。

---

## 1. バージョン設定

現状（本チェックリスト作成時点）: `KnowledgeBase.xcodeproj/project.pbxproj` は既に
**`MARKETING_VERSION = 1.1` / `CURRENT_PROJECT_VERSION = 2` に設定済み**（全 6 target × Debug/Release
の 12 箇所全てを更新済み、App / Widget / Share Extension / Safari Extension を含む）。Archive はこの
値をそのまま使うため、以下は **Xcode 上での確認のみ**でよい（値の変更作業は不要）。

- [ ] Xcode で `KnowledgeBase.xcodeproj` を開き、**KnowledgeBase ターゲット** → General タブ →
      **Version** が `1.1`、**Build** が `2` になっていることを確認する（変更は不要、pbxproj に
      設定済みの値がそのまま表示されるはず。App Store Connect は同一 Version 内で Build が重複すると
      アップロードを拒否するため、v1.0 で使った Build 番号 `1` と別の値 `2` になっていることが重要）。
- [ ] scheme は `KnowledgeBase`（`docs/HANDOFF.md` §3 参照、全 6 target 共有）。
- [ ] Xcode メニュー **Product → Archive** でアーカイブを作成する（実機ではなく
      `Any iOS Device (arm64)` を選択した状態でアーカイブすること）。
- [ ] アーカイブ完了後に自動で開く **Organizer** ウィンドウで対象アーカイブを選択 →
      **Distribute App** → **App Store Connect** → **Upload** の順に進める（署名は自動管理のままで可）。
- [ ] アップロード完了後、App Store Connect の「TestFlight」または「App 情報」→「ビルド」欄に
      新しい Build が反映されるまで数分〜数十分待つ（反映されたら §2 のロケール設定に進む）。

> 版数 bump は監査修正ラウンドで完了済み（`xcodebuild build` で BUILD SUCCEEDED、built app / 全 3 appex
> の Info.plist で `CFBundleShortVersionString=1.1` / `CFBundleVersion=2` を実機確認済み）。本チェックリスト
> 自体はコード変更を含まないが、対象の pbxproj は既に更新されているという事実を反映している。

---

## 2. ロケール追加 + コピペ対応表

App Store Connect の「App 情報」→「ローカリゼーション」で、v1.0 で唯一設定済みの **日本語 (ja)** に加えて
以下 **6 ロケール**を追加する。ロケールコードは App Store Connect の表記に合わせてある。

- [ ] 简体中文 (zh-Hans)
- [ ] 繁體中文 (zh-Hant)
- [ ] English (en-US)
- [ ] 한국어 (ko)
- [ ] Español (es-ES または es-MX、K-2 の原稿はどちらにも流用できる中立スペイン語)
- [ ] Deutsch (de-DE)

各ロケールを追加したら、「バージョン情報」タブの各フィールドに `RELEASE-MATERIALS.md` の該当セクションから
コピペする。**フィールドの並び順は上から実行すれば埋まる順**にしてある。

### 2-A. ja（日本語）— §1-L + §1-M M-1 を使う（v1.0 の §1-B〜§1-G は使わない）

| App Store Connect のフィールド | 参照セクション | 値の先頭 | 文字数（実測 / 上限） |
|---|---|---|---|
| 名前 | `RELEASE-MATERIALS.md` L-1 | `まとメモ：AIが読んだ記事を自動まとめ` | 19 / 30 |
| サブタイトル | L-2 | `あとで読むを、第二の脳に` | 12 / 30 |
| プロモーションテキスト | L-3 | `「あとで読む」で終わっていませんか？…` | 104 / 170 |
| キーワード | L-4 | `あとで読む,記事保存,AI要約,…` | 71 / 100 |
| 説明文 | L-5（冒頭段落）+ §1-F（「■ どこからでも」以降をそのまま連結） | `■ 「あとで読む」で、終わらせない。…` | 1173 / 4000（L-5 冒頭 134 字 + §1-F 残り 1037 字を連結した実測値） |
| このバージョンの新機能（What's New） | **§1-M M-1**（§1-J J-4 や §1-L L-6 ではなく、7 言語 + 言語ズレバナーまで反映した最終版を使う） | `まとメモ（旧 Knowledge Base）v1.1 をリリースしました。` | 278 / 4000 |

> 説明文の組み立て方: L-5 のコードブロック（4 行）をそのまま貼り、1 行空けて §1-F の `■ どこからでも、
> ひと手間で保存` 見出し以降（「さあ、あなたの iPhone の AI を…」まで）をそのまま続ける。§1-F 冒頭の
> `■ 読んだ知識が、勝手に育つ。` 段落は **使わない**（L-5 に置き換え済み）。

### 2-B. zh-Hans / zh-Hant / en — §1-J + §1-M を使う

| ロケール | フィールド | 参照 | 値の先頭 | 文字数（実測 / 上限） |
|---|---|---|---|---|
| zh-Hans | 名前 | J-1 | `Knowledge Base：AI第二大脑` | 21 / 30 |
| zh-Hans | サブタイトル | J-1 | `iPhone的AI，养出你的第二大脑` | 18 / 30 |
| zh-Hans | プロモーションテキスト | J-1 | `读完就忘？不再需要。…` | 123 / 170 |
| zh-Hans | キーワード | J-1 | `笔记,备忘录,AI,知识管理,…` | 65 / 100 |
| zh-Hans | 説明文 | J-1 | `■ 读过的知识，自动生长` | 1064 / 4000 |
| zh-Hans | What's New | **§1-M M-2** | `Knowledge Base v1.1 发布了。` | 214 / 4000 |
| zh-Hant | 名前 | J-2 | `Knowledge Base：AI第二大腦` | 21 / 30 |
| zh-Hant | サブタイトル | J-2 | `iPhone的AI，養出你的第二大腦` | 18 / 30 |
| zh-Hant | プロモーションテキスト | J-2 | `讀完就忘？不再需要。…` | 123 / 170 |
| zh-Hant | キーワード | J-2 | `筆記,備忘錄,AI,知識管理,…` | 65 / 100 |
| zh-Hant | 説明文 | J-2 | `■ 讀過的知識，自動生長` | 1062 / 4000 |
| zh-Hant | What's New | **§1-M M-3** | `Knowledge Base v1.1 發布了。` | 214 / 4000 |
| en-US | Name | J-3 | `Knowledge Base: Second Brain` | 28 / 30 |
| en-US | Subtitle | J-3 | `AI grows your second brain`（§1-H の旧案 `Your AI-organized second brain` は 31 字で上限超過のため**使わない**） | 26 / 30 |
| en-US | Promotional Text | J-3 | `Stop reading and forgetting. …` | 166 / 170 |
| en-US | Keywords | J-3 | `note,AI,knowledge,bookmark,…` | 95 / 100 |
| en-US | Description | J-3 | `■ Knowledge that grows on its own` | 2836 / 4000 |
| en-US | What's New | **§1-M M-4** | `Knowledge Base v1.1 is here.` | 552 / 4000 |

### 2-C. ko / es / de — §1-K + §1-M を使う

| ロケール | フィールド | 参照 | 値の先頭 | 文字数（実測 / 上限） |
|---|---|---|---|---|
| ko | 이름 (Name) | K-1 | `Knowledge Base: AI 두 번째 뇌` | 25 / 30 |
| ko | 부제 (Subtitle) | K-1 | `iPhone의 AI가 키우는 제2의 뇌` | 21 / 30 |
| ko | 프로모션 텍스트 | K-1 | `읽고 잊어버리는 습관과는 이제 안녕. …`（170 文字ちょうど、上限ぴったりなので追記しないこと） | 170 / 170 |
| ko | 키워드 | K-1 | `노트,메모,AI,지식관리,…` | 65 / 100 |
| ko | 설명 (Description) | K-1 | `■ 읽은 지식이, 저절로 자랍니다` | 1524 / 4000 |
| ko | What's New | **§1-M M-5** | `Knowledge Base v1.1을 출시했습니다.` | 296 / 4000 |
| es | Nombre | K-2 | `Knowledge Base: IA 2º Cerebro` | 29 / 30 |
| es | Subtítulo | K-2 | `IA de tu iPhone, tu 2º cerebro`（30 文字ちょうど、上限ぴったり） | 30 / 30 |
| es | Texto promocional | K-2 | `Deja de leer y olvidar. …` | 165 / 170 |
| es | Palabras clave | K-2 | `nota,IA,conocimiento,marcador,…` | 90 / 100 |
| es | Descripción | K-2 | `■ El conocimiento que lees crece por sí solo` | 3182 / 4000 |
| es | What's New | **§1-M M-6** | `Knowledge Base v1.1 ya está disponible.` | 626 / 4000 |
| de | Name | K-3 | `Knowledge Base: KI, 2. Gehirn` | 29 / 30 |
| de | Untertitel | K-3 | `iPhone-KI formt Ihr 2. Gehirn` | 29 / 30 |
| de | Werbetext | K-3 | `Schluss mit Lesen und Vergessen. …` | 162 / 170 |
| de | Schlüsselwörter | K-3 | `notiz,KI,wissen,lesezeichen,…` | 97 / 100 |
| de | Beschreibung | K-3 | `■ Wissen, das von selbst wächst`（Sie 調で統一、§1-K 冒頭の注記どおりアプリ内 UI の du 調とは意図的に別） | 3271 / 4000 |
| de | What's New | **§1-M M-7** | `Knowledge Base v1.1 ist da.` | 614 / 4000 |

### 2-D. 共通フィールド（全ロケール共通・ロケール非依存）

- [ ] Primary Category: 仕事効率化 (Productivity) — §1-A、v1.0 のまま変更不要
- [ ] Secondary Category: 辞書/参考書 (Reference) — §1-A、変更不要
- [ ] 年齢制限 4+、価格・Support URL・Privacy Policy URL — §1-A、変更不要
- [ ] 暗号輸出の質問（Uses Non-Exempt Encryption）: **いいえ**（`ITSAppUsesNonExemptEncryption = false` が
      Info.plist に既に設定済みのため、通常は自動回答されるが、初回確認ダイアログが出た場合は「いいえ」を選ぶ）

---

## 3. 審査メモ（App Review Information → Notes）

- [ ] Notes 欄には **§1-J J-5**（v1.1 更新版・7 言語対応 + AI 復旧を反映した審査メモ本体）をそのまま貼る。
- [ ] その本文に、**§1-L L-8** の追記文（日本語ロケール端末ではアプリ表示名・共有シートのボタンが
      「まとメモ」と表示される旨の注記、**日英併記**）を「【動作要件（重要）】」の直前など任意の位置に
      追加で貼り付ける（L-8 は独立したブロックなので、コピペで J-5 本文に挿入するだけでよい）。
- [ ] Contact Info（担当者の連絡先）と Demo Account（本アプリはログイン不要のため「不要」でよい）を確認する。

---

## 4. スクリーンショット

### 4-A. 生成済みファイルの場所

`ScreenShot/appstore/output/<locale>/` に、7 ロケール × 5 スライド × 2 サイズ = **70 枚**の PNG が
生成済み（本セッションで `python3 build.py` → ヘッドレス Chrome で PNG 化まで完了、`git status` には
出ない = `.gitignore` 対象のためコミット不要、そのままアップロードに使う）。

| App Store Connect の画面サイズ | 使うファイル | 解像度 |
|---|---|---|
| 6.9″ Display（iPhone 17 Pro Max 等、必須） | `output/<locale>/01-knowledge.png` 〜 `05-library.png`（`-65` なしの 5 枚） | 1320 × 2868 |
| 6.5″ Display（旧世代機種の見え方安定用、任意） | `output/<locale>/01-knowledge-65.png` 〜 `05-library-65.png`（`-65` 付きの 5 枚） | 1242 × 2688 |

- [ ] 各ロケールについて、「App プレビューとスクリーンショット」→ 対応する画面サイズのスロットに
      `01` 〜 `05` を**この順番**でアップロードする（`01-knowledge`(ナレッジフィード) →
      `02-wiki`(概念ページ) → `03-chat`(AI チャット) → `04-save`(記事詳細/共有訴求) →
      `05-library`(ライブラリ)、物語の弧: まとまる → 事典 → 根拠付き回答 → その場で保存 → 自動整理）。
- [ ] 6.9″ をアップロードすると 6.5″ 枠は Apple 側で自動生成される場合があるが、見え方を安定させたい
      場合は上表の `-65` ファイルを明示的に 6.5″ 枠にもアップロードする。

### 4-B. ja fallback のままのロケール（要判断）

現時点で `ScreenShot/<locale>/` に実機 PNG が存在するのは **どのロケールにも存在しない**
（`ScreenShot/ja/` も含め専用フォルダはゼロ）。したがって **7 ロケール全て**が
`ScreenShot/` 直下の ja 実機スクショ（`knowledge base.PNG` 等）をフォールバック画像として使っている。
つまり **zh-Hans / zh-Hant / en / ko / es / de の 6 ロケールは、キャプションだけ翻訳済みで
デバイス内 UI 表示は日本語のまま**（例: `output/de/03-chat.png` は見出し・チップは Deutsch だが、
画面内のチャット UI やステータスバー表記は日本語）。

- [ ] **提出前に必ず判断**: 日本語 UI が写った状態のスクショを他ロケールでそのまま提出するか、
      各言語で実機撮影し直すか。App Store の審査基準上はロック violation ではないが、ASO・信頼性の
      観点では望ましくない。最低でも **en** だけは差し替えることを推奨。
- [ ] ステータスバーの時刻/電池も v0.1 撮影時のまま（18:03〜18:04・52%）。`RELEASE-MATERIALS.md` §3-B の
      「9:41・フル充電」推奨とズレているため、差し替え時に揃えると良い。

### 4-C. 差し替え手順（`ScreenShot/appstore/README.md` に準拠）

1. 対象ロケールに端末言語 / アプリの「設定 > 生成言語」を切り替えてから、`SLIDE_LAYOUT` の 5 画面
   （ナレッジフィード / Wiki 詳細 / AI チャット / 記事詳細 / ライブラリ）を実機で撮影する。
2. `ScreenShot/<locale>/`（例: `ScreenShot/en/`）フォルダを作成し、**ja と同じファイル名**で置く
   （`knowledge base.PNG` / `wiki page.PNG` / `AI Chat.PNG` / `content page.PNG` / `library.PNG`）。
3. `cd ScreenShot/appstore && python3 build.py` を再実行 → その言語だけ実機画像に切り替わる
   （他言語は引き続き ja フォールバックのまま残るので、全部揃うまで待たずに 1 言語ずつ進めてよい）。
4. ヘッドレス Chrome で PNG 化する（`README.md` のコマンドをそのまま使えばよい。作業 A で発覚した
   「`-65` も `--window-size=1320,2868` のまま焼かれる」バグは README 側を修正済み — `suffix` ごとに
   `1320,2868` / `1242,2688` を出し分けるようになっている）。
5. `output/<locale>/` の PNG を App Store Connect に再アップロードする。

---

## 5. 対応済みで作業不要な項目

以下は既にコードで対応済み。App Store Connect 側での追加作業は不要（確認のみでよい）。

- [x] **暗号輸出申告**: `ITSAppUsesNonExemptEncryption = false` が `KnowledgeBase.xcodeproj` の
      Debug/Release 両ビルド設定に設定済み（`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`、
      標準 HTTPS のみで exempt）。App Store Connect 側で暗号使用の確認ダイアログが出ても
      「いいえ」を選べば通常は追加書類不要。
- [x] **Privacy Manifest**: `KnowledgeBase/PrivacyInfo.xcprivacy` が同梱済み（NSPrivacyTracking=false、
      収集データ種別なし、Required-Reason API は UserDefaults のみ宣言）。App Privacy 質問票
      （データ収集=なし / トラッキング=なし）と内容が一致しているため、質問票の再確認のみでよい。
- [x] **年齢制限・カテゴリ・Support/Privacy Policy URL**: §1-A のまま v1.0 から変更なし。

---

## 6. 提出前 最終チェックボックス

- [ ] §2 の全 7 ロケールのメタデータをコピペし終え、文字数超過（赤字警告）が出ていないことを
      App Store Connect の画面上で目視確認する。
- [ ] §3 の審査メモ（J-5 本文 + L-8 追記文）を Notes 欄に貼り終えている。
- [ ] §4 のスクリーンショットを 7 ロケール × 必須サイズぶんアップロードし終え、fallback のままの
      ロケールについて §4-B の判断（そのまま出す／差し替える）を済ませている。
- [ ] §1 でバージョン 1.1 のビルドをアップロード済みで、App Store Connect 上で選択できる状態になっている。
- [ ] 実機検証が完了している（`docs/HANDOFF.md` §2-1「実機検証（優先度順）」の 4 言語 UI・生成言語確認 +
      Apple Intelligence 可用性ガイド + AI 復旧 + `PR #78` の言語ズレ検知バナーの動作確認。
      加えて 韓国語・スペイン語・ドイツ語ロケールでの UI/生成言語も同じ手順で確認すること
      — HANDOFF.md 執筆時点では zh/en の 4 言語分の記述のみのため、ko/es/de も同一手順で追加確認する）。
- [ ] 「まとメモ」への改名が日本語ロケール端末（設定 > 一般 > 言語と地域 = 日本語）でのみ反映され、
      他 6 ロケールでは "Knowledge Base" のままであることを確認している。
- [ ] 提出（Submit for Review）を実行する。

---

## 付録: 文字数実測コマンド（再現用）

本チェックリストの文字数列は、`docs/app-store/RELEASE-MATERIALS.md` の該当コードブロックを
python3 の `len()` で直接測った実測値（ドキュメント記載値との差異ゼロを確認済み）。再現する場合:

```bash
cd /Users/changchiawei/Desktop/KnowledgeTree
python3 - <<'EOF'
import re
with open("docs/app-store/RELEASE-MATERIALS.md", encoding="utf-8") as f:
    content = f.read()
fence = "`" * 3
parts = content.split(fence)
count_re = re.compile(r"（(\d+)\s*/\s*4000\s*字）")
for i in range(1, len(parts), 2):
    text = parts[i]
    if text.startswith("\n"): text = text[1:]
    if text.endswith("\n"): text = text[:-1]
    following = parts[i+1] if i+1 < len(parts) else ""
    m = count_re.match(following.lstrip("\n"))
    if m:
        claimed, actual = int(m.group(1)), len(text)
        print(claimed, actual, "OK" if claimed == actual else "MISMATCH")
EOF
```
