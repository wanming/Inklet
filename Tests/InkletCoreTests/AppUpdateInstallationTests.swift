import Foundation
import XCTest
@testable import InkletCore

final class AppUpdateInstallationTests: XCTestCase {
    func testDownloadURLPointsAtTheReleaseDiskImage() throws {
        let tagName = "v2.2.0-37"
        let release = InkletRelease(
            version: try InkletReleaseVersion(tagName: tagName),
            tagName: tagName,
            name: nil,
            notes: "",
            pageURL: URL(string: "https://github.com/wanming/Inklet/releases/tag/\(tagName)")!
        )

        XCTAssertEqual(
            release.downloadURL,
            URL(string: "https://github.com/wanming/Inklet/releases/download/v2.2.0-37/Inklet.dmg")
        )
    }

    func testInstallLocationNeedsAWritableBundleOutsideAppTranslocation() {
        let writable: (String) -> Bool = { _ in true }

        XCTAssertTrue(AppUpdateInstallLocation.canReplace(
            bundleURL: URL(fileURLWithPath: "/Applications/Inklet.app"),
            isWritable: writable
        ))
        XCTAssertFalse(AppUpdateInstallLocation.canReplace(
            bundleURL: URL(fileURLWithPath: "/private/var/folders/x/AppTranslocation/1234/d/Inklet.app"),
            isWritable: writable
        ))
        XCTAssertFalse(AppUpdateInstallLocation.canReplace(
            bundleURL: URL(fileURLWithPath: "/usr/local/bin/inklet"),
            isWritable: writable
        ))
        XCTAssertFalse(AppUpdateInstallLocation.canReplace(
            bundleURL: URL(fileURLWithPath: "/Applications/Inklet.app"),
            isWritable: { $0 != "/Applications" }
        ))
        XCTAssertFalse(AppUpdateInstallLocation.canReplace(
            bundleURL: URL(fileURLWithPath: "/Applications/Inklet.app"),
            isWritable: { $0 != "/Applications/Inklet.app" }
        ))
    }

    func testInstallAttemptIsForgottenOnceItsBuildRuns() throws {
        let suiteName = "AppUpdateInstallationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let attempts = AppUpdateInstallAttempts(userDefaults: defaults)

        XCTAssertFalse(attempts.didFail(build: 37))

        attempts.record(build: 37)
        attempts.settle(currentBuild: 36)
        XCTAssertTrue(attempts.didFail(build: 37))
        XCTAssertFalse(attempts.didFail(build: 38))

        attempts.settle(currentBuild: 37)
        XCTAssertFalse(attempts.didFail(build: 37))
        XCTAssertNil(defaults.object(forKey: InkletPreferenceKeys.attemptedUpdateInstallBuild))
    }

    func testInstallPreferenceKeysAreNotRecognizedLegacyKeys() {
        XCTAssertFalse(InkletPreferenceKeys.recognizedLegacyKeys.contains(InkletPreferenceKeys.automaticallyInstallsUpdates))
        XCTAssertFalse(InkletPreferenceKeys.recognizedLegacyKeys.contains(InkletPreferenceKeys.attemptedUpdateInstallBuild))
    }

    func testSwapScriptArgumentsKeepTheBackupInTheStagingFolder() {
        let arguments = AppUpdateSwapScript.arguments(
            scriptPath: "/tmp/stage/install.sh",
            processIdentifier: 42,
            installedAppURL: URL(fileURLWithPath: "/Applications/Inklet.app"),
            replacementURL: URL(fileURLWithPath: "/tmp/stage/Inklet.app"),
            relaunches: false
        )

        XCTAssertEqual(arguments, [
            "/tmp/stage/install.sh",
            "42",
            "/Applications/Inklet.app",
            "/tmp/stage/Inklet.app",
            "/tmp/stage/Previous.app",
            "0",
        ])
    }

    func testSwapScriptReplacesTheAppAfterInkletExits() throws {
        let fixture = try SwapFixture()
        defer { fixture.remove() }
        try fixture.makeApp(at: fixture.replacementURL, marker: "new")

        XCTAssertEqual(try fixture.runScript(), 0)

        XCTAssertEqual(try fixture.marker(in: fixture.installedURL), "new")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.stagingURL.path))
    }

    func testSwapScriptPutsTheOldAppBackWhenTheReplacementIsMissing() throws {
        let fixture = try SwapFixture()
        defer { fixture.remove() }

        XCTAssertEqual(try fixture.runScript(), 1)

        XCTAssertEqual(try fixture.marker(in: fixture.installedURL), "old")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.stagingURL.path))
    }
}

private struct SwapFixture {
    let rootURL: URL
    let installedURL: URL
    let stagingURL: URL

    var replacementURL: URL {
        stagingURL.appendingPathComponent("Inklet.app", isDirectory: true)
    }

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppUpdateSwap.\(UUID().uuidString)", isDirectory: true)
        installedURL = rootURL.appendingPathComponent("Applications/Inklet.app", isDirectory: true)
        stagingURL = rootURL.appendingPathComponent("Staging", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        try makeApp(at: installedURL, marker: "old")
    }

    func makeApp(at url: URL, marker: String) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try marker.write(to: url.appendingPathComponent("marker"), atomically: true, encoding: .utf8)
    }

    func marker(in url: URL) throws -> String {
        try String(contentsOf: url.appendingPathComponent("marker"), encoding: .utf8)
    }

    /// Runs the script the way Inklet does, with the pid of a process that has already exited.
    func runScript() throws -> Int32 {
        let exited = Process()
        exited.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try exited.run()
        exited.waitUntilExit()

        let scriptURL = stagingURL.appendingPathComponent("install.sh")
        try AppUpdateSwapScript.source.write(to: scriptURL, atomically: true, encoding: .utf8)
        let script = Process()
        script.executableURL = URL(fileURLWithPath: "/bin/sh")
        script.arguments = AppUpdateSwapScript.arguments(
            scriptPath: scriptURL.path,
            processIdentifier: exited.processIdentifier,
            installedAppURL: installedURL,
            replacementURL: replacementURL,
            relaunches: false
        )
        try script.run()
        script.waitUntilExit()
        return script.terminationStatus
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
