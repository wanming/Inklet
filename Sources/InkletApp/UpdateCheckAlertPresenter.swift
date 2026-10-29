import AppKit
import InkletCore

@MainActor
final class UpdateCheckAlertPresenter: UpdateCheckPresenting {
    private(set) var isPresentingAlert = false
    var onPresentationStateChange: (@MainActor (Bool) -> Void)?

    enum AlertStyle: Equatable {
        case informational
        case warning
    }

    struct AlertContent: Equatable {
        let messageText: String
        let informativeText: String
        /// Markdown release notes in the interface language, shown rendered in a scroll view.
        var releaseNotes: String? = nil
        let primaryButtonTitle: String
        let secondaryButtonTitle: String?
        let alertStyle: AlertStyle
    }

    private let alertRunner: @MainActor (AlertContent) -> NSApplication.ModalResponse
    private let urlOpener: @MainActor (URL) -> Void
    private let applicationActivator: @MainActor () -> Void

    init(
        alertRunner: @escaping @MainActor (AlertContent) -> NSApplication.ModalResponse = defaultAlertRunner,
        urlOpener: @escaping @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) },
        applicationActivator: @escaping @MainActor () -> Void = {
            NSApp.activate(ignoringOtherApps: true)
        }
    ) {
        self.alertRunner = alertRunner
        self.urlOpener = urlOpener
        self.applicationActivator = applicationActivator
    }

    func presentUpdate(_ release: InkletRelease, currentVersion: String) {
        // "Beta" stays English in every language, like the Beta label next to the app version.
        let latestVersion = release.isPrerelease
            ? "\(release.version.marketingVersion) Beta"
            : release.version.marketingVersion
        var components = [
            L10n.format(
                "update.available.latestVersion",
                latestVersion,
                String(release.version.buildNumber)
            ),
            L10n.format("update.available.currentVersion", currentVersion),
        ]

        if let releaseName = usefulReleaseName(for: release) {
            components.append(releaseName)
        }
        let releaseNotes = InkletReleaseNotes.section(
            of: release.notes,
            preferring: [L10n.resolvedLanguage.displayName, InterfaceLanguage.english.displayName],
            languageHeadings: InterfaceLanguage.allCases.filter { $0 != .system }.map(\.displayName)
        ).trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        if releaseNotes == nil {
            components.append(L10n.text("update.available.noNotes"))
        }

        let content = AlertContent(
            messageText: L10n.text("update.available.title"),
            informativeText: components.joined(separator: "\n\n"),
            releaseNotes: releaseNotes,
            primaryButtonTitle: L10n.text("update.action.viewOnGitHub"),
            secondaryButtonTitle: L10n.text("update.action.later"),
            alertStyle: .informational
        )
        let response = runAlert(content)
        if response == .alertFirstButtonReturn {
            urlOpener(release.pageURL)
        }
    }

    func presentUpToDate(currentVersion: String) {
        let content = AlertContent(
            messageText: L10n.text("update.upToDate.title"),
            informativeText: L10n.format("update.upToDate.message", currentVersion),
            primaryButtonTitle: L10n.text("update.action.ok"),
            secondaryButtonTitle: nil,
            alertStyle: .informational
        )
        _ = runAlert(content)
    }

    func presentFailure(retry: @escaping @MainActor () -> Void) {
        let content = AlertContent(
            messageText: L10n.text("update.error.title"),
            informativeText: L10n.text("update.error.message"),
            primaryButtonTitle: L10n.text("update.action.retry"),
            secondaryButtonTitle: L10n.text("update.action.cancel"),
            alertStyle: .warning
        )
        let response = runAlert(content)
        if response == .alertFirstButtonReturn {
            retry()
        }
    }

    private static func defaultAlertRunner(_ content: AlertContent) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = content.messageText
        alert.informativeText = content.informativeText
        if let releaseNotes = content.releaseNotes {
            alert.accessoryView = UpdateReleaseNotesView.accessoryView(for: releaseNotes)
        }
        alert.alertStyle = switch content.alertStyle {
        case .informational: .informational
        case .warning: .warning
        }
        alert.addButton(withTitle: content.primaryButtonTitle)
        if let secondaryButtonTitle = content.secondaryButtonTitle {
            alert.addButton(withTitle: secondaryButtonTitle)
        }
        return alert.runModal()
    }

    private func runAlert(_ content: AlertContent) -> NSApplication.ModalResponse? {
        guard !isPresentingAlert else {
            return nil
        }
        isPresentingAlert = true
        onPresentationStateChange?(true)
        defer {
            isPresentingAlert = false
            onPresentationStateChange?(false)
        }
        applicationActivator()
        return alertRunner(content)
    }

    private func usefulReleaseName(for release: InkletRelease) -> String? {
        guard let name = release.name?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
              !isVersionMetadata(name, for: release)
        else {
            return nil
        }
        return name
    }

    private func isVersionMetadata(_ name: String, for release: InkletRelease) -> Bool {
        let marketingVersion = release.version.marketingVersion
        let buildNumber = release.version.buildNumber
        let exactMetadata = [
            release.tagName,
            marketingVersion,
            "v\(marketingVersion)",
            "\(marketingVersion) (\(buildNumber))",
            "\(marketingVersion) (build \(buildNumber))",
            "Inklet \(marketingVersion) (\(buildNumber))",
            "Inklet \(marketingVersion) (build \(buildNumber))",
        ]
        if exactMetadata.contains(where: { $0.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return true
        }

        let pattern = #"^(?:inklet\s+)?v?\d+(?:\.\d+)*(?:\s+beta)?(?:[-\s]*(?:build\s*)?\d+)?(?:\s*\(\s*(?:build\s*)?\d+\s*\))?$"#
        return name.range(of: pattern, options: [.regularExpression, .caseInsensitive, .diacriticInsensitive]) != nil
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
