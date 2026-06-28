//
//  SavedAnswerDetailView.swift
//  KnowledgeTree
//
//  spec 043 — SavedAnswer 詳細画面。
//  5 セクション (header / question / answer / cited articles / related concepts)
//  + toolbar (pin Toggle + delete Button)、spec 042 同 @Query live check pattern で
//  削除時 crash 回避。
//

import SwiftUI
import SwiftData

struct SavedAnswerDetailView: View {
    @Bindable var answer: SavedAnswer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ServiceContainer.self) private var services
    @State private var showDeleteConfirm: Bool = false
    /// spec 061 (P1-3): 削除失敗を伝える軽い alert。
    @State private var showDeleteError: Bool = false

    /// 削除時に空になる reactive guard (spec 042 ConceptPageDetailView と同パターン)。
    /// body 冒頭で `isAlive` short-circuit、@Bindable answer のプロパティ参照を一切させず crash 回避。
    @Query private var liveMatches: [SavedAnswer]

    init(answer: SavedAnswer) {
        self.answer = answer
        let id = answer.id
        _liveMatches = Query(filter: #Predicate<SavedAnswer> { $0.id == id })
    }

    /// answer がまだ DB に存在しているか (delete で消えた直後は false)。
    private var isAlive: Bool { !liveMatches.isEmpty }

    /// pin Toggle binding — Service 経由で永続化。
    /// spec 061 (P1-3): 失敗を記録 (非破壊操作なので alert は出さず log のみ、calm UX)。
    private var pinBinding: Binding<Bool> {
        Binding(
            get: { answer.isPinned },
            set: { newValue in
                if let service = services.savedAnswerService {
                    do {
                        try service.setPinned(answer, isPinned: newValue)
                    } catch {
                        AppErrorReporter.shared.report(error, operation: "setPinnedSavedAnswer")
                    }
                } else {
                    answer.isPinned = newValue
                }
            }
        )
    }

    var body: some View {
        // page 消失時の crash 回避: conceptPage プロパティ参照ゼロで Color.clear short-circuit
        if !isAlive {
            Color.clear
                .onAppear { dismiss() }
        } else {
            aliveBody
        }
    }

    @ViewBuilder
    private var aliveBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.section) {
                // spec 045: isStale notice banner (上端、目立つが calm)
                if answer.isStale {
                    staleNoticeBanner
                }
                headerSection
                questionSection
                answerSection
                citedArticlesSection
                relatedConceptsSection
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.vertical, DS.Spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("SavedAnswer.section.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // spec 045: isStale 時のみ「再生成」Button (orange)
            if answer.isStale {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        triggerRegenerate()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.orange)
                    }
                    .accessibilityIdentifier("button.regenerate")
                    .accessibilityLabel(Text("再生成"))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Toggle(isOn: pinBinding) {
                    Image(systemName: answer.isPinned ? "pin.fill" : "pin")
                }
                .toggleStyle(.button)
                .accessibilityIdentifier("savedAnswerDetail_pinToggle")
                .accessibilityLabel(String(localized: "SavedAnswer.detail.pin.toggle"))
            }
            // spec 045: ellipsis menu (更新済としてマーク + 削除)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if answer.isStale {
                        Button {
                            // spec 061 (P1-3): 非破壊操作、失敗は log のみ (calm UX)。
                            do {
                                try services.savedAnswerService?.markFresh(answer)
                            } catch {
                                AppErrorReporter.shared.report(error, operation: "markFreshSavedAnswer")
                            }
                        } label: {
                            Label("更新済としてマーク", systemImage: "checkmark.circle")
                        }
                        .accessibilityIdentifier("button.markFresh")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("SavedAnswer.detail.delete.action", systemImage: "trash")
                    }
                    .accessibilityIdentifier("savedAnswerDetail_deleteButton")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("savedAnswerDetail_menu")
            }
        }
        .alert("SavedAnswer.detail.delete.confirmTitle", isPresented: $showDeleteConfirm) {
            Button("SavedAnswer.detail.delete.action", role: .destructive) {
                // spec 061 (P1-3): 削除失敗を記録 + 表示。
                do {
                    try services.savedAnswerService?.delete(answer)
                    // dismiss は live check (Color.clear.onAppear) が自動で実行
                } catch {
                    AppErrorReporter.shared.report(error, operation: "deleteSavedAnswer")
                    showDeleteError = true
                }
            }
            Button("SavedAnswer.detail.cancel", role: .cancel) {}
        } message: {
            Text("SavedAnswer.detail.delete.confirmMessage")
        }
        // spec 061 (P1-3): 削除失敗の表示
        .alert("error.action.deleteFailed.title", isPresented: $showDeleteError) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text("error.action.deleteFailed")
        }
        .accessibilityIdentifier("savedAnswerDetail_root")
    }

    // MARK: - spec 045 helpers

    private var staleNoticeBanner: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text("更新が必要")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            Text("この答えは保存後に関連記事が追加されています。再生成で最新の AI 答えを得られます。")
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .accessibilityIdentifier("savedAnswer.stale.notice")
        .accessibilityElement(children: .combine)
    }

    private func triggerRegenerate() {
        services.pendingRegenerateRequest = PendingRegenerateRequest(
            question: answer.question,
            originalAnswerID: answer.id
        )
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: DS.Spacing.md) {
            Text(SavedAtFormatter.format(answer.savedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("·")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(answer.savedAutomatically ? "SavedAnswer.detail.auto" : "SavedAnswer.detail.manual")
                .font(.caption)
                .foregroundStyle(.secondary)
            if answer.isPinned {
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("SavedAnswer.detail.pin.toggle", systemImage: "pin.fill")
                    .font(.caption)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(DS.Color.sumiInk)
            }
            Spacer()
        }
        .accessibilityIdentifier("savedAnswerDetail_header")
    }

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("SavedAnswer.detail.question.title")
                .font(.title3.bold())
            Text(answer.question)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .accessibilityIdentifier("savedAnswerDetail_questionSection")
    }

    private var answerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("SavedAnswer.detail.answer.title")
                .font(.title3.bold())
            Text(answer.answer)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(DS.Typography.bodyLineSpacing)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("savedAnswerDetail_answerSection")
    }

    @ViewBuilder
    private var citedArticlesSection: some View {
        let sortedArticles = (answer.citedArticles ?? []).sorted { $0.savedAt > $1.savedAt }
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(String(format: String(localized: "SavedAnswer.detail.citedArticles.title"), sortedArticles.count))
                .font(.title3.bold())
            if sortedArticles.isEmpty {
                Text("SavedAnswer.detail.emptyCitedArticles")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedArticles, id: \.id) { article in
                    NavigationLink(value: article) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(article.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(SavedAtFormatter.format(article.savedAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DS.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .accessibilityIdentifier("savedAnswerDetail_citedArticlesSection")
    }

    @ViewBuilder
    private var relatedConceptsSection: some View {
        let pages = relatedConcepts()
        if !pages.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(String(format: String(localized: "SavedAnswer.detail.relatedConcepts.title"), pages.count))
                    .font(.title3.bold())
                FlowingTagsLayout(spacing: DS.Spacing.sm) {
                    ForEach(pages, id: \.id) { page in
                        NavigationLink(value: ConceptPageDetailDestination(id: page.id)) {
                            Text(page.name)
                                .font(.caption)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Color.tagFill, in: Capsule())
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .accessibilityIdentifier("savedAnswerDetail_relatedConceptsSection")
        }
    }

    /// relatedConceptIDs から ConceptPage を fetch (in-memory)。
    private func relatedConcepts() -> [ConceptPage] {
        guard !answer.relatedConceptIDs.isEmpty else { return [] }
        let ids = Set(answer.relatedConceptIDs)
        let descriptor = FetchDescriptor<ConceptPage>(
            predicate: #Predicate<ConceptPage> { ids.contains($0.id) },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
