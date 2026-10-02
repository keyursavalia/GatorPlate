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

        // Main tabs
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        XCTAssertTrue(tabBar.buttons["Map"].exists)
        XCTAssertTrue(tabBar.buttons["Feed"].exists)

        tabBar.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Ada"].waitForExistence(timeout: 5))

        // Sign out returns to Welcome
        app.buttons["Sign out"].tap()
        XCTAssertTrue(app.textFields["SFSU email"].waitForExistence(timeout: 10))
    }
}
