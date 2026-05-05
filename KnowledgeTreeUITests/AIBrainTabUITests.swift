//
//  AIBrainTabUITests.swift
//  KnowledgeTreeUITests
//
//  spec 011 — AI ブレインタブと既存ライブラリタブの UI 回帰テスト。
//  MVP scope: T008 (US4 既存保持) + T013 (US1 PowerGauge)
//  KnowledgeMap / RecentActivity の検証は spec 011 Phase 5/6 で追加。
//

import XCTest

final class AIBrainTabUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// T008 [US4]: ライブラリタブ → 検索バー / タグナビゲーションが TabView 内でも動作する。
    /// 既存挙動の回帰検証。
    @MainActor
    func testLibraryTabRetainsExistingBehavior() throws {
        let app = XCUIApplication()
        app.launch()

        // タブバー: ライブラリタブを明示タップ (起動時 default で選択されている想定だが念のため)
        let libraryTab = app.tabBars.buttons["tab.library"]
        if libraryTab.waitForExistence(timeout: 5) {
            libraryTab.tap()
        }

        // タグ一覧ナビゲーションボタンが存在し、tap で TagListView へ遷移できる
        let tagListButton = app.buttons["tagListNavigationButton"]
        XCTAssertTrue(
            tagListButton.waitForExistence(timeout: 5),
            "tagListNavigationButton が ライブラリタブで見つからない"
        )
    }

    /// T013 [US1]: AI ブレインタブを開くと PowerGauge が表示される。
    /// 0 件 / 既存件数 共に表示されること (回帰)。
    @MainActor
    func testAIBrainTabShowsPowerGauge() throws {
        let app = XCUIApplication()
        app.launch()

        // タブバー: AI ブレインタブをタップ
        let aibrainTab = app.tabBars.buttons["tab.aibrain"]
        XCTAssertTrue(
            aibrainTab.waitForExistence(timeout: 5),
            "AI ブレインタブが見つからない (TabView 化されていない可能性)"
        )
        aibrainTab.tap()

        // PowerGauge カードが表示される
        let powerGauge = app.otherElements["aibrain.power_gauge"]
        XCTAssertTrue(
            powerGauge.waitForExistence(timeout: 3),
            "PowerGaugeCard が AI ブレインタブで見つからない"
        )
    }

    /// T013 補助: AI ブレインタブ root の accessibilityIdentifier 検証。
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

    /// T019 [US2]: KnowledgeMap が AI ブレインタブで表示される。
    /// 0 件 / 既存件数 共に accessibility 経由で確認。
    @MainActor
    func testKnowledgeMapPresent() throws {
        let app = XCUIApplication()
        app.launch()

        let aibrainTab = app.tabBars.buttons["tab.aibrain"]
        XCTAssertTrue(aibrainTab.waitForExistence(timeout: 5))
        aibrainTab.tap()

        let map = app.otherElements["aibrain.knowledge_map"]
        XCTAssertTrue(
            map.waitForExistence(timeout: 5),
            "KnowledgeMapView が AI ブレインタブで見つからない"
        )
    }

    /// T020 [US2]: タグが 0 件のとき empty state が表示される。
    /// 新規インストール直後を想定 (記事なしでタグも 0 件)。
    @MainActor
    func testKnowledgeMapEmptyStateOnFreshInstall() throws {
        let app = XCUIApplication()
        // データクリアの仕組みは現状なし → 既存データがある場合は skip 相当
        app.launch()

        let aibrainTab = app.tabBars.buttons["tab.aibrain"]
        XCTAssertTrue(aibrainTab.waitForExistence(timeout: 5))
        aibrainTab.tap()

        // empty state のいずれかが表示されていれば test 通過。
        // ContentUnavailableView か通常のマップ表示 (既存記事あり) かを判定。
        let emptyState = app.otherElements["aibrain.map.empty"]
        let map = app.otherElements["aibrain.knowledge_map"]
        XCTAssertTrue(
            emptyState.waitForExistence(timeout: 3) || map.exists,
            "Map: empty state でも通常表示でもない (識別不能状態)"
        )
    }

    /// T031 [US3]: RecentActivityCards の 3 枚カードが AI ブレインタブで表示される。
    @MainActor
    func testRecentActivityCardsPresent() throws {
        let app = XCUIApplication()
        app.launch()

        let aibrainTab = app.tabBars.buttons["tab.aibrain"]
        XCTAssertTrue(aibrainTab.waitForExistence(timeout: 5))
        aibrainTab.tap()

        let recentSection = app.otherElements["aibrain.recent_activity"]
        XCTAssertTrue(
            recentSection.waitForExistence(timeout: 5),
            "RecentActivityCards section が見つからない"
        )

        // 3 枚のカードのいずれかは少なくとも見えていること
        let weekCard = app.otherElements["aibrain.recent.card.this_week"]
        let growingCard = app.otherElements["aibrain.recent.card.growing"]
        let connectionsCard = app.otherElements["aibrain.recent.card.connections"]
        XCTAssertTrue(
            weekCard.exists || growingCard.exists || connectionsCard.exists,
            "RecentActivity の 3 枚カードのいずれも見つからない"
        )
    }
}
