import XCTest
@testable import Inklet
@testable import InkletCore

final class WhatsNewPolicyTests: XCTestCase {
    func testVersionsCompareNumerically() {
        XCTAssertTrue(WhatsNewPolicy.isNewer("1.10.0", than: "1.9.0"))
        XCTAssertTrue(WhatsNewPolicy.isNewer("1.2.0", than: "1.1.12"))
        XCTAssertFalse(WhatsNewPolicy.isNewer("1.2.0", than: "1.2.0"))
    }

    func testUpdateShowsEveryVersionSinceTheLastOneSeenNewestFirst() {
        XCTAssertEqual(
            WhatsNewPolicy.unseenVersions(
                withNotes: ["1.2.0", "1.3.0", "1.4.0", "1.5.0"],
                currentVersion: "1.4.0",
                lastSeenVersion: "1.2.0",
                isWelcomeGuideShowing: false
            ),
            ["1.4.0", "1.3.0"]
        )
    }

    func testRelaunchingTheSameVersionShowsNothing() {
        XCTAssertEqual(
            WhatsNewPolicy.unseenVersions(
                withNotes: ["1.2.0"],
                currentVersion: "1.2.0",
                lastSeenVersion: "1.2.0",
                isWelcomeGuideShowing: false
            ),
            []
        )
    }

    func testUpdatingFromAVersionWithoutNotesShowsOnlyTheCurrentVersion() {
        XCTAssertEqual(
            WhatsNewPolicy.unseenVersions(
                withNotes: ["1.2.0", "1.3.0"],
                currentVersion: "1.3.0",
                lastSeenVersion: nil,
                isWelcomeGuideShowing: false
            ),
            ["1.3.0"]
        )
    }

    func testWelcomeGuideTakesPriority() {
        XCTAssertEqual(
            WhatsNewPolicy.unseenVersions(
                withNotes: ["1.3.0"],
                currentVersion: "1.3.0",
                lastSeenVersion: "1.2.0",
                isWelcomeGuideShowing: true
            ),
            []
        )
    }

    func testCatalogVersionsAreUniqueAndEachHasFeatures() {
        let versions = WhatsNewCatalog.versions
        XCTAssertEqual(Set(versions).count, versions.count)
        for release in WhatsNewCatalog.releases {
            XCTAssertFalse(release.features.isEmpty, release.version)
            XCTAssertLessThanOrEqual(release.features.count, 4, release.version)
        }
        XCTAssertEqual(WhatsNewCatalog.changelog(upTo: "2.0.5").first?.version, "2.0.0")
        XCTAssertTrue(WhatsNewCatalog.changelog(upTo: "1.1.12").isEmpty)
        let changelog = WhatsNewCatalog.changelog(upTo: "99.0.0").map(\.version)
        XCTAssertEqual(changelog, changelog.sorted { WhatsNewPolicy.isNewer($0, than: $1) })
    }
}
