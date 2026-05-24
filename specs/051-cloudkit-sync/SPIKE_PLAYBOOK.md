# spec 051 Phase 0 Spike Playbook

**目的**: R6 (App Group + CloudKit private DB の同時指定が iOS 26 で動くか) を実機検証
**所要**: **1 時間以下** (Apple Developer setup 含む)
**判断**: 完了後、Phase A 着手 (GO) / V2.5 繰り延べ (NO-GO) を決定

---

## 前提

- ✅ Apple Developer Account (paid、$99/年) — CloudKit container 作成に必須
- ✅ iPhone 実機 (iOS 26+) + iCloud にサインイン済
- ✅ Mac で Xcode 16+ + KnowledgeTree.xcodeproj が開ける
- ✅ Xcode で Apple ID にサインイン済 (Provisioning Profile 自動生成)

⚠️ **Apple Developer Account がない** → spike 不可、まず Apple Developer Program 加入 ($99/年) または **Option C: Widget だけ V2.0** に切替

---

## Step 1: Apple Developer Portal で CloudKit Container 作成 (10 分)

1. https://developer.apple.com/account/resources/identifiers/list/cloudContainer を開く
2. 右上「+」 → **CloudKit Containers** → Continue
3. 設定:
   - **Description**: `iKnow CloudKit Container`
   - **Identifier**: `iCloud.app.KnowledgeTree` (👈 この exact ID、後で Xcode で使う)
