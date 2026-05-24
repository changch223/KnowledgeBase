# Contract: SuggestedPromptGenerator

## Purpose

AI チャットタブの空状態 (ChatSession 履歴ゼロ) で表示する 3 つの suggested prompts を動的生成。ユーザーの実データ (最新 ConceptPage / Category) と固定 prompt を組み合わせる。1 日 1 回 cache 更新で起動毎再生成負荷を回避。

## Protocol

```swift
@MainActor
protocol SuggestedPromptGeneratorProtocol: AnyObject {
    /// 3 つの suggested prompts を返す。cache 有効なら cache から、なければ再生成。
    func generateSuggestedPrompts(in context: ModelContext) async -> [SuggestedPrompt]
    
    /// cache を空にする (テスト用)。
    func clearCache()
}
```

## SuggestedPrompt struct

```swift
struct SuggestedPrompt: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String           // 最大 30 字 (超過時 truncate ... 付き)
    let sourceType: SourceType
    
    enum SourceType: String, Codable {
        case latestConceptPage
        case latestCategory
        case fixedSummaryPrompt   // 「最近保存した記事の要点は?」
        case genericFallback
    }
}
```

## Default Implementation

```swift
@MainActor
final class DefaultSuggestedPromptGenerator: SuggestedPromptGeneratorProtocol {
    private let cacheKey = "spec056_suggested_prompts_cache"
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
    
    private struct CacheEntry: Codable {
        let date: String
        let prompts: [SuggestedPrompt]
    }
    
    func generateSuggestedPrompts(in context: ModelContext) async -> [SuggestedPrompt] {
        // 1. cache check
        let today = dateFormatter.string(from: .now)
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cache = try? JSONDecoder().decode(CacheEntry.self, from: data),
           cache.date == today {
            return cache.prompts
        }
        
        // 2. 再生成
        var prompts: [SuggestedPrompt] = []
        
        // (a) 最新 ConceptPage prompt (あれば)
        var cpDescriptor = FetchDescriptor<ConceptPage>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        cpDescriptor.fetchLimit = 1
        if let cp = try? context.fetch(cpDescriptor).first {
            let text = truncate("\(cp.name) について教えて", maxChars: 30)
            prompts.append(.init(id: UUID(), text: text, sourceType: .latestConceptPage))
        }
        
        // (b) 最新 Category prompt (あれば)
        if let latestCategory = await fetchLatestCategory(in: context) {
            let text = truncate("\(latestCategory) 分野で何があった?", maxChars: 30)
            prompts.append(.init(id: UUID(), text: text, sourceType: .latestCategory))
        }
        
        // (c) 固定: 「最近保存した記事の要点は?」 (常に追加、ただし最後に追加)
        prompts.append(.init(
            id: UUID(),
            text: String(localized: "chat.suggested.recentSummary"),  // "最近保存した記事の要点は?"
            sourceType: .fixedSummaryPrompt
        ))
        
        // (d) 3 件未満なら generic fallback で埋める
        let fallbacks = [
            String(localized: "chat.suggested.fallback.aboutApp"),     // "iKnow について教えて"
            String(localized: "chat.suggested.fallback.howToUse"),     // "使い方を教えて"
            String(localized: "chat.suggested.fallback.whatsNew")      // "最近何が新しい?"
        ]
        for fb in fallbacks where prompts.count < 3 {
            prompts.append(.init(id: UUID(), text: fb, sourceType: .genericFallback))
        }
        
        // 上位 3 件のみ
        let result = Array(prompts.prefix(3))
        
        // 3. cache save
        let entry = CacheEntry(date: today, prompts: result)
        if let data = try? JSONEncoder().encode(entry) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
        
        return result
    }
    
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
    
    private func fetchLatestCategory(in context: ModelContext) async -> String? {
        // Article の categoryRaw を distinct で fetch、savedAt desc で 1 件
        var descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20  // 直近 20 件から最初に出現する category
        let recent = (try? context.fetch(descriptor)) ?? []
        return recent.compactMap { $0.categoryRaw }.first
    }
    
    private func truncate(_ s: String, maxChars: Int) -> String {
        guard s.count > maxChars else { return s }
        return String(s.prefix(maxChars - 1)) + "…"
    }
}
```

## Behavior

| Case | Input | Output |
|---|---|---|
| 正常 (ConceptPage 5 / Category 3) | 最新 ConceptPage = "OpenAI"、最新 Category = "テクノロジー" | ["OpenAI について教えて", "テクノロジー 分野で何があった?", "最近保存した記事の要点は?"] |
| ConceptPage 0 / Category 0 | データ無し | ["最近保存した記事の要点は?", "iKnow について教えて", "使い方を教えて"] |
| ConceptPage 1 / Category 0 | 最新 ConceptPage = "Claude" | ["Claude について教えて", "最近保存した記事の要点は?", "iKnow について教えて"] |
| 30 字超過 | ConceptPage.name = "とても長い概念名で30字を超える例" | 「とても長い概念名で30字を超…」 (truncate) |
| 同 date 再呼出 | cache 有効 | cache 配列をそのまま返却、fetch なし |
| 翌日再呼出 | cache.date != today | 再生成、新 cache 保存 |

## UI 結合

```swift
struct SuggestedPromptsSection: View {
    @Environment(\.modelContext) var context
    @Environment(ServiceContainer.self) var services
    @State private var prompts: [SuggestedPrompt] = []
    let onPromptTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💡 候補")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(prompts) { prompt in
                Button {
                    onPromptTap(prompt.text)
                } label: {
                    HStack {
                        Text(prompt.text)
                        Spacer()
                        Image(systemName: "arrow.right.circle")
                    }
                    .padding()
                    .background(.regularMaterial, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            prompts = await services.suggestedPromptGenerator.generateSuggestedPrompts(in: context)
        }
    }
}
```

## Test Cases (6 件)

1. **正常**: ConceptPage 5 + Category 3 → 最新 1 + 最新 1 + 固定 1 (合計 3)
2. **データ無し fallback**: ConceptPage 0 + Category 0 → 固定 1 + generic 2 (合計 3)
3. **ConceptPage 1 + Category 0**: ConceptPage 1 + 固定 1 + generic 1
4. **30 字 truncate**: 入力 31+ 字 → 30 字に truncate + "…"
5. **1 日 cache**: 同日 2 回呼出 → cache 返却 (call count 1 のみ)
6. **cache miss (date 違い)**: 異なる date で 2 回呼出 → 再生成 (call count 2)

## DI / Lifecycle

- ServiceContainer に `suggestedPromptGenerator: SuggestedPromptGeneratorProtocol` を追加
- KnowledgeTreeApp.bootstrap で DefaultSuggestedPromptGenerator 生成 + inject
- SuggestedPromptsSection の `.task` で呼出

## xcstrings 追加

- `chat.suggested.recentSummary` = "最近保存した記事の要点は?"
- `chat.suggested.fallback.aboutApp` = "iKnow について教えて"
- `chat.suggested.fallback.howToUse` = "使い方を教えて"
- `chat.suggested.fallback.whatsNew` = "最近何が新しい?"

## Performance

- 初回 cache miss = SwiftData fetch 2 回 (ConceptPage + Article) + UserDefaults save = ~50ms
- cache hit = JSON decode のみ = ~5ms
- UI 表示まで合算 100ms 以内
