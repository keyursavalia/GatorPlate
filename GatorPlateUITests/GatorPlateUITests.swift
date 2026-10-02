import XCTest

/// Critical path with mock services (`-UITestMock`): signed out > sign up > terms > tabs > sign out.
final class GatorPlateUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSignUpAcceptTermsReachTabsAndSignOut() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMock"]
        app.launch()

        // Welcome
        let email = app.textFields["SFSU email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))

        app.buttons["New here? Create an account"].tap()

        email.tap()
        email.typeText("ada@mail.sfsu.edu")

        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("password1")

        let name = app.textFields["Your name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Ada")

        app.buttons["Create account"].tap()

        // Terms: "I agree" stays blocked until the box is checked.
        let agree = app.buttons["I agree"]
        XCTAssertTrue(agree.waitForExistence(timeout: 10))
        XCTAssertFalse(agree.isEnabled)

        app.descendants(matching: .any)["I have read and agree to the Terms of Use"].firstMatch.tap()
        XCTAssertTrue(agree.isEnabled)
        agree.tap()

        // Main tabs. Looked up as buttons: iPhone draws a tab bar, iPad draws a top row of buttons.
        let mapTab = app.buttons["Map"].firstMatch
        XCTAssertTrue(mapTab.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Feed"].firstMatch.exists)

        let settingsTab = app.buttons["Settings"].firstMatch
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()
        // LabeledContent is exposed as one combined element: "<label>, <value>".
        XCTAssertTrue(app.staticTexts["Posting as, Ada"].waitForExistence(timeout: 5))

        // Sign out returns to Welcome
        app.buttons["Sign out"].tap()
        XCTAssertTrue(app.textFields["SFSU email"].waitForExistence(timeout: 10))
    }
}
