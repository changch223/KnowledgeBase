//
//  AIPriorityCoordinator.swift
//  KnowledgeTree
//
//  spec 082 — チャット応答中は裏の AI 処理 (概念まとめ生成など) を一時停止し、
//  ANE をチャットに最優先で譲るためのコーディネータ。
//
//  背景: 全 Foundation Models 呼び出しは単一の FoundationModelGate (AsyncSemaphore(1)) で
//  直列化されているため、記事保存後の concept synthesis が走っているとチャット回答が
//  その後ろで待たされる。本コーディネータは「チャット応答中」フラグを共有し、
//  裏処理 (resynthesizeAllStale 等) が各 AI 呼び出しの前にここで待機することで、
//  チャット完了まで裏処理を進めない (= チャット最優先)。
//
//  デッドロックしない設計:
//  - チャットは FoundationModelGate を、裏処理は本コーディネータを待つ別レーン。
//  - 裏処理が既に gate を保持中なら、その 1 件分だけチャットが待ってから進む (有界)。
//

import Foundation

@MainActor
final class AIPriorityCoordinator {
    static let shared = AIPriorityCoordinator()

    /// チャット応答 (送信〜回答永続化) が進行中か。
    private(set) var isChatActive = false

    /// チャット完了を待っている裏処理の継続。
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// 通常は `shared` を使う。テストが共有状態の競合を避けて独立検証するために `init()` も許可。
    init() {}

    /// チャット応答開始。以後 `waitWhileChatActive()` はチャット完了までブロックする。
    func beginChat() {
        isChatActive = true
    }

    /// チャット応答終了。待機中の裏処理を全て再開させる。
    func endChat() {
        isChatActive = false
        let resume = waiters
        waiters.removeAll()
        for continuation in resume {
            continuation.resume()
        }
    }

    /// チャット応答中なら完了までブロック、そうでなければ即 return。
    /// 裏処理 (concept synthesis 等) が各 AI 呼び出しの前に呼ぶ。
    func waitWhileChatActive() async {
        guard isChatActive else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}
