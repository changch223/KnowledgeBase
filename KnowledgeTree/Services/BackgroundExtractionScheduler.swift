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
    /// spec 042: ConceptPage 再合成専用 BGTask 識別子。chunkedKnowledgeExtraction と並行で動作。
    static let conceptResynthesisTaskIdentifier = "app.KnowledgeTree.conceptResynthesis"
    /// spec 058: 週 1 Lint loop (整理 / 削除 / リンク強化 / 再分類 / SavedAnswer auto-refresh)。
    static let weeklyLintTaskIdentifier = "app.KnowledgeTree.weeklyLint"

    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "background")

    /// bootstrap で inject される。runner / queue が無いと handler は no-op で完了。
    var runnerProvider: (@MainActor () -> BackgroundExtractionRunner?)?
    var queueProvider: (@MainActor () -> BackgroundExtractionQueueProtocol?)?
    /// spec 042: ConceptSynthesisService の inject (resynthesizeAllStale を BGTask で呼ぶ)。
    var conceptSynthesisProvider: (@MainActor () -> ConceptSynthesisServiceProtocol?)?
    /// spec 058: LintEngine の inject (週 1 Lint loop を BGTask で呼ぶ)。
    var lintEngineProvider: (@MainActor () -> LintEngineProtocol?)?

    private var didRegister = false
    private var didRegisterConceptTask = false
    private var didRegisterWeeklyLintTask = false

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

    /// spec 042: ConceptPage 再合成用 BGTask handler 登録。
    /// App.init() で 1 回だけ呼ぶ。chunked extraction とは別 identifier で並行動作。
    /// 1 回の起動で fetchLimit=5 件 (FoundationModelsConceptSynthesisService 内部) のみ処理 → 時間制限内に収める。
    func registerConceptResynthesisHandler() {
        guard !didRegisterConceptTask else { return }
        didRegisterConceptTask = true

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.conceptResynthesisTaskIdentifier,
            using: nil
        ) { [weak self] task in
            Task { @MainActor [weak self] in
                await self?.handleConceptResynthesisTask(task)
            }
        }

        logger.notice("BG scheduler: registered handler for \(Self.conceptResynthesisTaskIdentifier, privacy: .public)")
    }

    /// spec 058: 週 1 Lint loop BGTask handler 登録。
    /// App.init() で 1 回だけ呼ぶ。
    /// 1 回の起動で 6 step Lint loop 全実行 (30 秒以内、1000 article 規模想定)。
    func registerWeeklyLintHandler() {
        guard !didRegisterWeeklyLintTask else { return }
        didRegisterWeeklyLintTask = true

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.weeklyLintTaskIdentifier,
            using: nil
        ) { [weak self] task in
            Task { @MainActor [weak self] in
                await self?.handleWeeklyLintTask(task)
            }
        }

        logger.notice("BG scheduler: registered handler for \(Self.weeklyLintTaskIdentifier, privacy: .public)")
    }

    /// spec 058: 次回週 1 Lint BGTask を「次の日曜 3 AM」に予約。
    /// expirationHandler / 完了時に次回分を chain submit する。
    func scheduleNextWeeklyLint() async {
        let request = BGAppRefreshTaskRequest(identifier: Self.weeklyLintTaskIdentifier)
        request.earliestBeginDate = Self.nextSundayAt3AM()
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.notice("BG scheduler: submitted weekly lint request for \(request.earliestBeginDate?.description ?? "nil", privacy: .public)")
        } catch {
            logger.error("BG scheduler: weekly lint submit failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// 次の日曜日 3 AM (local time) を計算 (週 1 BGTask の earliestBeginDate)。
    static func nextSundayAt3AM(now: Date = .now, calendar: Calendar = .current) -> Date {
        var components = DateComponents()
        components.weekday = 1  // Sunday (Gregorian)
        components.hour = 3
        components.minute = 0
        components.second = 0
        return calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(7 * 86400)
    }

    /// spec 042: 次回 ConceptPage 再合成 BGTask を 1 時間後に予約。
    /// expirationHandler / 完了時に次回分を chain submit する想定。
    func scheduleNextConceptResynthesis() async {
        let request = BGAppRefreshTaskRequest(identifier: Self.conceptResynthesisTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)  // 1 時間後
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.notice("BG scheduler: submitted concept resynthesis request")
        } catch {
            logger.error("BG scheduler: concept resynthesis submit failed: \(String(describing: error), privacy: .public)")
        }
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

    /// spec 042: ConceptPage 再合成 BGTask handler。
    /// fetchLimit=5 件処理 → 次回分を 1 時間後に submit。
    private func handleConceptResynthesisTask(_ task: BGTask) async {
        logger.notice("BG scheduler: concept resynthesis handler invoked")

        guard let synthesisService = conceptSynthesisProvider?() else {
            logger.error("BG scheduler: concept synthesis service not bound, completing with failure")
            task.setTaskCompleted(success: false)
            return
        }

        task.expirationHandler = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.scheduleNextConceptResynthesis()
                task.setTaskCompleted(success: false)
            }
        }

        await synthesisService.resynthesizeAllStale()
        task.setTaskCompleted(success: true)

        // 次回分を chain submit (stale ConceptPage が残っていれば次の slot で処理される)
        await scheduleNextConceptResynthesis()
    }

    /// spec 058: 週 1 Lint loop BGTask handler。
    /// LintEngine.runFullLintLoop で 6 step 全実行、次回分を chain submit。
    private func handleWeeklyLintTask(_ task: BGTask) async {
        logger.notice("BG scheduler: weekly lint handler invoked")

        guard let lintEngine = lintEngineProvider?() else {
            logger.error("BG scheduler: lint engine not bound, completing with failure")
            task.setTaskCompleted(success: false)
            // 次回分は予約 (engine が後で bind される場合に備える)
            await scheduleNextWeeklyLint()
            return
        }

        task.expirationHandler = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.scheduleNextWeeklyLint()
                task.setTaskCompleted(success: false)
            }
        }

        let result = await lintEngine.runFullLintLoop()
        logger.notice("BG scheduler: weekly lint done, ops=\(result.totalOperations), elapsed=\(result.elapsedSeconds)s")
        task.setTaskCompleted(success: true)

        // 次回分を chain submit (来週の日曜 3 AM)
        await scheduleNextWeeklyLint()
    }
}
