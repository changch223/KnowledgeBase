# Contract: KnowledgeGraphFullScreenView

## Purpose

AI チャットタブの 📊 アイコン tap から push される、全 Category の Knowledge Graph 可視化画面。AI ブレインタブ root の代替。

## View Structure

```swift
struct KnowledgeGraphFullScreenView: View {
    @Query(sort: \GraphNode.salience, order: .reverse)
    private var allNodes: [GraphNode]
    
    private var allCategories: [String] {
        Set(allNodes.compactMap { $0.categoryRaw }).sorted()
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.xxl) {
                if allCategories.isEmpty {
                    EmptyStateView(
                        icon: "chart.dots.scatter",
                        title: "knowledgeGraph.empty.title",
                        body: "knowledgeGraph.empty.body"
                    )
                } else {
                    ForEach(allCategories, id: \.self) { category in
                        VStack(alignment: .leading) {
                            Text(category)
                                .font(.headline)
                                .padding(.horizontal)
                            CategoryGraphView(categoryRaw: category)  // 既存 spec 041
                                .frame(height: 300)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("knowledgeGraph.fullScreen.title")
        .accessibilityIdentifier("view.knowledgeGraphFullScreen")
    }
}
```

## 既存 CategoryGraphView (spec 041) 流用

- 既存実装そのまま (Canvas + force-directed layout)
- node tap → GraphNodeDetailView push (既存遷移経路)

## Performance

- LazyVStack で Category 単位 lazy 描画
- 各 subgraph 30-50 node 程度に収まる想定
- 200+ node 全体でも 60fps 維持

## アクセシビリティ

- `view.knowledgeGraphFullScreen`
- 各 Category section header
- 既存 CategoryGraphView の accessibility 継承

## xcstrings 追加

- `knowledgeGraph.fullScreen.title` = "Knowledge Graph"
- `knowledgeGraph.empty.title` = "まだ知識グラフがありません"
- `knowledgeGraph.empty.body` = "記事を保存してエンティティが抽出されると、ここに表示されます"
