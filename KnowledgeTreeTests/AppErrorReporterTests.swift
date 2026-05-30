//
//  AppErrorReporterTests.swift
//  KnowledgeTreeTests
//
//  spec 061 (P1-3) — AppErrorReporter / AppErrorReporting の検証。
//

import Testing
import Foundation
@testable import KnowledgeTree

@MainActor
struct AppErrorReporterTests {

    /// Mock: report 呼び出しを記録して内容を検証できるようにする。
    final class MockAppErrorReporter: AppErrorReporting {
        private(set) var reports: [(operation: String, error: String)] = []
        func report(_ error: Error, operation: String) {
            reports.append((operation, String(describing: error)))
        }
    }

    enum SampleError: Error { case saveFailed }

    @Test func testReportRecordsOperation() {
        let mock = MockAppErrorReporter()
        mock.report(SampleError.saveFailed, operation: "deleteChatSession")
        #expect(mock.reports.count == 1)
        #expect(mock.reports.first?.operation == "deleteChatSession")
    }

    @Test func testReportRecordsMultipleOperations() {
        let mock = MockAppErrorReporter()
        mock.report(SampleError.saveFailed, operation: "addTag")
        mock.report(SampleError.saveFailed, operation: "removeTag")
        #expect(mock.reports.count == 2)
        #expect(mock.reports.map(\.operation) == ["addTag", "removeTag"])
    }

    /// 実 AppErrorReporter.shared は os.Logger に書くだけで crash しないこと。
    @Test func testSharedReporterDoesNotCrash() {
        AppErrorReporter.shared.report(SampleError.saveFailed, operation: "unitTest")
        #expect(Bool(true))
    }
}
