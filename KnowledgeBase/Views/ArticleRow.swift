//
//  ArticleRow.swift
//  KnowledgeTree
//
//  spec 001-003 — タイトル / URL / サムネイル / enrichment summary / status badge
//  spec 004 — essence + entity chips (上位 3) + 「AI 生成」ラベルを追加
//

import SwiftUI

struct ArticleRow: View {
    /// SwiftData @Model は Observation framework に乗っているため、
    /// `@Bindable` で受けると body 内で読んだ relationship target のプロパティ
    /// (article.enrichment.canonicalTitle 等) も Observation tracking 対象になる。
    /// これが SwiftData + SwiftUI の正規な観察手段。
    @Bindable var article: Article
    /// transitive observation が効かない場合のフォールバック refresh tick。
    var refreshTick: Int = 0
    /// spec 008: 検索結果モード時のクエリ文字列。空文字なら通常表示。
    var searchQuery: String = ""

    /// spec 008: 検索結果ハイライト (マッチ行を行末に追加表示)
    private var searchHighlight: SearchHighlight? {
        SearchHighlighter.highlight(article: article, query: searchQuery)
    }

    /// 共有時のタイトル (Article.title) を優先。
    /// 共有時のタイトルが空 / プレースホルダの場合のみ canonicalTitle にフォールバック。
    /// Why: 共有時にユーザーが見たタイトルが保存意図に最も近い。
    /// canonicalTitle は HTML <title> のまま (例: 「KFC」) で情報量が落ちる場合があるため。
    private var displayTitle: String {
        TitleCleaner.clean(rawDisplayTitle, host: TitleCleaner.webHost(of: article.url))
    }

    private var rawDisplayTitle: String {
        let shareTitle = article.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !shareTitle.isEmpty, shareTitle != article.url {
            return shareTitle
        }
        if let canonical = article.enrichment?.canonicalTitle, !canonical.isEmpty {
            return canonical
        }
        return article.title
    }

    private var enrichmentSummaryText: String? {
        guard let s = article.enrichment?.summary, !s.isEmpty else { return nil }
        return s
    }

    private var knowledgeAvailable: Bool {
        guard let knowledge = article.extractedKnowledge else { return false }
        return knowledge.status == .succeeded || knowledge.status == .partiallySucceeded
    }

    private var essenceText: String? {
        guard knowledgeAvailable,
              let essence = article.extractedKnowledge?.essence,
              !essence.isEmpty
        else { return nil }
        return essence
    }

    /// spec 103: 知識抽出が未完 (pending / extracting) のとき 2 行目に「整理中…」を出す。
    private var isOrganizing: Bool {
        guard !FeedBuilder.isProcessingComplete(article) else { return false }
        switch article.extractedKnowledge?.status {
        case .pending, .extracting: return true
        default: return false
        }
    }

    private var sourceLabelText: String {
        ArticleSourceLabel.label(for: article.url).localizedText
    }

