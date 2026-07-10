//
//  WidgetCardSnapshot.swift
//  iKnowWidget
//
//  spec 052 — Widget 表示用の値型 snapshot。
//
//  Widget process から App Group SwiftData container を直接 open して上位 N 件の
//  UnderstandingCard 候補を読み、表示に必要な値だけ struct に snapshot する
//  (defensive snapshot pattern、CloudKit / SwiftData invalidate 中の crash 予防)。
//
//  - AI / Foundation Models は呼ばない (Widget extension 制限)
//  - UnderstandingCardSurfaceService の純粋ロジックを利用 (file membership 共有)
//  - SwiftData fetch は同期 mainContext 呼び出し
//  - 失敗時 (container open 不可 / fetch 失敗) は空配列返却で graceful degrade
//

import Foundation
import SwiftData
import SwiftUI

struct WidgetCardSnapshot: Identifiable, Hashable {
    let id: UUID
    let title: String
    let labelText: String
    let labelColor: Color
    let symbolName: String
    let iconColor: Color
    let deepLinkURL: URL

    /// プレビュー / placeholder 用ダミー。
    static let placeholder = WidgetCardSnapshot(
        id: UUID(),
        title: "Apple Vision Pro",
        labelText: String(localized: "widget.label.newKnowledge"),
        labelColor: .green,
        symbolName: "lightbulb.fill",
        iconColor: .blue,
        deepLinkURL: URL(string: "iknow://learning/card/00000000-0000-0000-0000-000000000000")!
    )
}

// MARK: - Fetch

extension WidgetCardSnapshot {

    /// App Group SwiftData container を開いて、SurfaceService 経由で上位 N 件を取得。
    /// TimelineProvider から `await` で呼ばれる。**async** 必須 — semaphore + MainActor は deadlock するため不可。
    @MainActor
    static func fetchTop(limit: Int) async -> [WidgetCardSnapshot] {
        guard let container = makeReadOnlyContainer() else {
            return []
        }
        let context = container.mainContext
        let service = DefaultUnderstandingCardSurfaceService(context: context)
        let cards = await service.surfaceTopCards(limit: limit)
        return cards.compactMap { card in
            convert(card: card)
        }
    }

    private static func makeReadOnlyContainer() -> ModelContainer? {
        AppGroup.ensureContainerDirectoryExists()
        do {
            return try ModelContainer(
                for: SharedSchema.all,
                configurations: [SharedSchema.sharedConfiguration(cloudKitEnabled: false)]
            )
        } catch {
            return nil
        }
    }

    private static func convert(card: UnderstandingCard) -> WidgetCardSnapshot? {
        let (text, color) = labelInfo(for: card.label)
        let (symbol, iconColor) = symbolInfo(for: card.kind)
        guard let deepLink = URL(string: "iknow://learning/card/\(card.id.uuidString)") else {
            return nil
        }
        return WidgetCardSnapshot(
            id: card.id,
            title: card.titleText,
            labelText: text,
            labelColor: color,
            symbolName: symbol,
            iconColor: iconColor,
            deepLinkURL: deepLink
        )
    }

    private static func labelInfo(for label: UnderstandingCardLabel) -> (String, Color) {
        switch label {
        case .newKnowledge: return (String(localized: "widget.label.newKnowledge"), .green)
        case .needsUpdate:  return (String(localized: "widget.label.needsUpdate"), .orange)
        case .shallow:      return (String(localized: "widget.label.shallow"), .yellow)
        case .deepDive:     return (String(localized: "widget.label.deepDive"), .blue)
        case .review:       return (String(localized: "widget.label.review"), .gray)
        }
    }

    private static func symbolInfo(for kind: UnderstandingCardKind) -> (String, Color) {
        switch kind {
        case .conceptPage: return ("lightbulb.fill", .blue)
        case .savedAnswer: return ("quote.bubble.fill", .orange)
        }
    }
}
