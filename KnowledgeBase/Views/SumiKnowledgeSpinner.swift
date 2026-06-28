import SwiftUI

/// AI 処理中スピナー — 「知」文字がゆっくりフェードイン/アウト。
/// ProgressView の代わりに使用。
struct SumiKnowledgeSpinner: View {
    @State private var opacity: Double = 0.25
    var size: CGFloat = 20

    var body: some View {
        Text("知")
            .font(.system(size: size, weight: .black, design: .serif))
            .foregroundStyle(DS.Color.sumiInk)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
                ) {
                    opacity = 1.0
                }
            }
            .accessibilityLabel(Text("処理中"))
            .accessibilityHidden(false)
    }
}

/// コンパクト版（インライン用）
struct SumiKnowledgeSpinnerSmall: View {
    var body: some View {
        SumiKnowledgeSpinner(size: 14)
    }
}
