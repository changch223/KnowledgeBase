# Contract: AnswerActionsMenu (long press)

## Purpose

assistant 答え bubble を long press → context menu「保存 / コピー / 共有」表示。
ChatGPT/Gemini と同パターン。

## ChatMessageRow 改修

```swift
struct ChatMessageRow: View {
    let message: ChatMessage
    let streamingTextOverride: String?
    @Environment(ServiceContainer.self) private var services

    var body: some View {
        // ... 既存 bubble UI ...
        bubble
            .contextMenu {
                if message.role == "assistant" {
                    AnswerActionsMenu(
                        question: previousUserQuestion,
                        answer: message.text,
                        citedArticleIDs: message.citedArticleIDs ?? []
                    )
                }
            }
    }
}

struct AnswerActionsMenu: View {
    let question: String
    let answer: String
    let citedArticleIDs: [UUID]

    @Environment(ServiceContainer.self) private var services

    var body: some View {
        Group {
            Button {
                saveExplicit()
            } label: {
                Label("answer.actions.save", systemImage: "star")
            }
            .accessibilityIdentifier("answer.action.save")

            Button {
                UIPasteboard.general.string = answer
            } label: {
                Label("answer.actions.copy", systemImage: "doc.on.doc")
            }
            .accessibilityIdentifier("answer.action.copy")

            ShareLink(item: answer) {
                Label("answer.actions.share", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("answer.action.share")
        }
    }

    private func saveExplicit() {
        guard let service = services.savedAnswerService else { return }
        do {
            _ = try service.saveExplicit(
                question: question,
                answer: answer,
                citedArticleIDs: citedArticleIDs
            )
            // haptic feedback for success (light)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            NSLog("Failed to save: \(error)")
        }
    }
}
```

## SavedAnswerService 追加 API

```swift
// 既存 captureIfWorthy / captureIfWorthyOrReplaceStale は no-op 化 (spec 057)
// 新規 saveExplicit
func saveExplicit(
    question: String,
    answer: String,
    citedArticleIDs: [UUID]
) throws -> SavedAnswer
```

実装は spec 043 の既存 logic 流用 (関連 ConceptPage 解決等)、ただし「引用なしでも保存可能」(50 char + 制約のみ)。

## Test Cases

1. assistant message を long press → context menu 表示
2. 「保存」tap → SavedAnswer 作成 (引用なしでも)
3. 「コピー」tap → UIPasteboard.general.string が answer text に
4. 「共有」tap → ShareSheet 表示 (ShareLink behavior、UI test 困難なので smoke)
5. user message は context menu 表示しない

## Accessibility

- `answer.action.save / copy / share` identifier
- VoiceOver: Label の title 読み上げ

## xcstrings 追加

- `answer.actions.save` = "保存"
- `answer.actions.copy` = "コピー"
- `answer.actions.share` = "共有"
- `answer.actions.saved.haptic` = (使わない、haptic のみ)
