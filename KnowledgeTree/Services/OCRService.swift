//
//  OCRService.swift
//  KnowledgeTree
//
//  spec 091 ④ — 画像から文字を抽出 (OCR)。Vision VNRecognizeTextRequest。
//  アプリ target 専用 (UIKit / Vision 依存)。抽出テキストは RawArticleIntake で
//  source: .image の raw article として取り込む。
//

import Foundation
import Vision
#if canImport(UIKit)
import UIKit
#endif

protocol OCRServicing: Sendable {
    /// 画像データから認識テキストを返す (失敗・文字なしは空文字)。
    func recognizeText(in imageData: Data) async -> String
}

struct VisionOCRService: OCRServicing {
    func recognizeText(in imageData: Data) async -> String {
        await withCheckedContinuation { continuation in
            // perform は同期 + 重いのでバックグラウンドで実行 (main を塞がない)。
            DispatchQueue.global(qos: .userInitiated).async {
                #if canImport(UIKit)
                guard let cgImage = UIImage(data: imageData)?.cgImage else {
                    continuation.resume(returning: ""); return
                }
                #else
                continuation.resume(returning: ""); return
                #endif

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["ja-JP", "en-US"]
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: lines.joined(separator: "\n"))
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
