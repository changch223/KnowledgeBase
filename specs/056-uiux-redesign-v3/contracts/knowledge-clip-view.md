# Contract: KnowledgeClipView (Phase A 核心)

## Purpose

V3.0 の主役タブ。8 セクション → 3 セクションに削減し、Apple HIG (Clarity / Deference / Depth) 準拠の Today タブを実現。

## View Structure

```swift
struct KnowledgeClipView: View {
    @Environment(\.modelContext) var context
    @State private var path = NavigationPath()
    @State private var showSettings = false
    @State private var showAddArticle = false
    
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.xxl) {
                    RecentArticlesSection()
                    InterestingNextSection()
                    FollowingPeopleSection()
                }
                .padding(.bottom, 80)  // FAB 余白
            }
            .navigationTitle("knowledgeClip.tab.title")  // "知識 Clip"
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AvatarMenu()
                        .accessibilityIdentifier("toolbar.avatar")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                FABButton(icon: "plus") {
                    showAddArticle = true
                }
                .accessibilityIdentifier("fab.addArticle")
            }
            .sheet(isPresented: $showAddArticle) {
                AddArticleSheet()
            }
            // navigationDestinations (既存 + 新規)
            .navigationDestination(for: ConceptPageDetailDestination.self) { dest in
                ConceptPageDetailLoader(destinationID: dest.id)
            }
            .navigationDestination(for: UnderstandingCard.self) { card in
                DeepDiveChatView(card: card)
            }
            .navigationDestination(for: KnowledgeDigest.self) { digest in
                CategoryKnowledgeDetailView(digest: digest)
            }
            .navigationDestination(for: ActionItemsReviewDestination.self) { _ in
                ActionItemsReviewView()
            }
        }
        .accessibilityIdentifier("tab.knowledgeClip")
    }
}
```

## Section Order (固定)

1. **RecentArticlesSection** — 最近の記事 (差分 3 件)
2. **InterestingNextSection** — 続きが気になるもの (混在 5 件)
3. **FollowingPeopleSection** — 追っている人物・モノ (isFollowing + ⚠️ badge)

## Toolbar (右上)

- **AvatarMenu** — `person.crop.circle` icon → Settings sheet

## FAB (右下)

- **FABButton** with `plus` icon → AddArticleSheet modal

## 旧 Section の取り扱い

| 旧 section | 対応 |
|---|---|
| RecentDigestSection (spec 035) | **RecentArticlesSection に昇格 + 改名** |
| FactConflictsSection (spec 037) | **削除**、機能は FollowingPeopleSection の ⚠️ badge に統合 |
| StaleSavedAnswersSection (spec 046) | **削除**、機能は FollowingPeopleSection の ⚠️ badge に統合 |
| ConceptPage section (spec 042) | **FollowingPeopleSection に昇格 + isFollowing filter** |
| DynamicTopicsSection (spec 036 UserTopic) | **削除**、機能は InterestingNextSection の Topic Dashboard に統合 |
| KnowledgeDigest cards (spec 018) | **削除**、機能は InterestingNextSection に統合 |

## Empty State

各 section が独立に empty state 表示:
- `RecentArticlesSection`: 新規 install + cache empty → 「最近の記事はまだありません ✨ 記事を共有してみよう」
- `InterestingNextSection`: ConceptPage 0 + KnowledgeDigest 0 → 「もう少し記事を保存すると、ここに整理されます」
- `FollowingPeopleSection`: isFollowing 0 → 「気になる人物やモノをフォローすると、ここに集まります」

## V3 Migration Tooltip

```swift
.overlay(alignment: .top) {
    if showV3MigrationTooltip {
        V3MigrationTooltip(onDismiss: {
            UserDefaults.standard.set(true, forKey: "spec056_v3_migrated")
            showV3MigrationTooltip = false
        })
    }
}
.onAppear {
    if !UserDefaults.standard.bool(forKey: "spec056_v3_migrated") {
        showV3MigrationTooltip = true
    }
}
```

## アクセシビリティ

- `tab.knowledgeClip` — タブ識別子
- `toolbar.avatar` — Settings 入口
- `fab.addArticle` — 記事追加 FAB
- 各 section が独自 identifier (`section.recentArticles` 等)

## Performance

- LazyVStack で各 section の lazy 描画
- 表示開始から 1 秒以内に 3 section visible (SC-003)
- 60fps 維持 (SC-008)

## xcstrings 追加

- `knowledgeClip.tab.title` = "知識 Clip"
- `knowledgeClip.section.recentArticles` = "最近の記事"
- `knowledgeClip.section.interestingNext` = "続きが気になるもの"
- `knowledgeClip.section.following` = "追っている人物・モノ"
- `knowledgeClip.actionItems.needsUpdate` = "⚠️ 更新が必要 (%lld)"
- `knowledgeClip.moreLink` = "もっと見る ›"
- `knowledgeClip.empty.recentArticles` = "最近の記事はまだありません ✨"
- `knowledgeClip.empty.interestingNext` = "もう少し記事を保存すると、ここに整理されます"
- `knowledgeClip.empty.following` = "気になる人物やモノをフォローすると、ここに集まります"
- `knowledgeClip.v3.tooltip.title` = "タブが新しくなりました ✨"
- `knowledgeClip.v3.tooltip.body` = "知識 Clip / ライブラリ / AI チャット の 3 つにまとめました"
