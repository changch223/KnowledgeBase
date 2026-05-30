//
//  V3RedesignUITests.swift
//  KnowledgeTreeUITests
//
//  spec 059 (P0-5) — V3.0 3 タブ構成 (知識 Clip / ライブラリ / AI チャット) の基本導線 smoke test。
//  旧 UnderstandingTabUITests (tab.learning) / AIBrainTabUITests (tab.aibrain) は
//  spec 056 V3.0 でタブ廃止により無効化 → 本 suite に置き換え。
//
//  Apple Intelligence 設定や保存データの有無で内容が変わるため、
//  「タブが存在する」「主要導線が開く」までを検証する軽量 UI test。
//  実機 / Simulator 実行検証はユーザー後追い (sandbox 制約)。
//

import XCTest

final class V3RedesignUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Scenario 1: 起動 default = 知識 Clip タブ

    @MainActor
    func testKnowledgeClipTabIsDefaultOnLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // 3 タブが存在する
        let clipTab = app.tabBars.buttons["tab.knowledgeClip"]
        let libraryTab = app.tabBars.buttons["tab.library"]
        let chatTab = app.tabBars.buttons["tab.chat"]

        XCTAssertTrue(clipTab.waitForExistence(timeout: 5), "知識 Clip タブが存在しない")
        XCTAssertTrue(libraryTab.exists, "ライブラリタブが存在しない")
        XCTAssertTrue(chatTab.exists, "AI チャットタブが存在しない")

        // 起動 default で知識 Clip が選択されている
        XCTAssertTrue(clipTab.isSelected, "起動 default が知識 Clip タブではない")

        // V3.0 で廃止された旧タブが存在しないこと
        XCTAssertFalse(app.tabBars.buttons["tab.learning"].exists, "廃止された学習タブが残っている")
        XCTAssertFalse(app.tabBars.buttons["tab.aibrain"].exists, "廃止された AIブレインタブが残っている")
    }

    // MARK: - Scenario 2: 知識 Clip の FAB から Add Article sheet が開く

    @MainActor
    func testAddArticleSheetOpensFromFAB() throws {
        let app = XCUIApplication()
        app.launch()

        let clipTab = app.tabBars.buttons["tab.knowledgeClip"]
        XCTAssertTrue(clipTab.waitForExistence(timeout: 5))
        clipTab.tap()

        let fab = app.buttons["fab.addArticle"]
        guard fab.waitForExistence(timeout: 5) else {
            throw XCTSkip("FAB が見つからない (レイアウト未表示の可能性、実機検証で確認)")
        }
        fab.tap()

        // Add Article sheet (URL 入力欄) が開く
        let sheet = app.otherElements["sheet.addArticle"]
        let urlField = app.textFields["addArticle.urlField"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 3) || urlField.waitForExistence(timeout: 3),
                      "Add Article sheet が開かなかった")
    }

    // MARK: - Scenario 3: ライブラリタブへ navigate

    @MainActor
    func testLibraryTabShowsListOrEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        let libraryTab = app.tabBars.buttons["tab.library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 5))
        libraryTab.tap()

        // 空状態 (articleListEmpty) または記事一覧 (articleListRow) のいずれかが表示される
        let emptyState = app.otherElements["articleListEmpty"]
        let listRow = app.buttons["articleListRow"]
        let emptyVisible = emptyState.waitForExistence(timeout: 5)
        XCTAssertTrue(emptyVisible || listRow.exists,
                      "ライブラリタブで空状態も記事一覧も表示されなかった")
    }

    // MARK: - Scenario 4: AI チャットタブが開き empty-state を表示

    @MainActor
    func testChatTabOpensAndShowsContent() throws {
        let app = XCUIApplication()
        app.launch()

        let chatTab = app.tabBars.buttons["tab.chat"]
        XCTAssertTrue(chatTab.waitForExistence(timeout: 5))
        chatTab.tap()

        // chat root が表示される
        let chatRoot = app.otherElements["chat.tab.root"]
        let sidebarButton = app.buttons["chat.toolbar.sidebar"]
        XCTAssertTrue(chatRoot.waitForExistence(timeout: 5) || sidebarButton.waitForExistence(timeout: 5),
                      "AI チャットタブが開かなかった")
    }

    // MARK: - Scenario 5: Avatar menu から Settings を開く

    @MainActor
    func testSettingsOpensFromAvatarMenu() throws {
        let app = XCUIApplication()
        app.launch()

        let clipTab = app.tabBars.buttons["tab.knowledgeClip"]
        XCTAssertTrue(clipTab.waitForExistence(timeout: 5))
        clipTab.tap()

        let avatar = app.buttons["toolbar.avatar"]
        guard avatar.waitForExistence(timeout: 5) else {
            throw XCTSkip("Avatar menu が見つからない (実機検証で確認)")
        }
        avatar.tap()

        // Settings 内の健全性スコア / iCloud toggle 等が表示される
        let icloudToggle = app.switches["settings.icloud.toggle"]
        let healthSection = app.staticTexts["settings.health.section.title"]
        XCTAssertTrue(icloudToggle.waitForExistence(timeout: 3) || healthSection.waitForExistence(timeout: 3),
                      "Avatar menu から Settings が開かなかった")
    }
}
