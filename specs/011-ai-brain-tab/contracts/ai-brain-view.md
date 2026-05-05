# Contract: AIBrainView

**Created**: 2026-05-05
**File**: `KnowledgeTree/Views/AIBrainView.swift`

## 責務

AI ブレインタブの root view。NavigationStack 内で 3 セクション (PowerGauge / KnowledgeMap / RecentActivityCards) を縦 ScrollView で配置。`navigationDestination` は spec 008 既存の `TagFilteredDestination` 型を再利用し、KnowledgeMap ノードタップから TagFilteredListView へ遷移する。

## 構造

```swift
struct AIBrainView: View {
    @Environment(RefreshTrigger.self) private var refresh
    @Environment(ProcessingMonitor.self) private var processingMonitor
    @Query private var allTags: [Tag]

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    PowerGaugeCard()
                        .frame(height: 160)

                    KnowledgeMapView(tags: allTags)
                        .frame(minHeight: 300)

                    RecentActivityCards()
                        .frame(height: 120)
                }
                .padding()
            }
            .navigationTitle("AI ブレイン")
            .navigationDestination(for: TagFilteredDestination.self) { dest in
                TagFilteredListView(tagName: dest.tagName)
            }
        }
        .accessibilityIdentifier("aibrain.root")
        .onChange(of: refresh.version) { _, _ in
            // 子 view の @Query は自動更新されるが、map graph rebuild トリガーとして使う
        }
    }
}
```

## 入力契約

- 親から **環境経由で** `RefreshTrigger` / `ProcessingMonitor` / `ServiceContainer` / `ModelContainer` を受け取る
- 引数なし

## 出力契約

- 表示のみ (mutation なし)
- ノードタップで `path` に `TagFilteredDestination` を push、TagFilteredListView へ遷移

## アクセシビリティ

| Element | accessibilityIdentifier | VoiceOver Label |
|---|---|---|
| Root | `aibrain.root` | (NavigationStack default) |
| ScrollView | `aibrain.scroll` | — |
| Section 1 frame | `aibrain.power_gauge` | (PowerGaugeCard が提供) |
| Section 2 frame | `aibrain.knowledge_map` | (KnowledgeMapView が提供) |
| Section 3 frame | `aibrain.recent_activity` | (RecentActivityCards が提供) |

## ローカライゼーション

`Localizable.xcstrings` に追加するキー:

- `"AI ブレイン"` (NavigationBar title)

## エラーハンドリング

- `allTags.isEmpty` の場合: KnowledgeMapView 内で `ContentUnavailableView` 表示 (本 view 自体はそのまま表示)
- AIBrainView 自体がエラーパスを持たない (read-only view)

## 副作用

- `refresh.version` 変化で子の `@Query` が自動再評価
- `path` への push でナビゲーション遷移

## 依存

- `RefreshTrigger`, `ProcessingMonitor` (環境経由)
- `Tag` (`@Query`)
- `TagFilteredDestination` (spec 008、既存型)
- `TagFilteredListView` (spec 008、改修なし)
- `PowerGaugeCard` / `KnowledgeMapView` / `RecentActivityCards` (本 spec で新規)
