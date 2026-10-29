import AppKit
import Foundation
import XCTest
@testable import Inklet
@testable import InkletCore

@MainActor
final class UpdateCheckAlertPresenterTests: XCTestCase {
    nonisolated(unsafe) private var savedArgumentDomain: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        savedArgumentDomain = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        var argumentDomain = savedArgumentDomain
        argumentDomain[InkletPreferenceKeys.interfaceLanguage] = InterfaceLanguage.english.rawValue
        UserDefaults.standard.setVolatileDomain(argumentDomain, forName: UserDefaults.argumentDomain)
        NotificationCenter.default.post(name: .inkletLanguageDidChange, object: nil)
    }

    override func tearDown() {
        UserDefaults.standard.setVolatileDomain(savedArgumentDomain, forName: UserDefaults.argumentDomain)
        NotificationCenter.default.post(name: .inkletLanguageDidChange, object: nil)
        super.tearDown()
    }

    func testPresentUpdateAssemblesVersionDescriptionAndNotes() {
        for releaseName in ["Faster dictation", "Inklet 2.0.0 — Faster dictation"] {
            let recorder = AlertRecorder(response: .alertSecondButtonReturn)
            let presenter = makePresenter(recorder: recorder)

            presenter.presentUpdate(
                release(name: releaseName, notes: "Dictation is now noticeably faster."),
                currentVersion: "1.2.3 (45)"
            )

            XCTAssertEqual(recorder.contents, [
                .init(
                    messageText: "An Inklet update is available",
                    informativeText: "Latest: 2.0.0 (build 200)\n\nCurrent: 1.2.3 (45)\n\n\(releaseName)",
                    releaseNotes: "Dictation is now noticeably faster.",
                    primaryButtonTitle: "View on GitHub",
                    secondaryButtonTitle: "Later",
                    alertStyle: .informational
                ),
            ])
            XCTAssertTrue(recorder.openedURLs.isEmpty)
        }
    }

    func testPresentUpdatePreservesLargeBuildNumber() {
        let recorder = AlertRecorder(response: .alertSecondButtonReturn)
        for buildNumber in [2_147_483_648, Int.max] {
            let tagName = "v2.0.0-\(buildNumber)"
            let release = InkletRelease(
                version: try! InkletReleaseVersion(tagName: tagName),
                tagName: tagName,
                name: nil,
                notes: "Release notes",
                pageURL: URL(string: "https://github.com/wanming/Inklet/releases/tag/\(tagName)")!
            )

            makePresenter(recorder: recorder).presentUpdate(release, currentVersion: "1.2.3")

            XCTAssertEqual(
                recorder.contents.last?.informativeText.components(separatedBy: "\n\n").first,
                "Latest: 2.0.0 (build \(buildNumber))"
            )
        }
    }

    func testPresentUpdateOmitsWorkflowReleaseNameAndUsesNoNotesFallback() {
        let recorder = AlertRecorder(response: .alertSecondButtonReturn)
        let presenter = makePresenter(recorder: recorder)

        presenter.presentUpdate(release(name: "Inklet 2.0.0 (200)", notes: ""), currentVersion: "1.2.3")

        XCTAssertEqual(
            recorder.contents.first?.informativeText,
            "Latest: 2.0.0 (build 200)\n\nCurrent: 1.2.3\n\nView the release on GitHub for details."
        )
        XCTAssertNil(recorder.contents.first?.releaseNotes)

        let whitespaceRecorder = AlertRecorder(response: .alertSecondButtonReturn)
        makePresenter(recorder: whitespaceRecorder).presentUpdate(
            release(name: nil, notes: " \n\t "),
            currentVersion: "1.2.3"
        )
        XCTAssertEqual(
            whitespaceRecorder.contents.first?.informativeText,
            "Latest: 2.0.0 (build 200)\n\nCurrent: 1.2.3\n\nView the release on GitHub for details."
        )
    }

    func testPresentUpdateOmitsVersionOnlyReleaseNames() {
        let versionOnlyNames = [
            "v2.0.0-200",
            "2.0.0",
            "v2.0.0",
            "2.0.0 (200)",
            "2.0.0 (build 200)",
            "Inklet 2.0.0 (200)",
            "Ínklet 2.0.0 (BuIlD 200)",
            "Inklet 2.0.0 Beta (200)",
        ]
        let expectedInformativeText = "Latest: 2.0.0 (build 200)\n\nCurrent: 1.2.3"

        for name in versionOnlyNames {
            let recorder = AlertRecorder(response: .alertSecondButtonReturn)
            makePresenter(recorder: recorder).presentUpdate(
                release(name: name, notes: "Release notes"),
                currentVersion: "1.2.3"
            )

            XCTAssertEqual(recorder.contents.first?.informativeText, expectedInformativeText, name)
            XCTAssertEqual(recorder.contents.first?.releaseNotes, "Release notes", name)
            XCTAssertFalse(
                recorder.contents.first?.informativeText
                    .components(separatedBy: "\n\n")
                    .contains(name) ?? true,
                name
            )
        }
    }

    func testPresentUpdateMarksBetaReleases() {
        let recorder = AlertRecorder(response: .alertSecondButtonReturn)
        let tagName = "v2.0.0-200"
        let beta = InkletRelease(
            version: try! InkletReleaseVersion(tagName: tagName),
            tagName: tagName,
            name: "Inklet 2.0.0 Beta (200)",
            notes: "Release notes",
            pageURL: URL(string: "https://github.com/wanming/Inklet/releases/tag/\(tagName)")!,
            isPrerelease: true
        )

        makePresenter(recorder: recorder).presentUpdate(beta, currentVersion: "1.2.3 (199)")

        XCTAssertEqual(
            recorder.contents.first?.informativeText,
            "Latest: 2.0.0 Beta (build 200)\n\nCurrent: 1.2.3 (199)"
        )
        XCTAssertEqual(recorder.contents.first?.releaseNotes, "Release notes")
    }

    func testPresentUpdateShowsOnlyTheInterfaceLanguageSectionOfTheNotes() {
        let notes = """
        ## English
        - **Plain text results:** no stray Markdown.

        ## 简体中文
        - **结果不再带 Markdown 符号**：不会再出现 ** 这类符号。

        ## Deutsch
        - **Klartext:** keine Markdown-Zeichen.

        ---
        macOS 14 or newer.
        """

        let english = AlertRecorder(response: .alertSecondButtonReturn)
        makePresenter(recorder: english).presentUpdate(release(notes: notes), currentVersion: "1.2.3")
        XCTAssertEqual(
            english.contents.first?.releaseNotes,
            "- **Plain text results:** no stray Markdown.\n\nmacOS 14 or newer."
        )

        setInterfaceLanguage(.simplifiedChinese)
        let chinese = AlertRecorder(response: .alertSecondButtonReturn)
        makePresenter(recorder: chinese).presentUpdate(release(notes: notes), currentVersion: "1.2.3")
        XCTAssertEqual(
            chinese.contents.first?.releaseNotes,
            "- **结果不再带 Markdown 符号**：不会再出现 ** 这类符号。\n\nmacOS 14 or newer."
        )

        // A language without its own section falls back to English.
        setInterfaceLanguage(.japanese)
        let japanese = AlertRecorder(response: .alertSecondButtonReturn)
        makePresenter(recorder: japanese).presentUpdate(release(notes: notes), currentVersion: "1.2.3")
        XCTAssertEqual(
            japanese.contents.first?.releaseNotes,
            "- **Plain text results:** no stray Markdown.\n\nmacOS 14 or newer."
        )
    }

    func testReleaseNotesAccessoryStopsGrowingAtMaximumHeight() {
        let short = UpdateReleaseNotesView.accessoryView(for: "- One point")
        XCTAssertEqual(short.frame.width, UpdateReleaseNotesView.width)
        XCTAssertGreaterThan(short.frame.height, 0)
        XCTAssertLessThan(short.frame.height, UpdateReleaseNotesView.maximumHeight)

        let long = UpdateReleaseNotesView.accessoryView(
            for: (1...40).map { "- Point \($0) with **bold** text" }.joined(separator: "\n")
        )
        XCTAssertEqual(long.frame.height, UpdateReleaseNotesView.maximumHeight)
    }

    func testReleaseNotesInlineMarkdownKeepsOnlyHTTPSLinks() {
        let rendered = UpdateReleaseNotesView.inline(
            "**Bold** [site](https://getinklet.app) [file](file:///etc/hosts)"
        )
        XCTAssertEqual(String(rendered.characters), "Bold site file")
        let links = rendered.runs.compactMap { $0.link }
        XCTAssertEqual(links, [URL(string: "https://getinklet.app")!])
        XCTAssertTrue(rendered.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized })
    }

    func testPresentUpdateOpensOnlyItsExactPageURLForFirstResponse() {
        let firstRecorder = AlertRecorder(response: .alertFirstButtonReturn)
        makePresenter(recorder: firstRecorder).presentUpdate(release(), currentVersion: "1.2.3")
        XCTAssertEqual(firstRecorder.openedURLs, [release().pageURL])

        let laterRecorder = AlertRecorder(response: .alertSecondButtonReturn)
        makePresenter(recorder: laterRecorder).presentUpdate(release(), currentVersion: "1.2.3")
        XCTAssertTrue(laterRecorder.openedURLs.isEmpty)

        let otherRecorder = AlertRecorder(response: .cancel)
        makePresenter(recorder: otherRecorder).presentUpdate(release(), currentVersion: "1.2.3")
        XCTAssertTrue(otherRecorder.openedURLs.isEmpty)
    }

    func testPresentUpdateOffersInstallAndRelaunchWhenTheReleaseCanBeInstalled() {
        var installed: [Int] = []
        let installRecorder = AlertRecorder(response: .alertFirstButtonReturn)
        let installPresenter = makePresenter(recorder: installRecorder)
        installPresenter.canInstall = { _ in true }
        installPresenter.onInstall = { installed.append($0.version.buildNumber) }

        installPresenter.presentUpdate(release(), currentVersion: "1.2.3")

        XCTAssertEqual(installRecorder.contents.map(\.primaryButtonTitle), ["Install and Relaunch"])
        XCTAssertEqual(installRecorder.contents.map(\.secondaryButtonTitle), ["Later"])
        XCTAssertEqual(installRecorder.contents.map(\.tertiaryButtonTitle), ["View on GitHub"])
        XCTAssertEqual(installed, [200])
        XCTAssertTrue(installRecorder.openedURLs.isEmpty)

        let gitHubRecorder = AlertRecorder(response: .alertThirdButtonReturn)
        let gitHubPresenter = makePresenter(recorder: gitHubRecorder)
        gitHubPresenter.canInstall = { _ in true }
        gitHubPresenter.onInstall = { installed.append($0.version.buildNumber) }
        gitHubPresenter.presentUpdate(release(), currentVersion: "1.2.3")
        XCTAssertEqual(gitHubRecorder.openedURLs, [release().pageURL])
        XCTAssertEqual(installed, [200])
    }

    func testPresentUpdateKeepsViewOnGitHubWhenTheReleaseCannotBeInstalled() {
        var installed: [Int] = []
        let recorder = AlertRecorder(response: .alertFirstButtonReturn)
        let presenter = makePresenter(recorder: recorder)
        presenter.canInstall = { _ in false }
        presenter.onInstall = { installed.append($0.version.buildNumber) }

        presenter.presentUpdate(release(), currentVersion: "1.2.3")

        XCTAssertEqual(recorder.contents.map(\.primaryButtonTitle), ["View on GitHub"])
        XCTAssertEqual(recorder.contents.map(\.tertiaryButtonTitle), [nil])
        XCTAssertEqual(recorder.openedURLs, [release().pageURL])
        XCTAssertTrue(installed.isEmpty)
    }

    func testPresentInstallFailureOffersTheReleasePage() {
        let recorder = AlertRecorder(response: .alertFirstButtonReturn)
        makePresenter(recorder: recorder).presentInstallFailure(release())

        XCTAssertEqual(recorder.contents, [
            .init(
                messageText: "Couldn’t install the update",
                informativeText: "Download it from GitHub and install it yourself.",
                primaryButtonTitle: "View on GitHub",
                secondaryButtonTitle: "Cancel",
                alertStyle: .warning
            ),
        ])
        XCTAssertEqual(recorder.openedURLs, [release().pageURL])

        let cancelRecorder = AlertRecorder(response: .alertSecondButtonReturn)
        makePresenter(recorder: cancelRecorder).presentInstallFailure(release())
        XCTAssertTrue(cancelRecorder.openedURLs.isEmpty)
    }

    func testPresentUpToDateShowsCurrentVersionWithoutOpeningURL() {
        let recorder = AlertRecorder(response: .alertFirstButtonReturn)
        makePresenter(recorder: recorder).presentUpToDate(currentVersion: "1.2.3 (45)")

        XCTAssertEqual(recorder.contents, [
            .init(
                messageText: "Inklet is up to date",
                informativeText: "You’re using 1.2.3 (45).",
                primaryButtonTitle: "OK",
                secondaryButtonTitle: nil,
                alertStyle: .informational
            ),
        ])
        XCTAssertTrue(recorder.openedURLs.isEmpty)
    }

    func testPresentFailureRetriesOnlyForFirstResponse() {
        var retries = 0
        let retryRecorder = AlertRecorder(response: .alertFirstButtonReturn)
        makePresenter(recorder: retryRecorder).presentFailure { retries += 1 }
        XCTAssertEqual(retries, 1)
        XCTAssertEqual(retryRecorder.contents.first?.messageText, "Couldn’t check for updates")
        XCTAssertEqual(retryRecorder.contents.first?.informativeText, "Try again in a moment.")
        XCTAssertEqual(retryRecorder.contents.first?.primaryButtonTitle, "Retry")
        XCTAssertEqual(retryRecorder.contents.first?.secondaryButtonTitle, "Cancel")
        XCTAssertEqual(retryRecorder.contents.first?.alertStyle, .warning)

        let cancelRecorder = AlertRecorder(response: .alertSecondButtonReturn)
        makePresenter(recorder: cancelRecorder).presentFailure { retries += 1 }
        XCTAssertEqual(retries, 1)
    }

    func testPresenterActivatesImmediatelyBeforeEveryAlert() {
        let recorder = AlertRecorder(response: .alertSecondButtonReturn)
        let presenter = makePresenter(recorder: recorder)

        presenter.presentUpdate(release(), currentVersion: "1.2.3")
        presenter.presentUpToDate(currentVersion: "1.2.3")
        presenter.presentFailure { }

        XCTAssertEqual(recorder.events, [.activation, .alert, .activation, .alert, .activation, .alert])
    }

    func testPresentationStateBracketsActivatorAndRunnerForEveryAlertKind() {
        let recorder = AlertRecorder(response: .alertSecondButtonReturn)
        var presenter: UpdateCheckAlertPresenter!
        presenter = UpdateCheckAlertPresenter(
            alertRunner: { _ in
                XCTAssertTrue(presenter.isPresentingAlert)
                recorder.events.append(.alert)
                defer { recorder.events.append(.runnerReturn) }
                return recorder.response
            },
            urlOpener: { _ in XCTFail("Later must not open a URL") },
            applicationActivator: {
                XCTAssertTrue(presenter.isPresentingAlert)
                recorder.events.append(.activation)
            }
        )
        presenter.onPresentationStateChange = { isPresenting in
            XCTAssertEqual(presenter.isPresentingAlert, isPresenting)
            recorder.events.append(.presentation(isPresenting))
        }

        presenter.presentUpdate(release(), currentVersion: "1.2.3")
        presenter.presentUpToDate(currentVersion: "1.2.3")
        presenter.presentFailure { XCTFail("Cancel must not retry") }

        let alertLifecycle: [AlertRecorder.Event] = [
            .presentation(true),
            .activation,
            .alert,
            .runnerReturn,
            .presentation(false),
        ]
        XCTAssertEqual(recorder.events, alertLifecycle + alertLifecycle + alertLifecycle)
        XCTAssertFalse(presenter.isPresentingAlert)
    }

    func testPresentationStateEndsBeforeUpdateAndRetrySideEffects() {
        let recorder = AlertRecorder(response: .alertFirstButtonReturn)
        var presenter: UpdateCheckAlertPresenter!
        presenter = UpdateCheckAlertPresenter(
            alertRunner: { _ in
                XCTAssertTrue(presenter.isPresentingAlert)
                recorder.events.append(.alert)
                defer { recorder.events.append(.runnerReturn) }
                return recorder.response
            },
            urlOpener: { _ in
                XCTAssertFalse(presenter.isPresentingAlert)
                recorder.events.append(.openURL)
            },
            applicationActivator: { recorder.events.append(.activation) }
        )
        presenter.onPresentationStateChange = {
            recorder.events.append(.presentation($0))
        }

        presenter.presentUpdate(release(), currentVersion: "1.2.3")
        XCTAssertEqual(recorder.events, [
            .presentation(true),
            .activation,
            .alert,
            .runnerReturn,
            .presentation(false),
            .openURL,
        ])

        recorder.events.removeAll()
        presenter.presentFailure {
            XCTAssertFalse(presenter.isPresentingAlert)
            recorder.events.append(.retry)
        }
        XCTAssertEqual(recorder.events, [
            .presentation(true),
            .activation,
            .alert,
            .runnerReturn,
            .presentation(false),
            .retry,
        ])
    }

    func testReentrantPresentationIsDroppedWhileOuterAlertRemainsActive() {
        var alertRunCount = 0
        var activationCount = 0
        var presentationStates: [Bool] = []
        var openedURLs: [URL] = []
        var retryCount = 0
        var presenter: UpdateCheckAlertPresenter!
        presenter = UpdateCheckAlertPresenter(
            alertRunner: { _ in
                alertRunCount += 1
                XCTAssertTrue(presenter.isPresentingAlert)
                if alertRunCount == 1 {
                    presenter.presentUpdate(self.release(), currentVersion: "1.2.3")
                    XCTAssertTrue(presenter.isPresentingAlert)
                    presenter.presentFailure { retryCount += 1 }
                    XCTAssertTrue(presenter.isPresentingAlert)
                }
                return .alertFirstButtonReturn
            },
            urlOpener: { openedURLs.append($0) },
            applicationActivator: { activationCount += 1 }
        )
        presenter.onPresentationStateChange = { presentationStates.append($0) }

        presenter.presentUpToDate(currentVersion: "1.2.3")

        XCTAssertEqual(alertRunCount, 1)
        XCTAssertEqual(activationCount, 1)
        XCTAssertEqual(presentationStates, [true, false])
        XCTAssertTrue(openedURLs.isEmpty)
        XCTAssertEqual(retryCount, 0)
        XCTAssertFalse(presenter.isPresentingAlert)
    }

    private func setInterfaceLanguage(_ language: InterfaceLanguage) {
        var argumentDomain = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        argumentDomain[InkletPreferenceKeys.interfaceLanguage] = language.rawValue
        UserDefaults.standard.setVolatileDomain(argumentDomain, forName: UserDefaults.argumentDomain)
        NotificationCenter.default.post(name: .inkletLanguageDidChange, object: nil)
    }

    private func makePresenter(recorder: AlertRecorder) -> UpdateCheckAlertPresenter {
        UpdateCheckAlertPresenter(
            alertRunner: {
                recorder.events.append(.alert)
                recorder.contents.append($0)
                return recorder.response
            },
            urlOpener: { recorder.openedURLs.append($0) },
            applicationActivator: { recorder.events.append(.activation) }
        )
    }

    private func release(name: String? = "Faster dictation", notes: String = "Notes") -> InkletRelease {
        let tagName = "v2.0.0-200"
        return InkletRelease(
            version: try! InkletReleaseVersion(tagName: tagName),
            tagName: tagName,
            name: name,
            notes: notes,
            pageURL: URL(string: "https://github.com/wanming/Inklet/releases/tag/\(tagName)")!
        )
    }
}

@MainActor
private final class AlertRecorder {
    enum Event: Equatable {
        case presentation(Bool)
        case activation
        case alert
        case runnerReturn
        case openURL
        case retry
    }

    let response: NSApplication.ModalResponse
    var events: [Event] = []
    var contents: [UpdateCheckAlertPresenter.AlertContent] = []
    var openedURLs: [URL] = []

    init(response: NSApplication.ModalResponse) {
        self.response = response
    }
}
