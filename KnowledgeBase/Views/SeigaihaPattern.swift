import SwiftUI

/// 青海波（せいがいは）— 北斎の海のスケールモチーフ。
/// 伝統的な波うろこ文様を SwiftUI Canvas で描画。
/// 使用箇所: 空状態の背景、カードウォーターマーク等。
struct SeigaihaPattern: View {
    var opacity: Double = 0.045
    var cellSize: CGFloat = 28

    var body: some View {
        Canvas { ctx, size in
            let r = cellSize / 2
            let rowHeight = cellSize * 0.75

            var row = 0
            var y: CGFloat = -r
            while y < size.height + r {
                let offset: CGFloat = (row % 2 == 0) ? 0 : r
                var x: CGFloat = -r + offset
                while x < size.width + r {
                    // 半円（下向き）を描く
                    var path = Path()
                    path.addArc(
                        center: CGPoint(x: x, y: y + r),
                        radius: r,
                        startAngle: .degrees(180),
                        endAngle: .degrees(0),
                        clockwise: false
                    )
                    ctx.stroke(
                        path,
                        with: .color(DS.Color.sumiInk.opacity(opacity)),
                        lineWidth: 0.6
                    )
                    x += cellSize
                }
                y += rowHeight
                row += 1
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// セクション見出しに北斎スタイルの太細墨ライン装飾を添える。
struct SumiSectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            // 太細2本線（縦）— 北斎の版画の枠線をイメージ
            HStack(spacing: 2) {
                Rectangle()
                    .frame(width: 3, height: 16)
                    .foregroundStyle(DS.Color.sumiInk)
                Rectangle()
                    .frame(width: 1, height: 16)
                    .foregroundStyle(DS.Color.sumiMid)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(DS.Color.sumiInk)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .accessibilityAddTraits(.isHeader)
    }
}

/// 空状態表示 — 小さな波のイラストと一言。
struct SeigaihaEmptyState: View {
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            ZStack {
                SeigaihaPattern(opacity: 0.08, cellSize: 20)
                    .frame(width: 120, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                // 「知」文字を薄く重ねる
                Text("知")
                    .font(.system(size: 40, weight: .black))
                    .fontDesign(.serif)
                    .foregroundStyle(DS.Color.sumiInk.opacity(0.12))
            }
            Text(message)
                .font(.subheadline)
                .fontDesign(.serif)
                .foregroundStyle(DS.Color.sumiMid)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.section * 2)
    }
}
