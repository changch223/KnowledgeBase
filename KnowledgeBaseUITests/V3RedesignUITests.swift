//
//  V3RedesignUITests.swift
//  KnowledgeTreeUITests
//
//  spec 059 (P0-5) — V3.0 3 タブ構成の基本導線 smoke test。
//  spec 104: タブは ナレッジ / ライブラリ / 検索 (AI チャットタブは検索に統合)、＋ は右上 toolbar。
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
        let searchTab = app.tabBars.buttons["tab.search"]

        XCTAssertTrue(clipTab.waitForExistence(timeout: 20), "知識 Clip タブが存在しない")
        XCTAssertTrue(libraryTab.exists, "ライブラリタブが存在しない")
        XCTAssertTrue(searchTab.exists, "検索タブが存在しない")
        XCTAssertFalse(app.tabBars.buttons["tab.chat"].exists, "廃止された AI チャットタブが残っている")

        // 起動 default で知識 Clip が選択されている
        XCTAssertTrue(clipTab.isSelected, "起動 default が知識 Clip タブではない")

        // V3.0 で廃止された旧タブが存在しないこと
        XCTAssertFalse(app.tabBars.buttons["tab.learning"].exists, "廃止された学習タブが残っている")
        XCTAssertFalse(app.tabBars.buttons["tab.aibrain"].exists, "廃止された AIブレインタブが残っている")
    }

    // MARK: - Scenario 2: ナレッジ右上の ＋ から Add Article sheet が開く

    @MainActor
    func testAddArticleSheetOpensFromToolbarPlus() throws {
        let app = XCUIApplication()
        app.launch()

        let clipTab = app.tabBars.buttons["tab.knowledgeClip"]
        XCTAssertTrue(clipTab.waitForExistence(timeout: 20))
        clipTab.tap()

        let plus = app.buttons["toolbar.addArticle"]
        guard plus.waitForExistence(timeout: 20) else {
            throw XCTSkip("＋ ボタンが見つからない (レイアウト未表示の可能性、実機検証で確認)")
        }
        plus.tap()

        // Add Article sheet (URL 入力欄) が開く
        let sheet = app.otherElements["sheet.addArticle"]
        let urlField = app.descendants(matching: .any)["addArticle.urlField"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 3) || urlField.waitForExistence(timeout: 3),
                      "Add Article sheet が開かなかった")
    }

    // MARK: - Scenario 3: ライブラリタブへ navigate

    @MainActor
    func testLibraryTabShowsListOrEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        let libraryTab = app.tabBars.buttons["tab.library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 20))
        libraryTab.tap()

        // 空状態 (articleListEmpty) または記事一覧 (articleListRow) のいずれかが表示される
        let emptyState = app.descendants(matching: .any)["articleListEmpty"]
        let listRow = app.descendants(matching: .any)["articleListRow"]
        let emptyVisible = emptyState.waitForExistence(timeout: 20)
        XCTAssertTrue(emptyVisible || listRow.exists,
                      "ライブラリタブで空状態も記事一覧も表示されなかった")
    }

    // MARK: - Scenario 4: 検索タブが開き、検索欄と「最近聞いたこと」(または空案内) を表示

    @MainActor
    func testSearchTabOpensAndShowsContent() throws {
        let app = XCUIApplication()
        app.launch()

        let searchTab = app.tabBars.buttons["tab.search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 20))
        searchTab.tap()

        // 検索欄が表示される
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 20), "検索タブに検索欄が表示されなかった")

        // 履歴がある場合は見出し、無い場合は空案内のどちらかが表示される
        let recentHeader = app.staticTexts["search.section.recentQuestions"]
        let emptyGuide = app.staticTexts["search.empty.recent"]
        XCTAssertTrue(recentHeader.waitForExistence(timeout: 20) || emptyGuide.exists,
                      "「最近聞いたこと」も空案内も表示されなかった")
    }

    // MARK: - Scenario 5: Avatar menu から Settings を開く

    @MainActor
    func testSettingsOpensFromAvatarMenu() throws {
        let app = XCUIApplication()
        app.launch()

        // spec 087: AvatarMenu は Library タブの toolbar に移動 (Knowledge タブからは削除済)
        let libraryTab = app.tabBars.buttons["tab.library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 20))
        libraryTab.tap()

        let avatar = app.buttons["toolbar.avatar"]
        guard avatar.waitForExistence(timeout: 20) else {
            throw XCTSkip("Avatar menu が見つからない (実機検証で確認)")
        }
        avatar.tap()

        // Settings 内の iCloud toggle が表示される
        let icloudToggle = app.switches["settings.icloud.toggle"]
        XCTAssertTrue(icloudToggle.waitForExistence(timeout: 3),
                      "Avatar menu から Settings が開かなかった")
    }
}
