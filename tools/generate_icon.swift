#!/usr/bin/env swift
//
//  generate_icon.swift
//  KnowledgeTree
//
//  knowledge tree (知積) のアプリアイコンを 1024x1024 PNG で生成。
//  CoreGraphics + CoreText 標準、外部依存ゼロ。
//
//  実行: swift tools/generate_icon.swift
//  出力: KnowledgeTree/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
//
//  デザイン:
//  - 背景: actionBlue (#0A4D8C) のグラデーション (上 → 下、若干明 → 暗)
//  - 中央: 「知」漢字 (Hiragino Sans W7 ボールド、white)
//  - 右上: 緑の小さな葉 (knowledge が育つ象徴)
//

import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// MARK: - Setup

let size: CGFloat = 1024
let outputDir = "KnowledgeTree/Assets.xcassets/AppIcon.appiconset"
let outputPath = "\(outputDir)/AppIcon-1024.png"

// MARK: - Context

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bytesPerRow = Int(size) * 4

guard let context = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Failed to create CGContext\n", stderr)
    exit(1)
}

// MARK: - Background gradient (actionBlue 上 → やや暗い 下)

let topColor = CGColor(srgbRed: 16/255, green: 95/255, blue: 170/255, alpha: 1)   // やや明るい actionBlue
let bottomColor = CGColor(srgbRed: 6/255,  green: 50/255,  blue: 105/255, alpha: 1) // 深い navy

let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [topColor, bottomColor] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: size / 2, y: size),
    end: CGPoint(x: size / 2, y: 0),
    options: []
)

// MARK: - 「知」漢字 (中央)

let text = "知" as CFString
let fontSize: CGFloat = 720
let font = CTFontCreateWithName("HiraginoSans-W7" as CFString, fontSize, nil)

let textAttributes: [CFString: Any] = [
    kCTFontAttributeName: font,
    kCTForegroundColorAttributeName: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
]
let attributedString = CFAttributedStringCreate(nil, text, textAttributes as CFDictionary)!
let line = CTLineCreateWithAttributedString(attributedString)
let textBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

// 中央配置
let textX = (size - textBounds.width) / 2 - textBounds.origin.x
// CoreGraphics は origin が左下、漢字は若干上に配置 (光学的バランス)
let textY = (size - textBounds.height) / 2 - textBounds.origin.y - 30

context.textPosition = CGPoint(x: textX, y: textY)
CTLineDraw(line, context)

// MARK: - 装飾: 右上に緑の葉 (knowledge が育つ象徴)

let leafGreen = CGColor(srgbRed: 130/255, green: 200/255, blue: 110/255, alpha: 1)
context.setFillColor(leafGreen)

// シンプルな葉形 (楕円を傾ける)
context.saveGState()
context.translateBy(x: 800, y: 850)
context.rotate(by: -CGFloat.pi / 6)  // -30 度
context.fillEllipse(in: CGRect(x: -50, y: -25, width: 100, height: 50))
context.restoreGState()

// MARK: - 装飾: 左下に小さな粒 (積み重ね = 「積」象徴)

let dotColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.25)
context.setFillColor(dotColor)
let dotPositions: [(CGFloat, CGFloat, CGFloat)] = [
    (140, 220, 18),
    (180, 170, 14),
    (220, 200, 12),
    (165, 130, 10)
]
for (x, y, r) in dotPositions {
    context.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

// MARK: - Output PNG

guard let cgImage = context.makeImage() else {
    fputs("Failed to render image\n", stderr)
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(
    url as CFURL,
    UTType.png.identifier as CFString,
    1, nil
) else {
    fputs("Failed to create destination at \(outputPath)\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(dest, cgImage, nil)
guard CGImageDestinationFinalize(dest) else {
    fputs("Failed to finalize PNG\n", stderr)
    exit(1)
}

print("✅ Generated icon: \(outputPath) (1024x1024)")
