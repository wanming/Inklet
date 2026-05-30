import XCTest
@testable import InkletCore

final class AppVersionDisplayTests: XCTestCase {
    func testFormatsMarketingVersionAndBuildNumber() {
        XCTAssertEqual(
            AppVersionDisplay.format(
                marketingVersion: "0.1.0",
                buildNumber: "128",
                fallback: "2026.0529.2250"
            ),
            "0.1.0 (128)"
        )
    }

    func testFallsBackWhenBundleVersionsAreUnavailable() {
        XCTAssertEqual(
            AppVersionDisplay.format(
                marketingVersion: nil,
                buildNumber: nil,
                fallback: "2026.0529.2250"
            ),
            "2026.0529.2250"
        )
    }
}
