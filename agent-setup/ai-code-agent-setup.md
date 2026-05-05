# AI Code Agent セットアップ — 今後の対応チェックリスト

> Claude Code などの AI エージェントが知積アプリを高精度で開発・維持するために必要な設定・ドキュメントの一覧。
> 完了したら `[ ]` を `[x]` に変更する。

---

## 優先度 高

### [ ] 1. MCP: XcodeBuildMCP インストール

Xcode のビルド・テスト・デバッグ・UI 自動操作を Agent が構造化 JSON で扱えるようになる（59 ツール）。

**インストール手順:**
```bash
claude mcp add --transport stdio XcodeBuildMCP -- npx -y xcodebuildmcp@latest
```

**主な機能:**
- `simulator/build` — シミュレータービルド
- `simulator/screenshot` — スクリーンショット取得
- `ui-automation/tap` — UI 自動タップ
- `debugging/attach` — デバッガーアタッチ
- `test/run` — XCTest スイート実行

**参照:** https://www.xcodebuildmcp.com/

---

### [ ] 2. MCP: iOS Simulator MCP インストール

シミュレーターの視覚確認・操作を Agent が自律実行できるようになる。quickstart シナリオの一部自動化に必須。

**インストール手順:**
```bash
claude mcp add ios-simulator-mcp
```

**主な機能:**
- スクリーンショット取得・UI 階層検査
- タップ・スワイプ・テキスト入力
- GPS 位置設定
- アプリ起動・終了

**参照:** https://github.com/joshuayoes/ios-simulator-mcp

---

### [ ] 3. Hooks 設定 — 自動品質チェック

Agent がファイルを編集するたびに SwiftLint と XCTest が自動実行される。手動コマンド忘れを防ぐ。

**設定ファイル:** `.claude/settings.json`（プロジェクト共有）

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "cd /Users/changchiawei/Desktop/KnowledgeTree && swiftlint lint --quiet"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5"
          }
        ]
      }
    ]
  }
}
```

**注意:** SwiftLint が未インストールの場合は先に `brew install swiftlint` を実行。

---

## 優先度 中

### [ ] 4. DESIGN.md 作成 — AI 可読デザイン仕様書

`DesignSystem.swift` のトークンをマークダウン化したファイル。Agent がコードを読まずにデザイン意図を把握できる。

**作成場所:** `design-references/DESIGN.md`

**含める内容:**

| セクション | 内容 |
|-----------|------|
| カラートークン | `DS.Color.*` 全定数・用途・使用ルール |
| スペーシング | 8pt グリッド定義（xxs〜section） |
| タイポグラフィ | hero / section / content / body 各スタイル |
| コーナー半径 | thumb / chip / card / hero + continuous 指定 |
| アニメーション | 各 spring 定数 + Reduce Motion ルール |
| カスタム修飾子 | `.dsCardBackground` / `.dsAIGradientBackground` / `.dsShadowCard` 使用方法 |
| コンポーネントルール | Material 密度統一 / タッチターゲット 44pt / SF Symbols 階層レンダリング |

**参考フォーマット:** https://designmd.app/en/what-is-design-md

---

### [ ] 5. AGENTS.md 作成 — SwiftUI コーディング規約

Agent に知積アプリ固有のルールを伝えるファイル。CLAUDE.md の補完として機能。

**作成場所:** `agent-setup/AGENTS.md`

**含める内容:**

```markdown
## 絶対禁止
- .pbxproj ファイルを編集しない（破損で数時間ロスする）
- SwiftData @Model に computed property を追加しない（クラッシュ原因）
- MainActor 外から UI 更新しない

## 状態管理
- View Model には @Observable を使う（@ObservableObject は非推奨）
- View ローカルな一時状態のみ @State を使う
- SwiftData は @Query + @Bindable のパターンを踏襲する

## 非同期処理
- async/await + Task を使う（Combine は既存コードの維持のみ）
- MainActor isolation を明示する

## UI / デザイン
- DS.* トークンのみ使う（Color.white.opacity() などリテラル禁止）
- SF Symbols には .symbolRenderingMode(.hierarchical) を適用する
- タッチターゲットは最低 44pt 確保する
- アニメーションは DS.Animation.ifMotionAllowed() で Reduce Motion を尊重する

## テスト
- 新規ロジックには必ず Unit テストを追加する
- UI テストは XCTest + XcodeBuildMCP で実行する
- @Model / SwiftData のテストは InMemory コンテナを使う

## 廃止 API（使用禁止）
- @ObservableObject / @StateObject / @EnvironmentObject → @Observable に移行済み
- NavigationView → NavigationStack
- onChange(of:perform:) → onChange(of:) { _, new in }
```

---

## 優先度 低（将来対応）

### [ ] 6. quickstart シナリオの一部を自動化

MCP 導入後に検討。XcodeBuildMCP + iOS Simulator MCP で SC-001〜SC-007 の視覚確認を自動化する。

| シナリオ | 自動化難易度 | 方法 |
|---------|------------|------|
| SC-001 空状態表示 | 低 | スクリーンショット比較 |
| SC-002 記事追加 → カウントアップ | 中 | UI automation タップ + 値確認 |
| SC-003 60fps 確認 | 高 | Instruments 連携（手動が現実的） |
| SC-007 タグ backfill 完了 | 中 | BottomStatusBar 消滅を polling で確認 |

---

### [ ] 7. CI/CD パイプライン（GitHub Actions）

PR 作成時に自動ビルド・テストを走らせる。

```yaml
# .github/workflows/ios.yml の雛形
- xcodebuild build -scheme KnowledgeTree
- xcodebuild test -scheme KnowledgeTreeTests
- swiftlint lint
```

---

## 参照リソース

| リソース | URL |
|---------|-----|
| Claude Code ベストプラクティス | https://docs.anthropic.com/ja/docs/claude-code/best-practices |
| XcodeBuildMCP ドキュメント | https://www.xcodebuildmcp.com/ |
| iOS Simulator MCP | https://github.com/joshuayoes/ios-simulator-mcp |
| Claude Code Hooks ガイド | https://www.letanure.dev/blog/2025-08-06--claude-code-part-8-hooks-automated-quality-checks |
| CLAUDE.md の書き方 | https://www.humanlayer.dev/blog/writing-a-good-claude-md |
| SwiftUI Agent Skill | https://github.com/AvdLee/SwiftUI-Agent-Skill |

---

*最終更新: 2026-05-05*
