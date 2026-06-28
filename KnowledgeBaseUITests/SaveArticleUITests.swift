//
//  SaveArticleUITests.swift
//  KnowledgeTreeUITests
//
//  spec 001 / アプリ本体側の主要 UI フローの smoke test。
//
//  Share Extension 経由の保存フロー、複数記事の seed が必要なテスト
//  (一覧表示確認・行タップで SVC 表示・スワイプ削除) は launch argument
//  ベースの seed 機構が要追加。本 spec の MVP 範囲では quickstart.md の
//  手動検証で User Story 1〜3 を担保する。
//

import XCTest

final class SaveArticleUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesAndShowsEmptyOrList() throws {
        let app = XCUIApplication()
        app.launch()

        let emptyState = app.otherElements["articleListEmpty"]
        let listRow = app.buttons["articleListRow"]

        let emptyVisible = emptyState.waitForExistence(timeout: 5)
        let listVisible = listRow.exists

        XCTAssertTrue(
            emptyVisible || listVisible,
            "起動後に空状態 (articleListEmpty) または記事一覧 (articleListRow) のいずれかが表示されること"
        )
    }
}
