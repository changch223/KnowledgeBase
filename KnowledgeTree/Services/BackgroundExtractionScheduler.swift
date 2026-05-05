//
//  BackgroundExtractionScheduler.swift
//  KnowledgeTree
//
//  spec 009 — iOS BGTaskScheduler との配線。App.init() で registerHandler() を呼ぶ。
//  queue にエントリがあるとき scheduleBGTaskIfNeeded() で BGProcessingTaskRequest を submit。
//  BGTask handler 起動時に runner.run(articleID:) を呼ぶ。
//

import Foundation
import BackgroundTasks
import os

@MainActor
final class BackgroundExtractionScheduler {
    static let shared = BackgroundExtractionScheduler()
    static let taskIdentifier = "app.KnowledgeTree.chunkedKnowledgeExtraction"

    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "background")

    /// bootstrap で inject される。runner / queue が無いと handler は no-op で完了。
    var runnerProvider: (@MainActor () -> BackgroundExtractionRunner?)?
    var queueProvider: (@MainActor () -> BackgroundExtractionQueueProtocol?)?

    private var didRegister = false

    private init() {}

    /// App.init() で 1 回だけ呼ぶ。複数回呼ぶと iOS が precondition failure を起こすため
    /// didRegister flag で防御。
    func registerHandler() {
        guard !didRegister else { return }
        didRegister = true

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil  // main queue
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor [weak self] in
                await self?.handleTask(processingTask)
            }
        }

        logger.notice("BG scheduler: registered handler for \(Self.taskIdentifier, privacy: .public)")
    }

    /// queue にエントリがある場合に BGProcessingTaskRequest を submit。
    /// 既に submit 済の場合 iOS が上書き (重複 submit OK)。
    func scheduleBGTaskIfNeeded() async {
        guard let queue = queueProvider?() else { return }

        let hasPending = (try? queue.fetchOldestArticleID()) != nil
        guard hasPending else {
            logger.notice("BG scheduler: queue empty, skipping submit")
            return
        }

        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = false
        request.earliestBeginDate = nil

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.notice("BG scheduler: submitted request")
        } catch {
            // simulator / permitted identifier 未登録 / queue 上限 等で失敗するが致命的でない
            logger.error("BG scheduler: submit failed: \(String(describing: error), privacy: .public)")
        }
    }

    func cancelPending() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        logger.notice("BG scheduler: cancelled pending request")
    }

    // MARK: - Private

    private func handleTask(_ task: BGProcessingTask) async {
        logger.notice("BG scheduler: handler invoked")

        guard let queue = queueProvider?(), let runner = runnerProvider?() else {
            logger.error("BG scheduler: runner / queue not bound, completing with failure")
            task.setTaskCompleted(success: false)
            return
        }

        // queue から最古を peek (削除はしない)
        guard let articleID = try? queue.fetchOldestArticleID() else {
            logger.notice("BG scheduler: queue empty, completing")
            task.setTaskCompleted(success: true)
            return
        }

        // expirationHandler 設定
        task.expirationHandler = { [weak self, weak runner] in
            Task { @MainActor [weak self] in
                runner?.cancelCurrent()
                // articleID は queue に残ったまま (runner.run 内で完了時のみ remove)
                await self?.scheduleBGTaskIfNeeded()
                task.setTaskCompleted(success: false)
            }
        }

        // 実処理
        let succeeded = await runner.run(articleID: articleID)
        task.setTaskCompleted(success: succeeded)

        // 次の article がまだ queue にあれば次回予約
        if (try? queue.fetchOldestArticleID()) != nil {
            await scheduleBGTaskIfNeeded()
        }
    }
}
