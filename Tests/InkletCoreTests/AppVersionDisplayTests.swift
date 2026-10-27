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

    func testMarksBetaBuildsBeforeTheBuildNumber() {
        XCTAssertEqual(
            AppVersionDisplay.format(
                marketingVersion: "2.1.0",
                buildNumber: "36",
                fallback: "2026.0529.2250",
                isBeta: true
            ),
            "2.1.0 Beta (36)"
        )
    }

    func testOnlyTheBetaChannelCountsAsBeta() {
        XCTAssertTrue(AppVersionDisplay.isBeta(releaseChannel: "beta"))
        XCTAssertFalse(AppVersionDisplay.isBeta(releaseChannel: "stable"))
        XCTAssertFalse(AppVersionDisplay.isBeta(releaseChannel: nil))
    }
}
