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
        // Surface
        static let surfacePrimary   = SwiftUI.Color(.systemBackground)
        static let surfaceSecondary = SwiftUI.Color(.secondarySystemBackground)

        // Overlay (replaces scattered .opacity(0.06–0.20) literals)
        static let overlaySubtle = SwiftUI.Color.primary.opacity(0.06)
        static let overlayLight  = SwiftUI.Color.primary.opacity(0.10)
        static let overlayMedium = SwiftUI.Color.primary.opacity(0.15)

        // AI brand gradient (PowerGaugeCard, KnowledgeMapView)
        static let aiBrandStart      = SwiftUI.Color.accentColor.opacity(0.15)
        static let aiBrandEnd        = SwiftUI.Color.purple.opacity(0.15)
        static let aiBrandEdge       = SwiftUI.Color.secondary.opacity(0.25)
        static let aiBrandNodeFill   = SwiftUI.Color.accentColor.opacity(0.15)
        static let aiBrandNodeStroke = SwiftUI.Color.accentColor.opacity(0.55)

        // Processing phase tints (BottomStatusBar)
        static let phaseEnrichment = SwiftUI.Color.secondary
        static let phaseBody       = SwiftUI.Color.blue
        static let phaseKnowledge  = SwiftUI.Color.purple
        static let phaseTagging    = SwiftUI.Color.green

        // Text
        static let textEmphasis = SwiftUI.Color.primary.opacity(0.85)
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