4. Continue → Register
5. 完了。CloudKit Dashboard (https://icloud.developer.apple.com/dashboard/) でも確認可能

## Step 2: Xcode で iCloud Capability 追加 (5 分)

1. Xcode で `KnowledgeTree.xcodeproj` を開く
2. **TARGETS → KnowledgeTree** を選択
3. **Signing & Capabilities** タブ
4. 左上「**+ Capability**」 → 検索「**iCloud**」 → ダブルクリック
5. iCloud section が追加される:
   - ✅ **Services**: `CloudKit` をチェック
   - ✅ **Containers**: `iCloud.app.KnowledgeTree` をチェック (Step 1 で作った ID が出てくる、もし出なければ右下「↻」リロード)
6. (App Group も既に有効なはず、そのまま)

Xcode が `.entitlements` を自動更新します。

## Step 3: SharedSchema にフラグ付き CloudKit config を適用 (3 分)

`KnowledgeTree/SharedSchema.swift` を以下のように **一時的に** 変更:

```swift
import Foundation
import SwiftData

enum SharedSchema {
    /// 🧪 SPIKE: CloudKit を有効化 (実機検証用、Phase 0 のみ)
    /// false に戻せば従来動作 (App Group only)
    private static let SPIKE_CLOUDKIT_ENABLED = true   // 👈 ← spike のみ true、検証後 false に戻す

    static var all: Schema {
        Schema([
            Article.self,
            ArticleEnrichment.self,
            ArticleBody.self,
            ExtractedKnowledge.self,
            KeyFact.self,
            KnowledgeEntity.self,
            Tag.self,
            KnowledgeChunkProgress.self,
            BackgroundExtractionQueueEntry.self,
            KnowledgeDigest.self,
            ChatSession.self,
            ChatMessage.self,
            ConflictProposal.self,
            UserTopic.self,
            GraphNode.self,
            GraphEdge.self,
            ConceptPage.self,
            SavedAnswer.self,
            UnderstandingInteraction.self,
        ])
    }

    static func sharedConfiguration() -> ModelConfiguration {
        if SPIKE_CLOUDKIT_ENABLED {
            // 🧪 SPIKE: App Group + CloudKit private 同時指定
            return ModelConfiguration(
                schema: all,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(AppGroup.identifier),
                cloudKitDatabase: .private("iCloud.app.KnowledgeTree")
            )
        } else {
            return ModelConfiguration(
                schema: all,
                groupContainer: .identifier(AppGroup.identifier)
            )
        }
    }
}
```

## Step 4: ビルドして実機にインストール (10 分)

1. Xcode 左上で **実機 iPhone を選択** (Simulator では CloudKit は限定動作、要実機)
2. ⌘+R で Run
3. ビルド中、エラー出たら 👉 [Spike 結果: scenario 3 (worst case)](#worst-case-scenario-3)
4. インストール成功 → アプリ起動

## Step 5: 結果判定 (10 分)

### ✅ Scenario 1: BEST CASE — 正常動作

**判定基準**: 以下が全部当てはまる
- Xcode console に error / fatalError なし
- アプリ起動成功
- 学習タブ / 知識 Clip タブ等が従来通り表示
- 既存記事が消えてない (App Group container も読めている)
- (任意) 新 article 保存 → 数分待つ → CloudKit Dashboard (https://icloud.developer.apple.com/dashboard/) → Private Database → Records に Article が現れる

**console で watch するパターン (正常)**:
```
No errors mentioning "ModelContainer" or "CloudKit"
SwiftData が静かに sync を進行
```

**→ Phase A GO**
- spec 051 を fully 実装 (~2 週間で完成見込み)
- 私が schema 改修 + dedup logic + Settings toggle を一気に進める
- ✅ Step 6 に進む

### ⚠️ Scenario 2: MEDIUM — groupContainer 無視

**判定基準**: 
- アプリ起動成功
- でも **Share Extension からの保存記事が main app に反映されない** (Share Sheet で iKnow 保存 → main app でライブラリに出ない)
- CloudKit Dashboard には Share Extension 経由のも出る (or 出ない、要確認)

**→ Phase A GO with modification**
- spec 051 + Share Extension 改修 (CloudKit 直接書き、+1 週間)
- 合計 3 週間

### ❌ Scenario 3: WORST CASE — エラー

**判定基準**:
- アプリ起動失敗
- console に以下のような error:
  ```
  Fatal error: Could not create ModelContainer: ...
  CloudKit container "iCloud.app.KnowledgeTree" not found
  CloudKit + group container は同時指定できません
  ```
- もしくは ビルドエラー (Xcode が cloudKitDatabase API を認識しない等)

**→ NO-GO**
- spec 051 は V2.5 へ繰り延べ
- V2.0 は spec 052 Widget のみで release
- 私が spec 052 を 1 週間で実装

## Step 6: Spike 結果のクリーンアップ

**Scenario 1/2/3 どれでも、検証後**:

1. `SharedSchema.swift` の `SPIKE_CLOUDKIT_ENABLED` を **`false` に戻す** (本番動作復旧)
2. アプリを Xcode から再 install
3. 起動確認 (元に戻ったことを確認)

✅ これでアプリは spike 前の状態に戻ります。CloudKit Container は Apple Developer Portal に作ったままで OK (削除不要、Phase A で再利用)。

---

## 結果報告フォーマット

検証完了後、以下を私に報告してください:

```
Step 4 ビルド: ✅ OK / ❌ Error: <error message>

Step 5 起動: ✅ OK / ❌ Crash: <crash message>

学習タブ 表示: ✅ OK / ⚠️ Empty / ❌ Crash

既存記事 (ライブラリタブ): ✅ そのまま / ❌ 消えた

console error / warning (もしあれば全文 copy):
<paste>

CloudKit Dashboard 確認 (任意): ✅ Record 出る / ❌ 出ない / ⏭️ 確認しなかった

判定: Scenario 1 / 2 / 3
```

私が結果見て **Phase A 着手 / Widget 先 / V2.5 繰り延べ** を即決定します。

---

## トラブルシューティング

### Xcode signing error
- TARGETS → KnowledgeTree → Signing & Capabilities → Team が空 → 自分の Apple Developer Account 選択
- Bundle Identifier が他人と衝突 → 末尾に suffix 追加 (例: `app.KnowledgeTree.dev`)

### CloudKit container が iCloud capability の Containers リストに出ない
- Apple Developer Portal で作成後 5-10 分待つ (Apple のサーバー sync 遅延)
- Xcode で右下「↻」リロード
- それでもダメなら、Xcode 再起動

### 実機が認識されない
- iPhone を Mac に USB 接続 → iPhone で「このコンピュータを信頼」確認
- Xcode → Window → Devices and Simulators で実機表示確認

### "Provisioning profile doesn't include..." error
- Xcode が自動再生成するはず、待つ
- Manual: Signing & Capabilities → Automatically manage signing チェック解除/再チェック

---

## 何かわからない / 詰まったら

console error message を全文 copy して私に貼ってください。一緒にデバッグします。
