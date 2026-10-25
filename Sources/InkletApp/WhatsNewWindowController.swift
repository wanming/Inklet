import AppKit
import SwiftUI
import InkletCore

struct WhatsNewFeature: Equatable {
    let systemImage: String
    let titleKey: String
    let detailKey: String
}

struct WhatsNewRelease: Equatable {
    let version: String
    let features: [WhatsNewFeature]
}

/// What each release adds, in every interface language. Add an entry for each release; a version
/// without one shows nothing after the update.
enum WhatsNewCatalog {
    static let releaseNotesURL = URL(string: "https://github.com/wanming/Inklet/releases")!

    static let releases: [WhatsNewRelease] = [
        WhatsNewRelease(version: "1.2.0", features: [
            WhatsNewFeature(
                systemImage: "cpu",
                titleKey: "whatsNew.1.2.0.builtIn.title",
                detailKey: "whatsNew.1.2.0.builtIn.detail"
            ),
            WhatsNewFeature(
                systemImage: "server.rack",
                titleKey: "whatsNew.1.2.0.localServers.title",
                detailKey: "whatsNew.1.2.0.localServers.detail"
            ),
            WhatsNewFeature(
                systemImage: "paintpalette",
                titleKey: "whatsNew.1.2.0.design.title",
                detailKey: "whatsNew.1.2.0.design.detail"
            ),
            WhatsNewFeature(
                systemImage: "keyboard",
                titleKey: "whatsNew.1.2.0.guide.title",
                detailKey: "whatsNew.1.2.0.guide.detail"
            ),
        ]),
    ]

    static var versions: [String] {
        releases.map(\.version)
    }

    static func releases(for versions: [String]) -> [WhatsNewRelease] {
        versions.compactMap { version in releases.first { $0.version == version } }
    }

    /// The notes for this version, or the newest older ones, for the menu item.
    static func latestRelease(upTo currentVersion: String) -> WhatsNewRelease? {
        releases
            .filter { !WhatsNewPolicy.isNewer($0.version, than: currentVersion) }
            .max { WhatsNewPolicy.isNewer($1.version, than: $0.version) }
    }
}

/// A small window listing what changed, shown once after an update. It is ordered front without
/// activating Inklet, so it never takes focus from the app the person is typing in.
@MainActor
final class WhatsNewWindowController: NSWindowController {
    init(releases: [WhatsNewRelease]) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = L10n.text("whatsNew.window.title")
        window.isReleasedWhenClosed = false
        super.init(window: window)
        shouldCascadeWindows = false
        let hostingView = NSHostingView(rootView: WhatsNewView(releases: releases) { [weak self] in
            self?.close()
        })
        window.contentView = hostingView
        window.setContentSize(hostingView.fittingSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(activating: Bool) {
        window?.center()
        if activating {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
        } else {
            window?.orderFrontRegardless()
        }
    }
}

struct WhatsNewView: View {
    let releases: [WhatsNewRelease]
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: InkletTheme.Spacing.xxs) {
                Text(L10n.text("whatsNew.title"))
                    .font(InkletTheme.Typography.pageTitle)
                    .foregroundStyle(InkletTheme.label)
                Text(L10n.format("whatsNew.version", releases.first?.version ?? ""))
                    .font(InkletTheme.Typography.help)
                    .foregroundStyle(InkletTheme.secondaryLabel)
            }
            .padding(.top, InkletTheme.Spacing.xxl)
            .padding(.bottom, InkletTheme.Spacing.lg)

            VStack(alignment: .leading, spacing: InkletTheme.Spacing.md) {
                ForEach(releases.flatMap(\.features), id: \.titleKey) { feature in
                    featureRow(feature)
                }
            }

            HStack {
                Button(L10n.text("whatsNew.fullNotes")) {
                    NSWorkspace.shared.open(WhatsNewCatalog.releaseNotesURL)
                }
                .buttonStyle(InkletButtonStyle(kind: .ghost))
                Spacer()
                Button(L10n.text("whatsNew.done"), action: onClose)
                    .buttonStyle(InkletButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, InkletTheme.Spacing.xl)
            .padding(.bottom, InkletTheme.Spacing.lg)
        }
        .padding(.horizontal, InkletTheme.Spacing.xl)
        .frame(width: 480, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(InkletTheme.surface)
    }

    private func featureRow(_ feature: WhatsNewFeature) -> some View {
        HStack(alignment: .top, spacing: InkletTheme.Spacing.sm) {
            Image(systemName: feature.systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(InkletTheme.accentText)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text(feature.titleKey))
                    .font(InkletTheme.Typography.control)
                    .foregroundStyle(InkletTheme.label)
                Text(L10n.text(feature.detailKey))
                    .font(InkletTheme.Typography.help)
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
