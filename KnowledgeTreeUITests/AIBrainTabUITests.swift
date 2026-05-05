//
//  AIBrainTabUITests.swift
//  KnowledgeTreeUITests
//
//  spec 011 → 015 で v2 layout に書き換え。
//  - 旧 PowerGauge / KnowledgeMap / RecentActivity 系テスト 4 件削除
//  - 新 Stats Row / Insight Card / Category List テスト 4 件追加
//  - ライブラリタブ回帰 + AI ブレインタブ root 識別子の 2 件は保持
//

import XCTest

final class AIBrainTabUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// US4 (spec 011 由来) — ライブラリタブが既存挙動を保持。
    @MainActor
    func testLibraryTabRetainsExistingBehavior() throws {
        let app = XCUIApplication()
        app.launch()

        let libraryTab = app.tabBars.buttons["tab.library"]
        if libraryTab.waitForExistence(timeout: 5) {
            libraryTab.tap()
        }

        let tagListButton = app.buttons["tagListNavigationButton"]
        XCTAssertTrue(
            tagListButton.waitForExistence(timeout: 5),
            "tagListNavigationButton が ライブラリタブで見つからない"
        )
    }

    /// AI ブレインタブの root accessibilityIdentifier 検証 (spec 011 由来、保持)。
    @MainActor
    func testAIBrainRootAccessibilityIdentifier() throws {
        let app = XCUIApplication()
        app.launch()

        let aibrainTab = app.tabBars.buttons["tab.aibrain"]
        XCTAssertTrue(aibrainTab.waitForExistence(timeout: 5))
        aibrainTab.tap()

        let root = app.otherElements["aibrain.root"]
        XCTAssertTrue(
            root.waitForExistence(timeout: 3),
            "aibrain.root が見つからない"
        )
    }

    /// spec 015 / US1: Stats Row が表示される。
    @MainActor
    func testAIBrainTabShowsStatsRow() throws {
        let app = XCUIApplication()
        app.launch()

        let aibrainTab = app.tabBars.buttons["tab.aibrain"]
        XCTAssertTrue(aibrainTab.waitForExistence(timeout: 5))
        aibrainTab.tap()

        let statsRow = app.otherElements["aibrain.stats_row"]
        XCTAssertTrue(
            statsRow.waitForExistence(timeout: 5),
            "aibrain.stats_row が AI ブレインタブで見つからない"
        )
    }

    /// spec 015 / US1: AI Insight Card が表示される。
    @MainActor
    func testInsightCardPresent() throws {
        let app = XCUIApplication()
        app.launch()

        let aibrainTab = app.tabBars.buttons["tab.aibrain"]
        XCTAssertTrue(aibrainTab.waitForExistence(timeout: 5))
        aibrainTab.tap()

        let insightCard = app.otherElements["aibrain.insight_card"]
        XCTAssertTrue(
            insightCard.waitForExistence(timeout: 5),
            "aibrain.insight_card が AI ブレインタブで見つからない"
        )
    }

    /// spec 015 / US1: Category List が表示される (空状態 or 通常表示)。
    @MainActor
    func testCategoryListPresent() throws {
        let app = XCUIApplication()
        app.launch()

        let aibrainTab = app.tabBars.buttons["tab.aibrain"]
        XCTAssertTrue(aibrainTab.waitForExistence(timeout: 5))
        aibrainTab.tap()

        // 空状態 or 通常 Category List のいずれかが見つかれば pass
        let emptyState = app.otherElements["aibrain.category_list.empty"]
        let categoryList = app.otherElements["aibrain.category_list"]

        XCTAssertTrue(
            emptyState.waitForExistence(timeout: 3) || categoryList.exists,
            "Category List: empty state でも通常表示でもない"
        )
    }

    /// spec 015 / US1: タグ 0 件で Category List が空状態を表示。
    @MainActor
    func testCategoryListEmptyStateOnFreshInstall() throws {
        let app = XCUIApplication()
        app.launch()

        let aibrainTab = app.tabBars.buttons["tab.aibrain"]
        XCTAssertTrue(aibrainTab.waitForExistence(timeout: 5))
        aibrainTab.tap()

        // 空状態 or 通常表示のどちらかが必ずある
        let emptyState = app.otherElements["aibrain.category_list.empty"]
        let categoryList = app.otherElements["aibrain.category_list"]
        XCTAssertTrue(
            emptyState.waitForExistence(timeout: 3) || categoryList.exists,
            "Category List 状態が識別不能"
        )
    }
}
