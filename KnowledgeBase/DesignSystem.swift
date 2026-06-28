//
//  DesignSystem.swift
//  KnowledgeTree
//
//  Single source of truth for all design tokens.
//  No classes, no SwiftData dependency — compiles in Share Extension too.
//

import SwiftUI

enum DS {

    // MARK: - Color

    enum Color {
        // === spec 015: DESIGN.md target に従った single accent + parchment 系 ===
        // === spec 017: 5 tokens を Color.adaptive 化 (Light/Dark Mode auto adapt) ===

        /// KnowledgeTree Action Blue — single brand-level interactive color。
        /// Light: #0a4d8c (deep blue) / Dark: #3a8eef (DESIGN.md primary-on-dark、Apple Mac ライク)。
        /// 全 view で interactive 要素 (link / pill CTA / focus ring / accent border) に使用。
        static let actionBlue = SwiftUI.Color.adaptive(
            light: SwiftUI.Color(red:  10.0/255.0, green:  77.0/255.0, blue: 140.0/255.0),
            dark:  SwiftUI.Color(red:  58.0/255.0, green: 142.0/255.0, blue: 239.0/255.0)
        )
        /// Focus ring 用。Light: #1565b8 / Dark: #5aa3f5 (Light より明、ring 強調)
        static let actionBlueFocus = SwiftUI.Color.adaptive(
            light: SwiftUI.Color(red:  21.0/255.0, green: 101.0/255.0, blue: 184.0/255.0),
            dark:  SwiftUI.Color(red:  90.0/255.0, green: 163.0/255.0, blue: 245.0/255.0)
        )
        /// Parchment — 庭の地面メタファー。AI ブレインタブ背景・カードに使用。
        /// Light: #faf8f3 (off-white) / Dark: #1c1c1e (iOS .secondarySystemBackground 同等)
        static let parchment = SwiftUI.Color.adaptive(
            light: SwiftUI.Color(red: 250.0/255.0, green: 248.0/255.0, blue: 243.0/255.0),
            dark:  SwiftUI.Color(red:  28.0/255.0, green:  28.0/255.0, blue:  30.0/255.0)
        )
        /// Knowledge tile — KnowledgeMap node fill (廃止 view、alias 経由)。
        /// Light: #f5f5f7 / Dark: #2a2a2c
        static let knowledgeTile = SwiftUI.Color.adaptive(
            light: SwiftUI.Color(red: 245.0/255.0, green: 245.0/255.0, blue: 247.0/255.0),
            dark:  SwiftUI.Color(red:  42.0/255.0, green:  42.0/255.0, blue:  44.0/255.0)
        )
        /// Tag chip / AI badge fill。
        /// Light: #eaeaef / Dark: #2c2c2e (iOS .tertiarySystemFill 相当)
        static let tagFill = SwiftUI.Color.adaptive(
            light: SwiftUI.Color(red: 234.0/255.0, green: 234.0/255.0, blue: 239.0/255.0),
            dark:  SwiftUI.Color(red:  44.0/255.0, green:  44.0/255.0, blue:  46.0/255.0)
        )

        // === spec 014 既存 (維持) ===

        // Surface
        static let surfacePrimary   = SwiftUI.Color(.systemBackground)
        static let surfaceSecondary = SwiftUI.Color(.secondarySystemBackground)

        // Overlay (replaces scattered .opacity(0.06–0.20) literals)
        static let overlaySubtle = SwiftUI.Color.primary.opacity(0.06)
        static let overlayLight  = SwiftUI.Color.primary.opacity(0.10)
        static let overlayMedium = SwiftUI.Color.primary.opacity(0.15)

        // Text
        static let textEmphasis = SwiftUI.Color.primary.opacity(0.85)

        // === spec 015 で「廃止予定」だが廃止 view (PowerGauge / KnowledgeMap / RecentActivityCards) が
        // 参照中なので alias として残す。将来 spec で view 自体削除時に一緒に削除。
        // 全て actionBlue 系に統一されているため、視覚的には Apple-quiet 路線と整合。

