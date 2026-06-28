//
//  AIPriorityCoordinatorTests.swift
//  KnowledgeTreeTests
//
//  spec 082 — チャット優先コーディネータ (チャット中は裏 AI を一時停止) の検証。
//

import Testing
import Foundation
@testable import KnowledgeBase

@MainActor
struct AIPriorityCoordinatorTests {

    private final class Box { var done = false }

    // (1) チャット非アクティブ時は waitWhileChatActive が即 return
    //     共有 singleton は他テスト (ChatService.send) と競合するため、独立インスタンスで検証。
    @Test func inactiveReturnsImmediately() async {
        let c = AIPriorityCoordinator()
        #expect(c.isChatActive == false)
        await c.waitWhileChatActive()  // 即 return すべき (ブロックしない)
        #expect(c.isChatActive == false)
    }

    // (2) チャット中は待機 → endChat で再開
    @Test func blocksWhileChatActiveThenResumes() async {
        let c = AIPriorityCoordinator()
        c.beginChat()
        #expect(c.isChatActive == true)

        let box = Box()
        let task = Task { @MainActor in
            await c.waitWhileChatActive()
            box.done = true
        }
        // チャット中は裏処理 (task) は再開されない
        await Task.yield()
        #expect(box.done == false)

        c.endChat()
        await task.value
        #expect(box.done == true)
        #expect(c.isChatActive == false)
    }
}
