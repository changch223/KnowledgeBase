---
version: alpha
name: KnowledgeTree (知積)
description: A garden-quiet interface where a personal AI grows beside the user. Edge-to-edge light surfaces alternate with parchment to set a reading pace, framed by SF Pro Display + Hiragino headlines with negative letter-spacing and a single Action Blue (#0a4d8c) interactive color. UI chrome recedes so the user's accumulating knowledge can speak — no decorative gradients, no shadows on chrome, only a single soft drop-shadow under KnowledgeMap nodes resting on a surface.

colors:
  primary: "#0a4d8c"
  primary-focus: "#1565b8"
  primary-on-dark: "#3a8eef"
  ink: "#1d1d1f"
  body: "#1d1d1f"
  body-on-dark: "#ffffff"
  body-muted: "#6e6e73"
  ink-muted-80: "#333333"
  ink-muted-48: "#7a7a7a"
  divider-soft: "#f0f0f0"
  hairline: "#e0e0e0"
  canvas: "#ffffff"
  canvas-parchment: "#faf8f3"
  surface-pearl: "#fafafc"
  surface-tag-fill: "#eaeaef"
  surface-chip-translucent: "#d2d2d7"
  surface-knowledge-tile: "#f5f5f7"
  surface-black: "#000000"
  on-primary: "#ffffff"
  on-dark: "#ffffff"

typography:
  hero-display:
    fontFamily: "SF Pro Display, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 34px
    fontWeight: 700
    lineHeight: 1.07
    letterSpacing: -0.34px
  display-lg:
    fontFamily: "SF Pro Display, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 28px
    fontWeight: 600
    lineHeight: 1.14
    letterSpacing: -0.28px
  display-md:
    fontFamily: "SF Pro Text, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 22px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: -0.22px
  hero-counter:
    fontFamily: "SF Pro Display, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 28px
    fontWeight: 700
    lineHeight: 1.0
    letterSpacing: -0.28px
    fontVariantNumeric: "tabular-nums"
  hero-subtitle:
    fontFamily: "SF Pro Text, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 15px
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: -0.15px
  hero-brand:
    fontFamily: "SF Pro Display, system-ui, -apple-system, sans-serif"
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.0
    letterSpacing: 0.06px
    fontStyle: italic
  section-title:
    fontFamily: "SF Pro Display, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 20px
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: -0.2px
  row-title:
    fontFamily: "SF Pro Text, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 17px
    fontWeight: 400
    lineHeight: 1.41
    letterSpacing: -0.374px
  body-strong:
    fontFamily: "SF Pro Text, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 17px
    fontWeight: 600
    lineHeight: 1.24
    letterSpacing: -0.374px
  body:
    fontFamily: "SF Pro Text, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 17px
    fontWeight: 400
    lineHeight: 1.47
    letterSpacing: -0.374px
  caption:
    fontFamily: "SF Pro Text, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.38
    letterSpacing: -0.08px
  caption-strong:
    fontFamily: "SF Pro Text, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 13px
    fontWeight: 600
    lineHeight: 1.31
    letterSpacing: -0.08px
  ai-label:
    fontFamily: "SF Pro Text, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 11px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: 0.066px
  chip-label:
    fontFamily: "SF Pro Text, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1.25
    letterSpacing: 0
  map-node-label:
    fontFamily: "SF Pro Text, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 11px
    fontWeight: 500
    lineHeight: 1.18
    letterSpacing: -0.066px
  fine-print:
    fontFamily: "SF Pro Text, Hiragino Sans, system-ui, -apple-system, sans-serif"
    fontSize: 11px
    fontWeight: 400
    lineHeight: 1.27
    letterSpacing: -0.066px

rounded:
  none: 0px
  xs: 4px
  thumb: 8px
  chip: 12px
  card: 16px
  hero: 20px
  pill: 9999px
  full: 9999px

spacing:
  xxs: 2px
  xs: 4px
  sm: 6px
  md: 8px
  lg: 10px
  xl: 12px
  xxl: 16px
  xxxl: 20px
  section: 24px

components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.body}"
    rounded: "{rounded.pill}"
    padding: 11px 22px
    pressEffect: "scale(0.95)"
  button-primary-focus:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.pill}"
    outline: "2px solid {colors.primary-focus}"
  button-secondary-pill:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.primary}"
    border: "1px solid {colors.primary}"
    typography: "{typography.body}"
    rounded: "{rounded.pill}"
    padding: 11px 22px
  button-utility:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    border: "1px solid {colors.divider-soft}"
    typography: "{typography.caption}"
    rounded: "{rounded.thumb}"
    padding: 8px 14px
  text-link:
    backgroundColor: transparent
    textColor: "{colors.primary}"
    typography: "{typography.body}"
  power-gauge:
    backgroundColor: "{colors.surface-pearl}"
    border: "0.5px solid {colors.hairline}"
    textColor: "{colors.ink}"
    typography: "{typography.hero-counter}"
    rounded: "{rounded.hero}"
    padding: 20px 24px
    height: 180px
    layout: "VStack: hero-counter (記事) → mini-stats cluster (知識 / キーファクト, divider) → hero-brand 'Your AI is growing'"
    pulseEffect: "shadow radius 4 ↔ 12 (ifMotionAllowed)"
  knowledge-map-canvas:
    backgroundColor: "{colors.canvas}"
    rounded: "{rounded.card}"
    padding: 0
    minHeight: 320px
  knowledge-map-node:
    backgroundColor: "{colors.surface-knowledge-tile}"
    border: "1px solid {colors.hairline}"
    textColor: "{colors.ink}"
    typography: "{typography.map-node-label}"
    rounded: "{rounded.full}"
    sizeRange: 40px-100px
    shadow: "rgba(0, 0, 0, 0.10) 0 1px 4px"
    accentBorder: "{colors.primary}"
    fadeInDuration: "0.4s ease (ifMotionAllowed)"
  knowledge-map-edge:
    color: "{colors.divider-soft}"
    strokeWidth: 1px
    style: "solid (no gradient)"
  recent-activity-card:
    backgroundColor: "{colors.surface-pearl}"
    border: "0.5px solid {colors.hairline}"
    textColor: "{colors.ink}"
    typography: "{typography.body-strong}"
    rounded: "{rounded.card}"
    padding: 16px
    width: 200px
    height: 140px
    iconBackgroundColor: "{colors.surface-tag-fill}"
    iconColor: "{colors.primary}"
  article-row:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.row-title}"
    padding: 12px 16px
    leadingAccent: "3px solid {colors.primary} (knowledge succeeded only)"
    layout: "HStack: leading-accent → thumbnail (60×60) → VStack(title / essence / chips / url / ai-badge)"
  ai-badge:
    backgroundColor: "{colors.surface-tag-fill}"
    textColor: "{colors.primary}"
    typography: "{typography.ai-label}"
    rounded: "{rounded.pill}"
    padding: 2px 8px
    icon: "sparkles (SF Symbol)"
  thumbnail:
    backgroundColor: "{colors.surface-tag-fill}"
    rounded: "{rounded.thumb}"
    size: 60px
    fallbackIcon: "doc.text (SF Symbol, color {colors.ink-muted-48})"
  bottom-status-bar:
    backgroundColor: "{colors.canvas-parchment}"
    backdrop: "blur(20px) saturate(180%)"
    textColor: "{colors.ink}"
    typography: "{typography.caption}"
    height: 56px
    padding: 12px 16px
    progressTint: "{colors.primary}"
    layout: "HStack: progress-spinner → VStack(phase-label / article-title) → progress-counter"
  empty-state:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.body-muted}"
    typography: "{typography.section-title}"
    layout: "VStack: icon (48pt) → headline → caption"
    iconAnimation: "scale 0.8 → 1.0 + bob ±0.03 (ifMotionAllowed)"
  search-input:
    backgroundColor: "{colors.canvas}"
    border: "1px solid {colors.hairline}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.thumb}"
    padding: 8px 12px
    height: 36px
    leadingIcon: "magnifyingglass (SF Symbol, {colors.ink-muted-48})"
  tag-chip:
    backgroundColor: "{colors.surface-tag-fill}"
    textColor: "{colors.ink}"
    typography: "{typography.chip-label}"
    rounded: "{rounded.pill}"
    padding: 4px 10px
    removeIcon: "xmark.circle.fill (SF Symbol, {colors.ink-muted-48})"
  entity-chip:
    backgroundColor: "{colors.canvas}"
    border: "1px solid {colors.divider-soft}"
    textColor: "{colors.body-muted}"
    typography: "{typography.chip-label}"
    rounded: "{rounded.chip}"
    padding: 2px 8px
    salienceIndicator: "leading dot ({colors.primary} at salience >= 4)"
  flowing-tags-layout:
    spacing: "{spacing.xs}"
    wrap: "natural multiline"
    alignment: "leading"
  key-fact-row:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    padding: 12px 0
    leadingIcon: "circle.fill ({colors.primary}, 6pt)"
    factTypeLabel: "{typography.ai-label} ({colors.body-muted})"
  knowledge-summary:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.body}"
    typography: "{typography.body}"
    sectionTitle: "{typography.section-title}"
    padding: "0 16px"
    lineSpacing: 4
  related-articles-section:
    backgroundColor: "{colors.canvas}"
    sectionTitle: "{typography.section-title}"
    rowPadding: 8px 0
    rowTitle: "{typography.body-strong}"
    rowMeta: "{typography.caption}"
    divider: "{colors.divider-soft}"
  reader-view:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    maxWidth: 680px
    padding: 16px 20px
    lineSpacing: 8
  reader-toolbar:
    backgroundColor: "{colors.canvas-parchment}"
    backdrop: "blur(20px) saturate(180%)"
    textColor: "{colors.ink}"
    typography: "{typography.caption}"
    height: 44px
    padding: "0 12px"
  enrichment-status-badge:
    backgroundColor: "{colors.surface-tag-fill}"
    textColor: "{colors.body-muted}"
    typography: "{typography.fine-print}"
    rounded: "{rounded.pill}"
    padding: 2px 6px
  tag-input-field:
    backgroundColor: "{colors.canvas}"
    border: "1px solid {colors.hairline}"
    textColor: "{colors.ink}"
    typography: "{typography.caption}"
    rounded: "{rounded.thumb}"
    padding: 6px 10px
    placeholder: "{colors.ink-muted-48}"
  tag-list-row:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    padding: 10px 16px
    countLabel: "{typography.caption} ({colors.body-muted})"
    divider: "{colors.divider-soft}"
