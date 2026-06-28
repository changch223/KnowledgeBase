import SwiftUI

/// 北斎ロゴから着想した控えめな波形区切り線。
/// 気づく人だけ気づく程度の subtle な表現。
struct SumiWaveDivider: View {
    var body: some View {
        WaveShape()
            .stroke(DS.Color.sumiRule, lineWidth: 0.8)
            .frame(height: 10)
            .padding(.horizontal, DS.Spacing.xxl)
            .accessibilityHidden(true)
    }
}

private struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let amplitude: CGFloat = 2.0
        let cycles: CGFloat = 2.5
        path.move(to: CGPoint(x: 0, y: rect.midY))
        let steps = Int(rect.width)
        for i in 0...steps {
            let x = CGFloat(i)
            let y = rect.midY + amplitude * sin((x / rect.width) * cycles * 2 * .pi)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}
