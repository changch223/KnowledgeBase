//
//  UnderstandingTabUITests.swift
//  KnowledgeTreeUITests
//
//  spec 044 — 学習タブの基本フロー 3 ケース。
//  実機 / Simulator で Apple Intelligence 設定によりカード surface 内容が変わるため、
//  「タブが起動する」「empty state が出る or カードが出る」までを検証する軽量 UI test。
//

import XCTest

final class UnderstandingTabUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// US1 — 学習タブが起動 default で選択され、画面が出る (カード or empty state)。
    @MainActor
    func testLearningTabIsDefaultAndShowsContentOrEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        // tab bar の学習タブが存在する
        let learningTab = app.tabBars.buttons["tab.learning"]
        XCTAssertTrue(learningTab.waitForExistence(timeout: 5))

        // 起動 default で選択されている (or 学習タブのタイトルが見える)
        XCTAssertTrue(learningTab.isSelected || app.staticTexts["学習"].waitForExistence(timeout: 3))

        // カード or empty state のどちらかが 3 秒以内に出る (SC-001)
        let emptyState = app.otherElements["state.understanding.empty"]
        let cardQuery = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'card.understanding.'"))
        _ = emptyState.waitForExistence(timeout: 3)
        XCTAssertTrue(emptyState.exists || cardQuery.firstMatch.exists,
                      "学習タブで empty state もカードも表示されなかった")
    }

    /// US2 — カードがあればタップで DeepDiveChatView が起動 (家庭教師起動中…または chat 内容)。
    @MainActor
    func testTappingCardOpensDeepDiveChat() throws {
        let app = XCUIApplication()
        app.launch()

        let learningTab = app.tabBars.buttons["tab.learning"]
        guard learningTab.waitForExistence(timeout: 5) else {
            XCTFail("学習タブが見つからない")
            return
        }
        learningTab.tap()

        let cardQuery = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'card.understanding.'"))
        guard cardQuery.firstMatch.waitForExistence(timeout: 3) else {
            // ConceptPage / SavedAnswer が無ければスキップ (CI 環境想定)
            throw XCTSkip("学習タブにカードが無いため SC-002 はスキップ (新規インストール状態)")
        }
        cardQuery.firstMatch.tap()

        // DeepDiveChatView 起動: ✓ ボタンが見える
        let understoodButton = app.buttons["button.understood"]
        XCTAssertTrue(understoodButton.waitForExistence(timeout: 5), "DeepDiveChatView が起動しなかった")
    }

    /// US3 — 「✓ わかった」tap で画面は消えず (画面に残る)、tracker call が走る。
    @MainActor
    func testUnderstoodButtonRemainsOnScreenAndDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launch()

        let learningTab = app.tabBars.buttons["tab.learning"]
        guard learningTab.waitForExistence(timeout: 5) else {
            XCTFail("学習タブが見つからない")
            return
        }
        learningTab.tap()

        let cardQuery = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'card.understanding.'"))
        guard cardQuery.firstMatch.waitForExistence(timeout: 3) else {
            throw XCTSkip("学習タブにカードが無いため SC-003 はスキップ")
        }
        cardQuery.firstMatch.tap()

        let understoodButton = app.buttons["button.understood"]
        guard understoodButton.waitForExistence(timeout: 5) else {
            XCTFail("DeepDiveChatView が起動しなかった")
            return
        }
        understoodButton.tap()

        // 画面はまだ DeepDiveChatView (button が残っている)
        XCTAssertTrue(understoodButton.waitForExistence(timeout: 2), "「✓ わかった」後に画面が閉じてしまった (期待: 残る)")
    }
}
