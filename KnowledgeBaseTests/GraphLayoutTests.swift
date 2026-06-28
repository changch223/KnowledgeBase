//
//  GraphLayoutTests.swift
//  KnowledgeTreeTests
//
//  spec 041 — GraphLayout 純関数 3 ケース。
//

import Testing
import Foundation
import CoreGraphics
@testable import KnowledgeBase

struct GraphLayoutTests {

    private let canvas = CGSize(width: 300, height: 300)

    private func input(degree: Int, importance: Int = 1) -> (UUID, GraphLayout.Input) {
        let id = UUID()
        return (id, GraphLayout.Input(nodeID: id, degree: degree, importanceScore: importance))
    }

    // MARK: - 1. 中心 node は degree 最大

    @Test func testCenterNodeIsHighestDegree() {
        let (hubID, hub) = input(degree: 5, importance: 10)
        let (_, n1) = input(degree: 1)
        let (_, n2) = input(degree: 2)
        let (_, n3) = input(degree: 3)
        let positions = GraphLayout.compute(inputs: [n1, n2, hub, n3], canvas: canvas)

        #expect(positions.count == 4)
        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let centerPos = positions.first { $0.nodeID == hubID }
        #expect(centerPos?.point == center)
    }

    // MARK: - 2. 周辺 node は中心から radius の距離に配置 (円形)

    @Test func testPeripheralNodesOnCircle() {
        let (_, hub) = input(degree: 5)
        let inputs = [hub] + (0..<3).map { _ in input(degree: 1).1 }
        let positions = GraphLayout.compute(inputs: inputs, canvas: canvas)

        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let expectedRadius = min(canvas.width, canvas.height) / 2 * 0.7

        // 中心 node は1つ、それ以外は半径距離
        let nonCenter = positions.filter { $0.point != center }
        #expect(nonCenter.count == 3)
        for pos in nonCenter {
            let dx = pos.point.x - center.x
            let dy = pos.point.y - center.y
            let distance = sqrt(dx * dx + dy * dy)
            // 浮動小数点誤差を許容
            #expect(abs(distance - expectedRadius) < 0.01)
        }
    }

    // MARK: - 3. 空 input / canvas 0 サイズ は空配列を返す (overflow / degenerate ケース)

    @Test func testEmptyOrInvalidInputReturnsEmpty() {
        #expect(GraphLayout.compute(inputs: [], canvas: canvas).isEmpty)
        let (_, n) = input(degree: 1)
        #expect(GraphLayout.compute(inputs: [n], canvas: CGSize(width: 0, height: 100)).isEmpty)
        // 1 件のみは中心配置
        let single = GraphLayout.compute(inputs: [n], canvas: canvas)
        #expect(single.count == 1)
        #expect(single.first?.point == CGPoint(x: canvas.width / 2, y: canvas.height / 2))
    }
}