    var body: some View {
        HStack(spacing: 0) {
            // Leading edge accent: knowledge 完了記事のみ表示
            if knowledgeAvailable {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DS.Color.sumiInk)
                    .frame(width: 3)
                    .padding(.trailing, DS.Spacing.sm)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(alignment: .top, spacing: DS.Spacing.xl) {
                    thumbnailOrPlaceholder

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(displayTitle)
                            .font(DS.Typography.rowTitle)
                            .fontDesign(.serif)
                            .lineLimit(2)

                        if let essence = essenceText {
                            Text(essence)
                                .font(.caption)
                                .foregroundStyle(DS.Color.textEmphasis)
                                .lineLimit(2)
                        } else if isOrganizing {
                            Text("article.row.organizing")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        } else if let summary = enrichmentSummaryText {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        HStack(spacing: DS.Spacing.sm) {
                            if !sourceLabelText.isEmpty {
                                Text(sourceLabelText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: DS.Spacing.sm)
                            Text(SavedAtFormatter.format(article.savedAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .accessibilityIdentifier("articleRowSavedAt")
                        }
                    }

                    Spacer(minLength: 0)

                    if let enrichment = article.enrichment {
                        EnrichmentStatusBadge(status: enrichment.status)
                    }
                }

                // spec 008: 検索結果モード時のハイライト excerpt 行
                if let highlight = searchHighlight {
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Text(highlight.fieldName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 60, alignment: .leading)
                        Text(highlight.excerpt)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    .accessibilityIdentifier("searchHighlight")
                }
            }
            .padding(.vertical, DS.Spacing.xs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(combinedAccessibilityLabel)
        .id(refreshTick)
    }

    /// サムネイル URL なし時は doc.text プレースホルダーで左列アンカーを統一
    private var thumbnailOrPlaceholder: some View {
        Group {
            if article.enrichment?.ogImageURL != nil {
                ThumbnailView(urlString: article.enrichment?.ogImageURL)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.thumb)
                        .fill(DS.Color.overlaySubtle)
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            }
        }
    }

    private var combinedAccessibilityLabel: String {
        var parts: [String] = [displayTitle]
        if let essence = essenceText {
            parts.append(essence)
        } else if isOrganizing {
            parts.append(String(localized: "article.row.organizing"))
        } else if let summary = enrichmentSummaryText {
            parts.append(summary)
        }
        if !sourceLabelText.isEmpty { parts.append(sourceLabelText) }
        parts.append(SavedAtFormatter.accessibilityText(article.savedAt))
        return parts.joined(separator: ", ")
    }
}

/// spec 016: ArticleRow.savedAt 表示用 helper。
/// 今日 / 昨日 は相対 + 時刻、7 日以内は「N 日前」、それ以上は「YYYY/MM/DD」。
/// `now` 引数は test で時刻注入できるよう default `.now`。
enum SavedAtFormatter {
    private static let calendar: Calendar = .current

    private static func timeString(_ date: Date, locale: Locale) -> String {
        let f = DateFormatter()
        f.locale = locale
        // ja は従来どおり "09:15" (template だと "9:15" になり桁が揃わない)。
        // 他ロケールは端末の 12/24 時間設定に従う (en_US なら "9:15 AM")。
        if locale.language.languageCode == .japanese {
            f.dateFormat = "HH:mm"
        } else {
            f.setLocalizedDateFormatFromTemplate("jmm")
        }
        return f.string(from: date)
    }

    private static func dayWord(_ day: Int, locale: Locale) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = locale
        f.dateTimeStyle = .named
        f.unitsStyle = .short
        f.formattingContext = .beginningOfSentence
        var c = DateComponents()
        c.day = day
        return f.localizedString(from: c)
    }

    static func format(_ date: Date, now: Date = .now, locale: Locale = .autoupdatingCurrent) -> String {
        // spec 019 fix: Calendar.isDateInToday/isDateInYesterday はシステム時刻固定で
        // now 引数を尊重しない。test 決定論性のため自前で「同日 / 前日」判定する。
        let nowDay = calendar.dateComponents([.year, .month, .day], from: now)
        let dateDay = calendar.dateComponents([.year, .month, .day], from: date)
        if nowDay.year == dateDay.year, nowDay.month == dateDay.month, nowDay.day == dateDay.day {
            return dayWord(0, locale: locale) + " " + timeString(date, locale: locale)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
            let yDay = calendar.dateComponents([.year, .month, .day], from: yesterday)
            if yDay.year == dateDay.year, yDay.month == dateDay.month, yDay.day == dateDay.day {
                return dayWord(-1, locale: locale) + " " + timeString(date, locale: locale)
            }
        }
        let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if daysAgo >= 0 && daysAgo <= 7 {
            let r = RelativeDateTimeFormatter()
            r.locale = locale
            r.unitsStyle = .short
            return r.localizedString(for: date, relativeTo: now)
        }
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("yMMdd")
        return f.string(from: date)
    }

    static func accessibilityText(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateStyle = .long
        f.timeStyle = .short
        let formatted = f.string(from: date)
        return String(localized: "savedAt.accessibility \(formatted)")
    }
}