---

## Overview

KnowledgeTree (知積) は、ユーザーが Safari で読んだ記事を Share Sheet で保存するだけで、自分専用の AI が静かに育つ iPhone アプリ。インターフェースは **その「育ち」を邪魔せず引き立てる「庭」のような場所** であるべきという設計哲学に立つ。Apple の web デザインから「product-first / UI recedes」の規律を、Apple Health / Weather から「mini-stats cluster / full-bleed surface」の構造を借りつつ、KnowledgeTree 固有の **静かな AI 性格** を表現する。

ライブラリタブ (📚) は記事のリーディング体験、AI ブレインタブ (🧠) は蓄積知識の俯瞰体験。両方とも edge-to-edge の light surface (純白 + parchment) を主軸に、interactive な要素はすべて **single Action Blue** (`{colors.primary}` — #0a4d8c) でのみ表現する。装飾的な gradient は禁止、shadow は KnowledgeMap node が「物理的に庭に置かれている」感覚を出すための **ただ一つ** に限定。

タイポグラフィは SF Pro Display (英) + Hiragino Sans (日) のミックスで、display サイズに negative letter-spacing を効かせて Apple-tight の見え方を再現。日本語は letter-spacing を 0 に保ち、句読点の文字組ルールを尊重する。

**Key Characteristics:**

- AI personality-first presentation; UI recedes so the accumulating knowledge can speak.
- Alternating light surfaces (white ↔ parchment) act as section dividers without borders or shadows.
- Single Action Blue (`{colors.primary}` — #0a4d8c) carries every interactive element. No second brand color, no gradient, no multi-color phase tints.
- Two button grammars: Action Blue pill CTAs (`{rounded.pill}`) and compact utility rects (`{rounded.thumb}`).
- SF Pro Display + SF Pro Text + Hiragino Sans/Mincho fallback — negative letter-spacing at display sizes (`-0.20 → -0.34`) for "Apple-tight" headlines.
- Whisper-soft shadow used **only** under KnowledgeMap nodes resting on the canvas (`rgba(0, 0, 0, 0.10) 0 1px 4px`) — exactly one drop-shadow in the entire system.
- 2-tab navigation: 📚 ライブラリ + 🧠 AI ブレイン. The TabView is the only persistent chrome.
- Two-section rhythm in AI ブレインタブ: PowerGauge (hero counter) → KnowledgeMap (canvas) → RecentActivityCards (horizontal scroll). A predictable pulse from "data" to "exploration" to "narrative."
- Pulsing animations are reserved for ambient state (PowerGauge shadow pulse, EmptyState bob); all are gated by `UIAccessibility.isReduceMotionEnabled` via `DS.Animation.ifMotionAllowed(_:)`.

## Colors

> **Source views analyzed:** spec 008-014 の全 18 view (PowerGaugeCard / KnowledgeMapView / RecentActivityCards / AIBrainView / ArticleRow / ArticleDetailView / ArticleListView / BottomStatusBar / EmptyStateView / EntityChip / FlowingTagsLayout / KeyFactRow / KnowledgeSummaryView / ReaderToolbar / ReaderView / RelatedArticlesSection / TagChip / TagInputField / TagListView / EnrichmentStatusBadge / ThumbnailView)。Color システムは全 view で identical、surface-mode mix のみが view ごとに異なる。

### Brand & Accent

- **Action Blue** (`{colors.primary}` — #0a4d8c): The single brand-level interactive color. All text links, all blue pill CTAs ("再抽出"・"開く"), tag accent borders, AI badge text, focus ring root, and KnowledgeMap node accent stroke. KnowledgeTree's quiet but universal "click me" / "alive AI" signal. Press state shifts via `transform: scale(0.95)` rather than a hex change.
- **Focus Blue** (`{colors.primary-focus}` — #1565b8): A marginally brighter sibling of Action Blue, reserved for the keyboard focus ring on buttons (`outline: 2px solid`).
- **Sky Link Blue** (`{colors.primary-on-dark}` — #3a8eef): Reserved for inline copy on dark surfaces (e.g., future spec 016 dark mode). Currently unused in spec 014, defined for forward compatibility.

### Surface

- **Pure White** (`{colors.canvas}` — #ffffff): The dominant canvas. ArticleListView, ArticleDetailView, ReaderView, KnowledgeMap canvas, search input, and most card backgrounds.
- **Parchment** (`{colors.canvas-parchment}` — #faf8f3): The signature KnowledgeTree off-white — slightly warmer than Apple's #f5f5f7 to evoke the "庭の地面" (garden ground). Used for BottomStatusBar, ReaderToolbar (frosted), AI ブレインタブ background tone.
- **Pearl Surface** (`{colors.surface-pearl}` — #fafafc): A near-white used for PowerGauge card and RecentActivityCards. Lighter than parchment so cards still read as elevated against `{colors.canvas-parchment}`.
- **Knowledge Tile** (`{colors.surface-knowledge-tile}` — #f5f5f7): KnowledgeMap node fill. Sits between canvas (#ffffff) and parchment, providing the faintest "taggable cell" hint without competing with content.
- **Tag Fill** (`{colors.surface-tag-fill}` — #eaeaef): TagChip / AI badge / thumbnail placeholder background. A neutral cool gray that supports both ink text and primary blue text.
- **Translucent Chip Gray** (`{colors.surface-chip-translucent}` — #d2d2d7): The base hex of the translucent chip used over photography (e.g., reader toolbar control circles). In production, applied at ~64% alpha as `rgba(210, 210, 215, 0.64)`.
- **Pure Black** (`{colors.surface-black}` — #000000): Reserved for true void — video player backgrounds (rare). Currently unused in spec 014, defined for forward compatibility.

### Text

- **Near-Black Ink** (`{colors.ink}` — #1d1d1f): The voice of every headline, every body paragraph, and the dark utility chip's fill. Chosen instead of pure black to keep the page feeling photographic rather than printed (Apple convention).
- **Body** (`{colors.body}` — #1d1d1f): Same hex as ink — KnowledgeTree uses one near-black tone for all text on light surfaces.
- **Body Muted** (`{colors.body-muted}` — #6e6e73): Secondary copy (essence preview, captions, RecentActivityCard sub-text, EmptyState description). Apple system gray equivalent.
- **Ink Muted 80** (`{colors.ink-muted-80}` — #333333): Body text on the white pearl button surface — slightly softer than pure black.
- **Ink Muted 48** (`{colors.ink-muted-48}` — #7a7a7a): Disabled button text, fine-print, search placeholder, thumbnail fallback icon.
- **Body On Dark** (`{colors.body-on-dark}` — #ffffff): Reserved for future dark mode (spec 016 候補).

### Hairlines & Borders

- **Divider Soft** (`{colors.divider-soft}` — #f0f0f0): The "border" tone on entity chips and section dividers. Functions as a ring shadow rather than a hard line. In production, often applied as `rgba(0, 0, 0, 0.06)` for a softer feel.
- **Hairline** (`{colors.hairline}` — #e0e0e0): The 0.5–1px hairline border on PowerGaugeCard, RecentActivityCards, KnowledgeMap node, search input.

### Brand Gradient

**No decorative gradients.** This is non-negotiable. Earlier iterations (spec 014 Phase 3) used an `accentColor → purple` gradient on PowerGauge / KnowledgeMap, but the design system documented here **abolishes** all gradient tokens in favor of solid surfaces + the single accent. KnowledgeTree's identity comes from **the absence of decoration**, not from a signature gradient.

If atmospheric depth is needed in future spec, it MUST come from photographic content (e.g., article OG images), not from CSS-style gradient overlays.

## Typography

### Font Family

- **Display**: `SF Pro Display, Hiragino Sans, system-ui, -apple-system, sans-serif` — Apple's proprietary display face, optimized for sizes ≥ 19px. Defines the voice of every headline. Hiragino Sans handles 日本語 fallback automatically on iOS.
- **Body / UI**: `SF Pro Text, Hiragino Sans, system-ui, -apple-system, sans-serif` — the text-optimized variant used for body copy, captions, buttons, and links below 20px.
- **Mincho fallback (optional)**: Hiragino Mincho ProN for special editorial moments (e.g., quote cards in future spec). Not used in spec 014.

### Hierarchy

| Token | Size | Weight | Line Height | Letter Spacing | Use |
|---|---|---|---|---|---|
| `{typography.hero-display}` | 34px | 700 | 1.07 | -0.34px | NavigationTitle of AI ブレインタブ; large hero headlines |
| `{typography.display-lg}` | 28px | 600 | 1.14 | -0.28px | Section heads; ArticleDetailView title |
| `{typography.display-md}` | 22px | 600 | 1.20 | -0.22px | Sub-section heads (e.g., "関連記事", "知識サマリ") |
| `{typography.hero-counter}` | 28px | 700 | 1.0 | -0.28px (+ tabular-nums) | PowerGauge main counter ("47 記事を吸収済") |
| `{typography.hero-subtitle}` | 15px | 400 | 1.4 | -0.15px | PowerGauge sub-text ("123 知識  ·  450 キーファクト") |
| `{typography.hero-brand}` | 12px | 400 italic | 1.0 | +0.06px | "Your AI is growing" tagline |
| `{typography.section-title}` | 20px | 700 | 1.25 | -0.20px | Detail screen section headers |
| `{typography.row-title}` | 17px | 400 | 1.41 | -0.374px | ArticleRow primary title |
| `{typography.body-strong}` | 17px | 600 | 1.24 | -0.374px | Inline strong emphasis; RecentActivityCard headline |
| `{typography.body}` | 17px | 400 | 1.47 | -0.374px | Default paragraph; ReaderView body; button-primary label |
| `{typography.caption}` | 13px | 400 | 1.38 | -0.08px | Secondary captions, button-utility text, ReaderToolbar |
| `{typography.caption-strong}` | 13px | 600 | 1.31 | -0.08px | Emphasized captions |
| `{typography.ai-label}` | 11px | 600 | 1.20 | +0.066px | AI badge ("AI 生成"); fact-type label |
| `{typography.chip-label}` | 12px | 500 | 1.25 | 0 | TagChip / EntityChip label |
| `{typography.map-node-label}` | 11px | 500 | 1.18 | -0.066px | KnowledgeMap node label inside the circle |
| `{typography.fine-print}` | 11px | 400 | 1.27 | -0.066px | EnrichmentStatusBadge text; legal disclaimers |

### Principles

- **Negative letter-spacing at display sizes.** Every headline at 17px and up carries a slight tracking tighten (`-0.08 → -0.34px`). This produces the iconic "Apple-tight" headline cadence. Never used at 12px or below for English; never used for 日本語 (set to 0 to respect 文字組).
- **Body copy at 17px, not 16px.** KnowledgeTree breaks the SaaS convention and runs paragraph text at 17px (Apple convention). The extra pixel gives the reading pace.
- **Hiragino Sans as automatic 日本語 fallback.** The browser/iOS picks up Hiragino when the rendered codepoint is Japanese; the SF Pro line-height (1.41–1.47) accommodates it without breakage.
- **`tabular-nums` on PowerGauge counter only.** The `hero-counter` token uses `font-variant-numeric: tabular-nums` so digits don't jitter during count-up animation.
- **Weight 500 sparingly used.** Apple's ladder is 300/400/600/700, but KnowledgeTree uses weight 500 deliberately on `{typography.chip-label}` and `{typography.map-node-label}` to give chips/labels a touch more presence without escalating to 600. This is a controlled deviation, not an oversight.
- **Italic only for hero-brand.** "Your AI is growing" is the only italic moment; `{typography.hero-brand}` is the only italic token.
- **Line-height is context-specific.** Display sizes use 1.07–1.25 (tight). Body uses 1.41–1.47. ReaderView body uses 1.47 + 8pt extra `lineSpacing` for editorial reads.

### Note on 日本語 Typography

- **`letter-spacing` is set to 0 for Japanese characters.** Apple-tight tracking only applies to ASCII display sizes; Hiragino's metrics already account for ideographic spacing.
- **句読点 (、 。) handling.** The system relies on iOS's automatic 文字組 (kerning between kana / kanji / punctuation). Do not manually adjust.
- **Mixed-script lines.** When 日本語 + ASCII appear on the same line (common in this app), the SF Pro/Hiragino fallback chain handles per-glyph substitution; no manual font-feature settings needed.
- **`@MainActor` Dynamic Type compliance.** All sizes respect Dynamic Type via `Font.title.bold()`, `.body`, etc. The fixed sizes above are the **default** at the system standard size.

### Note on Font Substitutes (build-time / off-system)

- For non-Apple platforms (build artifacts, web previews, design tools), use **Inter** (Google Fonts, variable) for English and **Noto Sans JP** for Japanese. Both are open-source and the closest visual match.
- Inter at weight 600 with `font-feature-settings: "ss03"` approximates SF Pro's rounded "a" character.
- Nudge `letter-spacing` down by `-0.01em` on display sizes when substituting Inter; Inter's default tracking runs slightly wider than SF Pro.

## Layout

### Spacing System

- **Base unit:** 8px. Sub-base values (2, 4, 6) are used for tight typographic adjustments; structural layout snaps to 8/12/16/20/24.
- **Tokens:** `{spacing.xxs}` 2px · `{spacing.xs}` 4px · `{spacing.sm}` 6px · `{spacing.md}` 8px · `{spacing.lg}` 10px · `{spacing.xl}` 12px · `{spacing.xxl}` 16px · `{spacing.xxxl}` 20px · `{spacing.section}` 24px.
- **Section vertical padding:** `{spacing.section}` (24px) inside a card; AI ブレインタブ inter-section spacing is `{spacing.xxl}` (16px).
- **Card padding:** `{spacing.xxl}` (16px) inside RecentActivityCards; PowerGauge uses 20px × 24px asymmetric.
- **Button padding:** 8px–11px vertical, 14px–22px horizontal.
- **Universal rhythm constants:** the 17px body line-height multiplier (~25px line) defines the page's reading rhythm.

### Grid & Container

- **Max content width:** No fixed max; iPhone full-bleed for tabs, ReaderView caps at 680px on iPad to preserve readability.
- **Column patterns:** Single-column on iPhone for ArticleListView, ArticleDetailView, ReaderView. RecentActivityCards uses horizontal scroll (3 fixed-width cards). KnowledgeMap uses Canvas force-directed layout (no grid).
- **Gutters:** `{spacing.xl}` (12px) between RecentActivityCards horizontal items.

### Whitespace Philosophy

KnowledgeTree's whitespace is the AI's pedestal. Every section begins with at least 16px of air above its headline and 16px below. PowerGauge stands alone with 24px above/below within the card. The inter-row padding in ArticleListView is 12px vertical — generous for finger targets, calm for reading.

The 日本語 reading pace requires slightly more leading than English; line-height 1.47 (SF Pro Text default) accommodates Hiragino's taller mark without crowding.

## Elevation & Depth

| Level | Treatment | Use |
|---|---|---|
| Flat | No shadow, no border | Full-bleed canvas, navigation bar (transparent), body sections |
| Soft hairline | 0.5–1px solid `{colors.hairline}` | PowerGauge / RecentActivityCards / KnowledgeMap node / search input |
| Backdrop blur | `backdrop-filter: blur(20px) saturate(180%)` | BottomStatusBar, ReaderToolbar |
| Knowledge node shadow | `rgba(0, 0, 0, 0.10) 0 1px 4px` | KnowledgeMap node circle (the only true "shadow" in the system) |

**Shadow philosophy.** KnowledgeTree uses **exactly one** drop-shadow, and it is applied to KnowledgeMap nodes resting on the Canvas — never to cards, never to buttons, never to text. Elevation in the UI comes from (a) hairline borders and (b) backdrop-blur on sticky bars. The single shadow is about giving each tag node weight, not about UI hierarchy.

### Decorative Depth

- **Hairlines as elevation.** PowerGauge / RecentActivityCards / KnowledgeMap node use a 0.5–1px `{colors.hairline}` border instead of shadow. The hairline reads as a "container edge" rather than a lifted card.
- **Backdrop-filter blur** on `{component.bottom-status-bar}` and `{component.reader-toolbar}` creates a "floating over content" effect that's functional, not decorative.
- **No drop-shadows on cards.** PowerGauge, RecentActivityCards, EmptyState — none get shadow. This is a Constitution-level rule.

## Shapes

### Border Radius Scale

| Token | Value | Use |
|---|---|---|
| `{rounded.none}` | 0px | Full-bleed sections (no corner rounding) |
| `{rounded.xs}` | 4px | Inline subtle accents (rare) |
| `{rounded.thumb}` | 8px | Thumbnail images, search input, button-utility, tag-input-field |
| `{rounded.chip}` | 12px | EntityChip (the pill-but-not-quite container) |
| `{rounded.card}` | 16px | RecentActivityCards, KnowledgeMap canvas container |
| `{rounded.hero}` | 20px | PowerGaugeCard (the largest card in the system) |
| `{rounded.pill}` | 9999px | Action Blue CTAs, AI badge, TagChip, button-secondary-pill — the signature pill |
| `{rounded.full}` | 9999px / 50% | KnowledgeMap node (perfect circle), circular icon controls |

### Photography & Imagery Geometry

- **Article thumbnails**: 60×60 `{rounded.thumb}` (8px) crops, light neutral background, fallback icon when no OG image. Apple convention.
- **OG hero image** (ArticleDetailView): full-width, 200pt tall, `{rounded.none}` at the top edge (full-bleed) and `{rounded.thumb}` at the bottom. Fade overlay `linear-gradient(to bottom, transparent 60%, {colors.canvas} 100%)` smooths into body content.
- **No rounded full-bleed sections** — sections are rectangular and edge-to-edge; the surface change (canvas ↔ parchment) is the divider.
- **KnowledgeMap node** is the single perfect circle (`{rounded.full}`). All other circular elements are decorative or icon-host.

## Components

### Top Navigation

**TabView** — Persistent 2-tab bar pinned to the bottom (iOS standard). Background uses iOS material; tab item text uses `{typography.caption}`. Two tabs only:
- 📚 ライブラリ (`tab.library`) — SF Symbol `books.vertical`
- 🧠 AI ブレイン (`tab.aibrain`) — SF Symbol `brain`

**NavigationStack** — Each tab embeds a `NavigationStack`. NavigationTitle uses `{typography.hero-display}` (large title mode for AI ブレインタブ, inline for ライブラリタブ).

### Buttons

**`button-primary`** — The signature KnowledgeTree action. Background `{colors.primary}` (Action Blue #0a4d8c), text `{colors.on-primary}` in `{typography.body}` (SF Pro Text 17px / 400), rounded `{rounded.pill}`, padding 11px × 22px. The full-pill radius IS the brand action signal.
- Active state: `transform: scale(0.95)` (the system-wide micro-interaction).
- Focus state: `{component.button-primary-focus}` — 2px solid `{colors.primary-focus}` outline.

**`button-secondary-pill`** — Used as the second CTA in pairings. Background transparent, text `{colors.primary}`, 1px solid `{colors.primary}` border, rounded `{rounded.pill}`, padding 11px × 22px. Reads as a "ghost pill."

**`button-utility`** — Compact actions (e.g., "再抽出", reading mode toggle). Background `{colors.canvas}`, text `{colors.ink}` in `{typography.caption}`, 1px solid `{colors.divider-soft}` border, rounded `{rounded.thumb}` (8px), padding 8px × 14px. Active state shrinks via `transform: scale(0.95)`.

**`text-link`** — Inline body links in `{colors.primary}` (Action Blue). Underline on tap, none at rest.

### Cards & Containers

**`power-gauge`** — The hero card of AI ブレインタブ. Background `{colors.surface-pearl}` (#fafafc), 0.5px solid `{colors.hairline}` border, rounded `{rounded.hero}` (20px), padding 20px × 24px, height 180px. Centered VStack: `hero-counter` (記事数) → mini-stats cluster (知識 / キーファクト separated by Divider, both `tabular-nums`) → `hero-brand` "Your AI is growing" italic. Pulsing shadow (radius 4 ↔ 12, 2s loop) gated by `ifMotionAllowed`. **No gradient, no specular highlight.** The pearl surface + hairline + ambient shadow pulse is the entire effect.

**`knowledge-map-canvas`** — Background `{colors.canvas}` (white), no border, rounded `{rounded.card}` (16px), minHeight 320pt. Contains: SwiftUI Canvas drawing edges (`{component.knowledge-map-edge}`) + node circles (`{component.knowledge-map-node}`). Pinch zoom 0.5x–3x, drag pan supported.

**`knowledge-map-node`** — Background `{colors.surface-knowledge-tile}` (#f5f5f7), 1px solid `{colors.hairline}` border, text `{colors.ink}` in `{typography.map-node-label}`, rounded `{rounded.full}` (perfect circle), size 40px–100px (`log2(articles + 1) * 20`), drop shadow `rgba(0, 0, 0, 0.10) 0 1px 4px` (the system shadow). Tapping pushes a `TagFilteredDestination` onto the navigation stack. New nodes fade in over 0.4s (gated by `ifMotionAllowed`).

**`knowledge-map-edge`** — Solid 1px line in `{colors.divider-soft}` (#f0f0f0) connecting two nodes that share a `KnowledgeEntity`. **No gradient stroke, no curve, no animation** — straight edges, static, Apple-quiet.

**`recent-activity-card`** — Used in horizontal scroll on AI ブレインタブ Section 3. Background `{colors.surface-pearl}` (#fafafc), 0.5px solid `{colors.hairline}` border, rounded `{rounded.card}` (16px), padding `{spacing.xxl}` (16px), fixed width 200pt × height 140pt. Top: `iconBadge` — SF Symbol on a circular background `{colors.surface-tag-fill}` (#eaeaef), icon color `{colors.primary}` (single accent for ALL three cards, no per-card color variation). Below: card title in `{typography.body-strong}`, secondary lines in `{typography.caption}`.

**`article-row`** — Used in ArticleListView. Background `{colors.canvas}`, padding 12px × 16px. Layout: HStack with leading 3px Action Blue accent (visible only when `knowledge.status == .succeeded`, `accessibilityHidden(true)`) → 60×60 thumbnail (`{rounded.thumb}`) → VStack(title in `{typography.row-title}` / essence in `{typography.caption}` / EntityChip row / URL in `{typography.fine-print}` muted / AI badge if knowledge available). Tap presents the ArticleDetailView sheet.

**`ai-badge`** — Inline indicator on ArticleRow when knowledge is available. Background `{colors.surface-tag-fill}` (#eaeaef), text `{colors.primary}` in `{typography.ai-label}`, rounded `{rounded.pill}`, padding 2px × 8px, leading SF Symbol `sparkles` at 11px.

**`thumbnail`** — Background `{colors.surface-tag-fill}` (when no image), 60×60pt, rounded `{rounded.thumb}` (8px). When loaded, displays the OG image cropped square. Fallback shows SF Symbol `doc.text` in `{colors.ink-muted-48}`.

**`bottom-status-bar`** — Floats at the bottom edge during background processing. Background `{colors.canvas-parchment}` at default opacity with `backdrop-filter: blur(20px) saturate(180%)`, height 56px, padding 12px × 16px. Layout: HStack with leading ProgressView (tinted `{colors.primary}` for ALL phases) → VStack(phase label in `{typography.caption-strong}` / article title in `{typography.caption}` truncated) → optional progress counter ("12/47") in `{typography.caption}`. Hidden when `monitor.isIdle`.

**`empty-state`** — Used in ArticleListView and KnowledgeMapView when no data. Background `{colors.canvas}`, text `{colors.body-muted}`. VStack: SF Symbol icon at 48pt → headline in `{typography.section-title}` → caption in `{typography.caption}`. Icon enters with scale 0.8 → 1.0 (0.4s spring) and bobs ±0.03 every 2s. Both gated by `ifMotionAllowed`.

### Inputs & Forms

**`search-input`** — The article list search input. Background `{colors.canvas}`, text `{colors.ink}` in `{typography.body}` (17px), 1px solid `{colors.hairline}` border, rounded `{rounded.thumb}` (8px), padding 8px × 12px, height 36px. Leading icon: SF Symbol `magnifyingglass` in `{colors.ink-muted-48}`.

**`tag-input-field`** — Used inline in ArticleDetailView for adding manual tags. Background `{colors.canvas}`, 1px solid `{colors.hairline}` border, rounded `{rounded.thumb}`, padding 6px × 10px, text `{colors.ink}` in `{typography.caption}`, placeholder `{colors.ink-muted-48}`. On submit, calls `TagStore.addTag` and clears.

Error and validation states are not yet documented in spec 014; future spec.

### Tags & Entities

**`tag-chip`** — Used in ArticleRow / ArticleDetailView / TagListView. Background `{colors.surface-tag-fill}` (#eaeaef), text `{colors.ink}` in `{typography.chip-label}`, rounded `{rounded.pill}`, padding 4px × 10px. Optional trailing remove icon: SF Symbol `xmark.circle.fill` in `{colors.ink-muted-48}`. Tapping pushes `TagFilteredDestination`.

**`entity-chip`** — Used in ArticleRow's top entities row and KnowledgeSummary. Background `{colors.canvas}`, 1px solid `{colors.divider-soft}` border, text `{colors.body-muted}` in `{typography.chip-label}`, rounded `{rounded.chip}` (12px), padding 2px × 8px. When `salience >= 4`, prepend a `{colors.primary}` 4×4pt circle as a leading dot to indicate "AI auto-tag candidate."

**`flowing-tags-layout`** — A custom Layout (spec 008) that wraps tag chips across multiple lines naturally. Spacing `{spacing.xs}` (4px), leading alignment, line break when width exceeded.

### Detail & Reader

**`key-fact-row`** — A single row in the KnowledgeSummary fact list. Background `{colors.canvas}`, padding 12px × 0px, leading dot `{colors.primary}` 6pt fill. Layout: HStack with dot → VStack(fact statement in `{typography.body}` → fact-type label "claim" / "definition" / "event" in `{typography.ai-label}` `{colors.body-muted}`).

**`knowledge-summary`** — The structured AI output container in ArticleDetailView. Background `{colors.canvas}`, section title in `{typography.section-title}`, body in `{typography.body}`, padding `0 16px`, line spacing 4. Sub-sections: 「要約」 + 「キーファクト」 (`KeyFactRow` rows) + 「エンティティ」 (`EntityChip` row).

**`related-articles-section`** — Below KnowledgeSummary, lists articles sharing entities. Background `{colors.canvas}`, section title in `{typography.section-title}`, each row 8px × 0px padding, row title in `{typography.body-strong}`, meta line in `{typography.caption}`, divider `{colors.divider-soft}` between rows.

**`reader-view`** — Edge-to-edge readable mode for body text. Background `{colors.canvas}`, text `{colors.ink}` in `{typography.body}`, max width 680pt (iPad), padding 16px × 20px, line spacing 8 (extra editorial leading). No chrome — only the floating ReaderToolbar.

**`reader-toolbar`** — Floats above ReaderView. Background `{colors.canvas-parchment}` with `backdrop-filter: blur(20px) saturate(180%)`, text `{colors.ink}` in `{typography.caption}`, height 44px, padding `0 12px`. Contains: close button + reading progress + share button (all SF Symbols).

**`enrichment-status-badge`** — Tiny status pill on ArticleRow / ArticleDetailView. Background `{colors.surface-tag-fill}`, text `{colors.body-muted}` in `{typography.fine-print}`, rounded `{rounded.pill}`, padding 2px × 6px. States: "未取得" / "取得中" / "取得失敗".

**`tag-list-row`** — A row in TagListView. Background `{colors.canvas}`, padding 10px × 16px, title in `{typography.body}`, count label in `{typography.caption}` `{colors.body-muted}`, divider `{colors.divider-soft}`.

## Do's and Don'ts

### Do

- Use `{colors.primary}` (Action Blue #0a4d8c) for every interactive element — links, pill CTAs, focus signals, AI badge text, KnowledgeMap node accent, BottomStatusBar progress tint — and **nothing else**. The single accent is non-negotiable.
- Set headlines in `{typography.hero-display}` or `{typography.display-lg}` with negative letter-spacing (`-0.20 → -0.34px`) for ASCII; keep letter-spacing 0 for 日本語 to respect 文字組.
- Run body copy at `{typography.body}` (17px / 400 / 1.47 / -0.374px) — not 16px. The extra pixel defines the brand's reading pace.
- Alternate `{colors.canvas}` and `{colors.canvas-parchment}` for full-bleed section rhythm. The surface change IS the divider.
- Reserve `{rounded.pill}` for the primary blue CTA, AI badge, and TagChip — anything that should read as an "action" or "tag tap-target."
- Apply the single drop-shadow (`rgba(0, 0, 0, 0.10) 0 1px 4px`) **only** to KnowledgeMap nodes — never to cards, buttons, or text.
- Use `transform: scale(0.95)` as the active/press state on every button — it's the system-wide micro-interaction.
- Wrap **every decorative animation** in `DS.Animation.ifMotionAllowed(_:)` so Reduce Motion is respected globally.
- Use `accessibilityHidden(true)` on the leading edge accent and other purely decorative elements that VoiceOver should skip.
- Use SF Pro Display + Hiragino Sans naturally — no manual font-feature settings; iOS handles the script switch.

### Don't

- Don't introduce a second accent color. Every "click me" / "AI alive" signal is `{colors.primary}` (Action Blue).
- Don't add gradients **anywhere** — no AI brand gradient, no phase tint gradient, no full-bleed gradient. Atmospheric depth comes from solid surface alternation only.
- Don't add shadows to cards, buttons, or text — shadow is reserved for KnowledgeMap nodes.
- Don't set body copy at weight 500 unless on `chip-label` or `map-node-label`. Default body is 400; strong inline is 600; display is 600–700.
- Don't round full-bleed sections — sections are rectangular; the surface change is the divider.
- Don't tighten line-height below 1.41 for body copy — the editorial leading is part of the brand.
- Don't mix radius grammars — use `{rounded.thumb}` for compact utility, `{rounded.card}` for cards, `{rounded.hero}` for the PowerGauge, `{rounded.pill}` for actions/chips, and `{rounded.full}` only for KnowledgeMap nodes.
- Don't use multiple colors for `{component.bottom-status-bar}` phase tint — all phases (enrichment / body / knowledge / tagBackfilling) MUST use `{colors.primary}`. Distinguishing by color is information-overload; the phase **label text** carries the meaning.
- Don't apply `letter-spacing` to 日本語 text — it breaks 文字組 and reads as amateur.
- Don't omit `ifMotionAllowed` guards on decorative animations. Reduce Motion is non-negotiable.
- Don't use SF Pro Display for body sizes (< 19px) — the metrics are wrong; switch to SF Pro Text.

## Responsive Behavior

KnowledgeTree is iPhone-first; iPad uses adaptive layout with size class. No web breakpoints.

### iPhone Breakpoints

| Name | Width | Key Changes |
|---|---|---|
| Small phone | 320–374px (iPhone SE) | TagChip wraps earlier; PowerGauge mini-stats stack vertically; AI ブレインタブ scroll indicator stays hidden |
| Phone | 375–392px (iPhone 14, 15) | Default layout |
| Standard phone | 393–428px (iPhone 17 Pro) | Default layout |
| Large phone | 429–480px (iPhone Plus / Pro Max) | More room for KnowledgeMap; nodes can expand to full 100pt |

### iPad

iPad uses **adaptive layout via `UITraitCollection.horizontalSizeClass`**. Views automatically:
- ReaderView caps at 680pt max width, centered.
- ArticleListView maintains single-column on `.compact`, switches to 2-column grid on `.regular` (future spec consideration).
- AI ブレインタブ keeps single-column flow; KnowledgeMap canvas expands to fill available width.

iPad split view, slide-over, and Stage Manager are explicitly not designed for in spec 014; future spec.

### Touch Targets

- Minimum 44 × 44pt (Apple HIG). `{component.button-primary}` lands at ~44 × 100pt with the full-pill radius making the visible hit area more generous than the label suggests.
- KnowledgeMap nodes are 40–100pt circles; the smallest (40pt) is below the 44pt minimum but compensates with `contentShape(Circle())` for an enlarged hit area.
- TagChip / EntityChip have 24pt height; tap target is extended via `frame(minHeight: 44)` invisible overlay.
- Bottom navigation tab items are platform-default (~50pt height).

### Collapsing Strategy

- **Tab bar**: Always visible (iOS standard); never collapses.
- **Search bar**: Searchable modifier on ArticleListView; collapses into navigation bar at scroll.
- **BottomStatusBar**: Auto-shows when `monitor.isIdle == false`, slides up with `DS.Animation.statusBar` spring; disappears when idle.

### Image Behavior

- ArticleRow thumbnails: 60×60 fixed, square crop, lazy-loaded via `AsyncImage`.
- ArticleDetailView OG image: full-width, 200pt fixed height, fade overlay at bottom edge for visual hand-off into body content.
- KnowledgeMap canvas: vector-only, no raster images.

## Iteration Guide

1. Focus on ONE component at a time. Reference its YAML key directly (`{component.power-gauge}`, `{component.knowledge-map-node}`).
2. Variants of an existing component (`-focus`, `-active`) live as separate entries in `components:`.
3. Use `{token.refs}` everywhere — never inline hex.
4. Never document hover. Default and Active/Pressed states only (touch UI).
5. Display headlines stay SF Pro Display 600–700 with negative letter-spacing. Body stays SF Pro Text 400 at 17px. The boundary is unbreakable.
6. The single drop-shadow (`rgba(0, 0, 0, 0.10) 0 1px 4px`) is reserved for KnowledgeMap nodes only.
7. When in doubt about emphasis: alternate surface (canvas → parchment) before adding chrome.
8. Wrap every decorative animation in `DS.Animation.ifMotionAllowed(_:)` — no exceptions.
9. 日本語 text: letter-spacing 0, line-height 1.41+, never bold below caption-strong.

## Known Gaps

- **Dark mode tokens** are not surfaced. The current system relies on `Color(.systemBackground)` adaptive behavior; explicit dark-mode token pairs (e.g., `canvas-dark`, `ink-on-dark`) are deferred to a future spec.
- **Error / validation states** were not surfaced on the analyzed views; only the neutral search input and tag input field are documented.
- **iPad split-view / Stage Manager** layouts are not designed. The system currently relies on adaptive size class only.
- **Animation timing functions** for spec 014's redesigned visuals are documented in `DS.Animation` (Swift), but a YAML-level mapping into this DESIGN.md is not yet authored.
- **Localization for non-Japanese languages** (English UI fallback, Chinese, Korean) is not designed; current strings are 日本語-first per Constitution Principle VII.
- **Apple Liquid Glass** (iOS 26's translucent material refresh) is not yet adopted. Planned to evaluate after iOS 26 final release; expected to require zero work for tab bar, possible work for `bottom-status-bar` and `reader-toolbar`.
- **shapeof.ai's 4 patterns** (Ambient / Adaptive / Agentic / Zero-UI) are mentioned as a future evaluation framework for AI features (spec 015+); not formally encoded as design tokens here.

## Migration Notes

This DESIGN.md describes the **target state**. The current implementation (`KnowledgeTree/DesignSystem.swift` as of spec 014 / commit `b78c2f4`) deviates from this target in the following ways. Migration is planned for **spec 015** (not yet started).

### Tokens to be removed (spec 015)

From `enum DS { Color { ... } }`:
- `aiBrandStart` (= `Color.accentColor.opacity(0.15)`)
- `aiBrandEnd` (= `Color.purple.opacity(0.15)`)
- `aiBrandEdge` (= `Color.secondary.opacity(0.25)`)
- `aiBrandNodeFill` (= `Color.accentColor.opacity(0.15)`)
- `aiBrandNodeStroke` (= `Color.accentColor.opacity(0.55)`)
- `phaseEnrichment` (= `Color.secondary`)
- `phaseBody` (= `Color.blue`)
- `phaseKnowledge` (= `Color.purple`)
- `phaseTagging` (= `Color.green`)

### Tokens to be added (spec 015)

To `enum DS { Color { ... } }`:
- `actionBlue` = `Color(red: 0.039, green: 0.302, blue: 0.549)` (#0a4d8c)
- `actionBlueFocus` = `Color(red: 0.082, green: 0.396, blue: 0.722)` (#1565b8)
- `parchment` = `Color(red: 0.980, green: 0.973, blue: 0.953)` (#faf8f3)
- `knowledgeTile` = `Color(red: 0.961, green: 0.961, blue: 0.969)` (#f5f5f7)
- `tagFill` = `Color(red: 0.918, green: 0.918, blue: 0.937)` (#eaeaef)

### View migrations (spec 015)

| View | Current | Target (per DESIGN.md) |
|---|---|---|
| **PowerGaugeCard** | 4-layer ZStack (`.ultraThinMaterial` + AI gradient + specular highlight + content) + scale jitter pulse | Single layer: `surface-pearl` background + hairline border + `actionBlue` shadow pulse only. No gradient, no specular highlight |
| **KnowledgeMapView** | linearGradient stroke edges + radial gradient nodes + capsule label pills | Solid `divider-soft` straight-line edges + solid `surface-knowledge-tile` fill nodes + plain text labels (no pill background). The single drop-shadow stays |
| **RecentActivityCards** | Per-card color icon (accentColor / green / purple) | All three cards use `actionBlue` icon on `tag-fill` circular background. Identical color across cards |
| **AIBrainView** | full-bleed AI brand gradient (300pt) + large title | No gradient. Plain `canvas-parchment` background with optional 0.5px hairline at section breaks |
| **BottomStatusBar** | 4 phase tint colors (secondary / blue / purple / green) for `phaseEnrichment` / `phaseBody` / `phaseKnowledge` / `phaseTagging` | Unified `actionBlue` progress tint for ALL phases. Phase label text alone differentiates |
| **ArticleRow** | `aiBrandEnd` leading edge accent | `actionBlue` leading edge accent (visually similar but token-correct) |

### Implementation strategy (spec 015 outline)

1. Add new tokens to `DesignSystem.swift` alongside existing (no deletion yet).
2. Migrate one view at a time: PowerGaugeCard → KnowledgeMapView → RecentActivityCards → AIBrainView → BottomStatusBar → ArticleRow.
3. Delete deprecated tokens from `DesignSystem.swift`.
4. Update `DesignSystemTests` (if any) and run regression suite.
5. Take iPhone 17 Pro screenshots and compare to DESIGN.md target descriptions.
6. PR with full Constitution Check.

Estimated scope: ~10 files modified, ~150–250 lines net change (additions + deletions cancel partially).

### Backward compatibility

This migration is purely visual; no `@Model` / Schema / Service / data-layer changes. All 66 existing unit tests should pass without modification. UI tests using `accessibilityIdentifier` are unaffected.
