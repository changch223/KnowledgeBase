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
        labelText: "新しい知識",
        labelColor: .green,
        symbolName: "lightbulb.fill",
        iconColor: .blue,
        deepLinkURL: URL(string: "iknow://learning/card/00000000-0000-0000-0000-000000000000")!
    )
}

// MARK: - Fetch

extension WidgetCardSnapshot {

    /// App Group SwiftData container を開いて、SurfaceService 経由で上位 N 件を取得。
    /// Widget context (@MainActor not necessarily) から呼ばれるため、@MainActor isolated。
    @MainActor
    static func fetchTop(limit: Int) -> [WidgetCardSnapshot] {
        guard let container = makeReadOnlyContainer() else {
            return []
        }
        let context = container.mainContext
        let service = DefaultUnderstandingCardSurfaceService(context: context)

        // SurfaceService は async (await) だが、Task で待たずに同期化するため
        // 同期版 wrapper を呼ぶ (内部は @MainActor fetch のみで I/O 待ちなし)。
        // 注: SurfaceService.surfaceTopCards は async だが実体は同期 fetch なので
        // ここで Task + semaphore で待つのは避け、await を spawn 同期化する。
        let semaphore = DispatchSemaphore(value: 0)
        var result: [UnderstandingCard] = []
        Task { @MainActor in
            result = await service.surfaceTopCards(limit: limit)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + .seconds(2))

        return result.compactMap { card in
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
        case .newKnowledge: return ("新しい知識", .green)
        case .needsUpdate:  return ("更新が必要", .orange)
        case .shallow:      return ("理解が浅い", .yellow)
        case .deepDive:     return ("深掘り余地あり", .blue)
        case .review:       return ("復習", .gray)
        }
    }

    private static func symbolInfo(for kind: UnderstandingCardKind) -> (String, Color) {
        switch kind {
        case .conceptPage: return ("lightbulb.fill", .blue)
        case .savedAnswer: return ("quote.bubble.fill", .orange)
        }
    }
}
