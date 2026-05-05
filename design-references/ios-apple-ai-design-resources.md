# iOS Apple風 AI Agent デザインリソース集

> 知積アプリの UI/UX 設計・AI エージェント連携に役立つリソースをまとめたリファレンス。

---

## AI Agent 向けデザイン仕様形式

AI エージェント（Claude Code など）がデザイン意図を正確に理解・実装するための仕様形式。

| リソース                                | URL                                                        | 概要                                                                                                  |
| ----------------------------------- | ---------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **DESIGN.md 形式**                    | https://designmd.app/en/what-is-design-md                  | AI が読みやすいマークダウンでデザイン仕様を記述する標準フォーマット。色・タイポグラフィ・SF Symbols・Dynamic Type の挙動を1ファイルに集約                  |
| **designtoken.md**                  | https://designtoken.md                                     | 150行以上のプロダクション向けトークン定義テンプレート。カラースケール・コンポーネント状態・確定的パースに対応                                            |
| **W3C Design Tokens Specification** | https://www.w3.org/community/design-tokens/                | ツール間でデザイントークンを交換する国際標準フォーマット                                                                        |
| **awesome-ios-design-md**           | https://github.com/Meliwat/awesome-ios-design-md           | Instagram・Spotify・DoorDash・Duolingo・Uber・Airbnb などの主要アプリの DESIGN.md ファイル集。AI エージェントがそのまま参照できる形式     |
| **SwiftUI-Agent-Skill**             | https://github.com/AvdLee/SwiftUI-Agent-Skill              | SwiftUI のベストプラクティスをエージェントスキルとして蒸留。State管理・View構成・Swift Charts・iOS 18 Liquid Glass・macOS マルチウィンドウを網羅 |
| **claude-code-ui-agents**           | https://github.com/mustafakendiguzel/claude-code-ui-agents | Claude 向けに最適化された UI/UX デザインタスクのプロンプト集                                                               |
| **awesome-claude-design**           | https://github.com/rohitg00/awesome-claude-design          | DESIGN.md プロンプトを美的スタイル別に分類・リミックスレシピ付き                                                               |

---

## Apple iOS 26 / Liquid Glass（WWDC 2025）

2025年 WWDC で発表された最新 Apple デザイン言語。タブバー・ナビゲーションバー・モーダルに適用する動的な半透明素材。

| リソース | URL | 概要 |
|---------|-----|------|
| **WWDC 2025: Meet Liquid Glass** | https://developer.apple.com/videos/play/wwdc2025/219 | Liquid Glass の設計思想・使用ルール・実装方法の公式セッション |
| **WWDC 2025: Get to know the new design system** | https://developer.apple.com/videos/play/wwdc2025/356 | iOS 26 デザインシステム全体像の公式セッション |
| **LiquidGlassReference** | https://github.com/conorluddy/LiquidGlassReference | Liquid Glass の SwiftUI 実装サンプル集 |
| **Apple Newsroom 発表** | https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/ | Liquid Glass の公式アナウンス |

### Liquid Glass 実装ポイント

- **自動採用**: Xcode 26 + iOS 26 ターゲットで再コンパイルするだけで、ナビゲーションバー・タブバーが自動で Glass 化（コード変更不要）
- **使用ルール**: ナビゲーション層専用（タブバー・モーダル・バー）。コンテンツ領域には使わない
- **アクセシビリティ**: Reduced Transparency・Increased Contrast・Reduced Motion に自動対応

---

## AI アプリ UX パターン（2025〜2026）

| リソース | URL | 概要 |
|---------|-----|------|
| **Shape of AI** | https://www.shapeof.ai | AI UX パターンの体系的カタログ。最も包括的なリファレンス |
| **OpenAI Apps SDK UI Guidelines** | https://developers.openai.com/apps-sdk/concepts/ui-guidelines | AI 機能を持つアプリの UI 設計ガイドライン |

### 4つの主要 AI UX パターン

| パターン | 内容 | 知積への適用 |
|---------|------|------------|
| **Ambient AI** | AI を UI に溶け込ませ、ボタンの裏に隠さない | タグ自動付与を「見えない」形で実行（spec 012〜013） |
| **Adaptive UX** | ユーザー行動から次のアクションを予測・表面化 | AI Brain タブのコンテンツ優先順位動的調整 |
| **Agentic UX** | AI が自律的にタスクを完了、操作は保守的・取り消し可能 | Backfill runner の進捗表示 + 中断復帰（spec 013） |
| **Zero-UI** | Live Activities・ウィジェットでアプリを開かずに価値提供 | 将来の Widget / Live Activity 対応候補 |

---

## オープンソース SwiftUI デザインシステム

| リソース | URL | 特徴 |
|---------|-----|------|
| **NormanDSKit** | https://github.com/normansanchezn/NormanDSKit | 完全モジュール型、デザイントークン + クリーンなテーマ API、iOS 18 Liquid Glass 対応 |
| **Orange OUDS iOS** | https://github.com/Orange-OpenSource/ouds-ios | 本番品質の SwiftUI コンポーネントライブラリ（Orange Design System 準拠） |
| **Kiwi Orbit SwiftUI** | https://github.com/kiwicom/orbit-swiftui | 大規模プロダクションで検証済みのデザインシステム（Kiwi.com） |

---

## 学習・スキルリソース

| リソース | URL | 内容 |
|---------|-----|------|
| **Apple Human Interface Guidelines** | https://developer.apple.com/design/human-interface-guidelines | iOS 26 + Liquid Glass 含む公式デザインガイドライン |
| **Apple Design Resources** | https://developer.apple.com/design/resources/ | 公式デザインキット・テンプレート・コンポーネント仕様 |
| **Point-Free** | https://www.pointfree.co | TCA・モダン SwiftUI・テスト設計の第一人者的教材 |
| **objc.io App Architecture** | https://www.objc.io/books/app-architecture/ | デザインパターン + SwiftUI アーキテクチャの書籍 |
| **SwiftUI Design System Guide 2025** | https://dev.to/swift_pal/swiftui-design-system-a-complete-guide-to-building-consistent-ui-components-2025-299k | カラー・タイポグラフィ・スペーシングトークンシステムの実装ガイド |
| **Swift Composable Architecture (TCA)** | https://github.com/pointfreeco/swift-composable-architecture | モジュール・テスタブルな状態管理アーキテクチャの参照実装 |

---

## 知積への即時適用ポイント

1. **DESIGN.md を作成する** — `DesignSystem.swift` の内容をマークダウン化すると、Claude Code がデザイン意図をより正確に理解して実装できる。`awesome-ios-design-md` のサンプルを参考に作成。

2. **designtoken.md 形式でトークンを文書化** — 現在の `DS.Color` / `DS.Spacing` / `DS.Typography` をトークンテーブルに変換し、AI エージェントが参照しやすくする。

3. **Liquid Glass は iOS 26 リリース後に検討** — タブバーは Xcode 26 で再コンパイルするだけで自動対応。追加コストほぼゼロ。

4. **shapeof.ai を AI 機能設計の参照元に** — 今後の AI 機能追加時、4つのパターン（Ambient / Adaptive / Agentic / Zero-UI）に照らして設計を検討する。

5. **SwiftUI-Agent-Skill を Claude Code のコンテキストに活用** — spec 実装時にこのスキルのガイドラインを参照すると、より Apple らしいコードが生成される。

---

*最終更新: 2026-05-05*
