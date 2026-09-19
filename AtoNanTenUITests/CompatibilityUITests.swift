import XCTest

/// Exercise the same critical flows on each supported OS using isolated demo data.
@MainActor
final class CompatibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testInitialSetupCreatesAChildAndOpensHome() {
        let app = launch(scene: "setup")
        let name = app.textFields["例：たろう"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["機種変更：バックアップから引き継ぐ"].exists)
        name.tap()
        name.typeText("UI Test")
        tap(app.buttons["つぎへ"], in: app)
        XCTAssertTrue(app.staticTexts["学校の宿題"].waitForExistence(timeout: 5))
        tap(app.buttons["つぎへ"], in: app)
        tap(app.buttons["はじめる！"], in: app)
        XCTAssertTrue(app.staticTexts["ごほうびプラス"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 / 5 てん"].exists)
        capture("初回設定後のホーム", app: app)
    }

    func testApprovingRequestsUpdatesPointsAndHistory() {
        let app = launch(scene: "parent")
        XCTAssertTrue(app.staticTexts["3 / 5点"].waitForExistence(timeout: 10))
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "承認待ちを確認")).firstMatch, in: app)
        for _ in 0..<2 {
            let approve = app.buttons["承認する"].firstMatch
            XCTAssertTrue(approve.waitForExistence(timeout: 5))
            approve.tap()
        }
        XCTAssertTrue(app.staticTexts["承認待ちはありません"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["5 / 5点"].waitForExistence(timeout: 5))
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "履歴を見る")).firstMatch, in: app)
        XCTAssertTrue(app.navigationBars["履歴"].waitForExistence(timeout: 5))
        capture("承認後の履歴", app: app)
    }

    func testRewardStartsAndFinishesTimer() {
        let app = launch(scene: "achievement")
        let redeem = app.buttons["ごほうびをもらった"]
        XCTAssertTrue(redeem.waitForExistence(timeout: 10))
        tap(redeem, in: app)
        let finish = app.buttons["おしまいにする"]
        XCTAssertTrue(finish.waitForExistence(timeout: 10))
        capture("ごほうびタイマー", app: app)
        finish.tap()
        XCTAssertTrue(app.staticTexts["ごほうびプラス"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 / 5 てん"].exists)
    }

    func testBackupDialogsOpenFromSettingsAndSetup() {
        let app = launch(scene: "parent")
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "アプリの設定")).firstMatch, in: app)
        tap(app.buttons["データの引き継ぎ"], in: app)
        XCTAssertTrue(app.navigationBars["データの引き継ぎ"].waitForExistence(timeout: 5))
        capture("引き継ぎ画面", app: app)
        tap(app.buttons["データをエクスポート"], in: app)
        cancelFileDialog(in: app, screenshotName: "エクスポート先の選択")
        tap(app.buttons["データをインポート"], in: app)
        cancelFileDialog(in: app, screenshotName: "インポート元の選択")

        app.terminate()
        app.launchArguments = arguments(scene: "setup")
        app.launch()
        tap(app.buttons["機種変更：バックアップから引き継ぐ"], in: app)
        XCTAssertTrue(app.buttons["データをインポート"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["データをエクスポート"].exists)
        tap(app.buttons["データをインポート"], in: app)
        cancelFileDialog(in: app, screenshotName: "初回設定からのインポート")
        app.buttons["閉じる"].tap()
        XCTAssertTrue(app.textFields["例：たろう"].waitForExistence(timeout: 5))
    }

    private func launch(scene: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments(scene: scene)
        app.launch()
        return app
    }

    private func arguments(scene: String) -> [String] {
        ["-demoScene", scene, "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.exists && element.isHittable {
                element.tap()
                return
            }
            app.swipeUp()
        }
        XCTFail("操作する項目が見つかりません: \(element)")
    }

    private func cancelFileDialog(in app: XCUIApplication, screenshotName: String) {
        let browser = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"].firstMatch
        XCTAssertTrue(browser.waitForExistence(timeout: 10), app.debugDescription)
        capture(screenshotName, app: app)
        let cancel = app.buttons["キャンセル"].firstMatch
        if cancel.exists && cancel.isHittable {
            cancel.tap()
        } else {
            // Some system file pickers use a dismissible sheet without a Cancel button.
            browser.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        }
        XCTAssertTrue(browser.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.navigationBars["データの引き継ぎ"].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
