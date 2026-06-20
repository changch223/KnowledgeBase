//
//  AudioTranscriptionService.swift
//  KnowledgeTree
//
//  spec 092 ⑤ — 音声ファイルを文字に書き起こす。
//  iOS 26 の SpeechTranscriber / SpeechAnalyzer (完全 on-device、長時間対応) を主、
//  使えない端末は SFSpeechRecognizer (on-device) に fallback。
//  spec 093 — 音声の言語自動検知: 候補 locale で冒頭を短く試し、最も認識量の多い
//  言語で本転写する (中国語音声を日本語モデルで誤認識する問題を解消)。
//  アプリ target 専用 (Speech / AVFoundation 依存)。書き起こしは RawArticleIntake で
//  source: .audio の raw article として取り込む。
//

import Foundation
import Speech
import AVFoundation

enum AudioTranscriptionError: Error {
    case unauthorized
    case unavailable
    case noSpeechFound
    case decodeFailed
}

protocol AudioTranscribing: Sendable {
    /// 音声ファイル URL から書き起こしテキストを返す。
    func transcribe(fileURL: URL) async throws -> String
}

struct AudioTranscriptionService: AudioTranscribing {

    /// 検知に使う冒頭の秒数。
    private let detectionPrefixSeconds: Double = 15
    /// 「十分に認識できた」と判断する chars/sec の閾値 (誤 locale はほぼ 0 になる)。
    private let goodScorePerSecond: Double = 1.5

    func transcribe(fileURL: URL) async throws -> String {
        try await ensureAuthorized()

        // 主経路: iOS 26 新 API (on-device、長時間、言語自動検知)。
        if #available(iOS 26.0, *), SpeechTranscriber.isAvailable {
            if let text = try? await transcribeAutoDetect(fileURL: fileURL),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }

        // fallback: 従来 API (on-device、メイン言語固定)。
        let legacy = try await transcribeLegacy(fileURL: fileURL)
        guard !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AudioTranscriptionError.noSpeechFound
        }
        return legacy
    }

    // MARK: - 認証

    private func ensureAuthorized() async throws {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return
        case .notDetermined:
            let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
            }
            guard status == .authorized else { throw AudioTranscriptionError.unauthorized }
        default:
            throw AudioTranscriptionError.unauthorized
        }
    }

    // MARK: - 新 API (iOS 26) + 言語自動検知

    @available(iOS 26.0, *)
    private func transcribeAutoDetect(fileURL: URL) async throws -> String? {
        let locale = await detectBestLocale(for: fileURL)
        return try await transcribeWithAnalyzer(fileURL: fileURL, locale: locale)
    }

    /// 候補 locale で冒頭を短く転写し、最も認識量の多い言語を選ぶ。
    /// メイン言語 (日本語) が十分認識できれば即採用し、他言語モデルの DL を避ける。
    @available(iOS 26.0, *)
    private func detectBestLocale(for fileURL: URL) async -> Locale {
        let candidates = await candidateLocales()
        let fallback = candidates.first ?? Locale(identifier: "ja-JP")

        guard candidates.count > 1,
              let prefixURL = makePrefix(of: fileURL, seconds: detectionPrefixSeconds) else {
            return fallback
        }
        defer { try? FileManager.default.removeItem(at: prefixURL) }

        let prefixSeconds = audioDuration(of: prefixURL) ?? detectionPrefixSeconds
        guard prefixSeconds > 0 else { return fallback }

        var best: (locale: Locale, score: Double)?
        for locale in candidates {
            guard let text = try? await transcribeWithAnalyzer(fileURL: prefixURL, locale: locale) else { continue }
            let chars = text.trimmingCharacters(in: .whitespacesAndNewlines).count
            let score = Double(chars) / prefixSeconds
            if best == nil || score > best!.score {
                best = (locale, score)
            }
            // 優先順 (メイン言語が先頭) で十分なら即採用 → 余計なモデル DL を避ける。
            if score >= goodScorePerSecond {
                return locale
            }
        }
        return best?.locale ?? fallback
    }

    /// 候補 locale (メイン言語 → 端末優先言語 → よく使う言語) を supportedLocale に正規化。
    @available(iOS 26.0, *)
    private func candidateLocales() async -> [Locale] {
        var ids = ["ja-JP"]                                   // メイン言語
        ids += Locale.preferredLanguages                       // 端末の優先言語
        ids += ["en-US", "zh-Hans-CN", "zh-Hant-TW", "ko-KR"]  // よく使う言語

        var result: [Locale] = []
        var seen = Set<String>()
        for id in ids {
            guard let match = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: id)) else { continue }
            if seen.insert(match.identifier(.bcp47)).inserted {
                result.append(match)
            }
        }
        return result
    }

    @available(iOS 26.0, *)
    private func transcribeWithAnalyzer(fileURL: URL, locale: Locale) async throws -> String? {
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)

        // 言語モデル asset を端末にインストール (未導入なら DL、導入済なら nil)。
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let file = try AVAudioFile(forReading: fileURL)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        // 結果列を並行で収集 (start がファイルを流し込み、finishAfterFile で列が終端)。
        async let collected: String = {
            var acc = AttributedString()
            for try await result in transcriber.results {
                acc += result.text
            }
            return String(acc.characters)
        }()

        try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
        return try await collected
    }

    // MARK: - 冒頭抽出 / 長さ

    /// 音声の冒頭 `seconds` 秒を PCM で temp ファイルに書き出す (検知用、AVAssetExportSession 不要)。
    private func makePrefix(of url: URL, seconds: Double) -> URL? {
        guard let input = try? AVAudioFile(forReading: url) else { return nil }
        let format = input.processingFormat
        let total = input.length
        let wantFrames = min(Double(total), seconds * format.sampleRate)
        let frames = AVAudioFrameCount(max(0, wantFrames))
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        do {
            try input.read(into: buffer, frameCount: frames)
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("kt-audio-prefix-\(UUID().uuidString).caf")
            let output = try AVAudioFile(forWriting: tmp, settings: format.settings)
            try output.write(from: buffer)
            return tmp
        } catch {
            return nil
        }
    }

    private func audioDuration(of url: URL) -> Double? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return nil }
        return Double(file.length) / sampleRate
    }

    // MARK: - 従来 API (fallback)

    private func transcribeLegacy(fileURL: URL) async throws -> String {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
            ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else {
            throw AudioTranscriptionError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { cont in
            var resumed = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if !resumed { resumed = true; cont.resume(throwing: error) }
                    return
                }
                guard let result, result.isFinal else { return }
                if !resumed {
                    resumed = true
                    cont.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