        /// @deprecated (alias for spec 014 → 015 migration)
        static let aiBrandStart      = actionBlue.opacity(0.10)
        /// @deprecated
        static let aiBrandEnd        = actionBlue.opacity(0.20)
        /// @deprecated
        static let aiBrandEdge       = SwiftUI.Color.secondary.opacity(0.25)
        /// @deprecated
        static let aiBrandNodeFill   = actionBlue.opacity(0.10)
        /// @deprecated
        static let aiBrandNodeStroke = actionBlue.opacity(0.55)

        /// @deprecated — phase tints は全て actionBlue 統一 (Apple single-accent rule)
        static let phaseEnrichment = actionBlue
        /// @deprecated
        static let phaseBody       = actionBlue
        /// @deprecated
        static let phaseKnowledge  = actionBlue
        /// @deprecated
        static let phaseTagging    = actionBlue
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs:     CGFloat =  2
        static let xs:      CGFloat =  4
        static let sm:      CGFloat =  6
        static let md:      CGFloat =  8
        static let lg:      CGFloat = 10
        static let xl:      CGFloat = 12
        static let xxl:     CGFloat = 16
        static let xxxl:    CGFloat = 20
        static let section: CGFloat = 24
    }

    // MARK: - Corner Radius

    enum Radius {
        static let thumb: CGFloat =  8
        static let chip:  CGFloat = 12
        static let card:  CGFloat = 16
        static let hero:  CGFloat = 20
    }

    // MARK: - Typography

    enum Typography {
        static let heroCounter:    Font    = .title.bold()
        static let heroSubtitle:   Font    = .subheadline
        static let heroBrand:      Font    = .caption.italic()
        static let sectionTitle:   Font    = .title3.bold()
        static let rowTitle:       Font    = .body
        static let aiLabel:        Font    = .caption2
        static let chipLabel:      Font    = .caption
        static let chipIcon:       Font    = .caption2
        static let mapNodeLabel:   Font    = .caption.weight(.medium)
        static let bodyLineSpacing: CGFloat = 8
    }

    // MARK: - Animation

    enum Animation {
        static let standard      = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
        static let counterAppear = SwiftUI.Animation.easeOut(duration: 0.55)
        static let counterUpdate = SwiftUI.Animation.easeOut(duration: 0.35)
        static let pulseLoop     = SwiftUI.Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        static let nodeAppear    = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.75)
        static let statusBar     = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.85)
        static let interactive   = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.9)

        /// Returns nil when Reduce Motion is enabled so callers can skip decorative animations.
        static func ifMotionAllowed(_ anim: SwiftUI.Animation) -> SwiftUI.Animation? {
            UIAccessibility.isReduceMotionEnabled ? nil : anim
        }
    }
}

// MARK: - View Modifiers

extension View {

    /// Card background using the secondary system surface and continuous rounded rect.
    func dsCardBackground(radius: CGFloat = DS.Radius.card) -> some View {
        background(
            DS.Color.surfaceSecondary,
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
    }

    /// AI brand gradient background (accentColor → purple tint).
    func dsAIGradientBackground(radius: CGFloat = DS.Radius.hero) -> some View {
        background(
            LinearGradient(
                colors: [DS.Color.aiBrandStart, DS.Color.aiBrandEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
    }
}

// MARK: - Color Adaptive (spec 017)

extension Color {
    /// Light/Dark Mode で異なる色を返す adaptive Color を生成する (spec 017)。
    /// SwiftUI の Color(uiColor:) と UIKit の UIColor dynamicProvider を組み合わせ、
    /// UITraitCollection.userInterfaceStyle に応じて auto-adapt する。
    ///
    /// - Parameters:
    ///   - light: Light Mode 時の色
    ///   - dark: Dark Mode 時の色
    /// - Returns: SwiftUI が auto-adapt する Color
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
