# Contract: PowerGaugeCard

**Created**: 2026-05-05
**File**: `KnowledgeTree/Views/PowerGaugeCard.swift`

## 責務

AI ブレインタブの Section 1。Article 数 / KnowledgeEntity 重複排除数 / KeyFact 数を一目で表示し、起動時カウントアップ + 静かなパルスアニメーションでブランド演出する。固定英文「Your AI is growing」を表示。

## 構造

```swift
struct PowerGaugeCard: View {
    @Query private var articles: [Article]
    @Query private var entities: [KnowledgeEntity]
    @Query private var keyFacts: [KeyFact]

    @State private var animatedArticleCount: Int = 0
    @State private var pulseScale: CGFloat = 1.0

    private var entityCount: Int {
        Set(entities.map { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }).count
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(spacing: 8) {
                Text("\(animatedArticleCount) 記事を吸収済")
                    .font(.title.bold())
                    .contentTransition(.numericText())

                Text("\(entityCount) 知識  ·  \(keyFacts.count) キーファクト")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Your AI is growing")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
            .padding()
        }
        .scaleEffect(pulseScale)
        .accessibilityIdentifier("aibrain.power_gauge")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI パワー: \(articles.count) 記事、\(entityCount) 知識、\(keyFacts.count) キーファクト")
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animatedArticleCount = articles.count
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.02
            }
        }
        .onChange(of: articles.count) { _, newValue in
            withAnimation(.easeOut(duration: 0.4)) {
                animatedArticleCount = newValue
            }
        }
    }
}
```

## 入力契約

- 引数なし
- `@Query` から `Article` / `KnowledgeEntity` / `KeyFact` を全件取得

## 出力契約

- 表示のみ
- ユーザー操作なし (タップしても何も起きない、calm UX)

## アニメーション

| トリガー | 効果 | 持続 | curve |
|---|---|---|---|
| onAppear | animatedArticleCount: 0 → articles.count | 0.6 秒 | easeOut |
| onAppear (繰り返し) | pulseScale: 1.0 ↔ 1.02 | 2.0 秒 / 周期 | easeInOut autoreverses repeatForever |
| articles.count 変化 (新記事) | animatedArticleCount: 旧 → 新 | 0.4 秒 | easeOut |

## アクセシビリティ

| 要素 | accessibilityIdentifier | VoiceOver Label |
|---|---|---|
| Card root | `aibrain.power_gauge` | "AI パワー: N 記事、N 知識、N キーファクト" |

## ローカライゼーション

`Localizable.xcstrings` に追加するキー:

- `"%lld 記事を吸収済"` (引数: animatedArticleCount)
- `"%lld 知識  ·  %lld キーファクト"` (引数: entityCount, keyFacts.count)
- `"AI パワー: %lld 記事、%lld 知識、%lld キーファクト"` (VoiceOver)

**例外** (生英文として spec.md に根拠あり):
- `"Your AI is growing"` (固定英文、ブランド演出。Localizable.xcstrings には英文キーとして追加)

## ローディング状態

- 初回 onAppear 前: `animatedArticleCount = 0` で表示
- onAppear 後 0.6 秒で実数まで count up

## エラーハンドリング

- `@Query` が失敗するケースは ModelContainer レベルでアプリ起動失敗 → 本 view では考慮不要
- 0 件 (新規ユーザー): カウントアップが 0 のまま、3 つの数字すべて 0 表示

## 副作用

- `pulseScale` の `.repeatForever` アニメーションは view 表示中のみ動作
- view が消えると SwiftUI が自動停止 (CPU 影響最小)
- `@Query` 経由で SwiftData の auto-merge を受信 (RefreshTrigger.bump 経由でも更新)

## 依存

- `Article`, `KnowledgeEntity`, `KeyFact` (`@Query`)
- SwiftUI animation (`.contentTransition(.numericText())` for count flicker)
