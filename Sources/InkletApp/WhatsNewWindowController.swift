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
        WhatsNewRelease(version: "2.1.0", features: [
            WhatsNewFeature(
                systemImage: "speaker.wave.2",
                titleKey: "whatsNew.2.1.0.systemVoice.title",
                detailKey: "whatsNew.2.1.0.systemVoice.detail"
            ),
            WhatsNewFeature(
                systemImage: "text.alignleft",
                titleKey: "whatsNew.2.1.0.plainText.title",
                detailKey: "whatsNew.2.1.0.plainText.detail"
            ),
            WhatsNewFeature(
                systemImage: "testtube.2",
                titleKey: "whatsNew.2.1.0.beta.title",
                detailKey: "whatsNew.2.1.0.beta.detail"
            ),
        ]),
        WhatsNewRelease(version: "2.0.0", features: [
            WhatsNewFeature(
                systemImage: "cpu",
                titleKey: "whatsNew.2.0.0.builtIn.title",
                detailKey: "whatsNew.2.0.0.builtIn.detail"
            ),
            WhatsNewFeature(
                systemImage: "server.rack",
                titleKey: "whatsNew.2.0.0.localServers.title",
                detailKey: "whatsNew.2.0.0.localServers.detail"
            ),
            WhatsNewFeature(
                systemImage: "paintpalette",
                titleKey: "whatsNew.2.0.0.design.title",
                detailKey: "whatsNew.2.0.0.design.detail"
            ),
            WhatsNewFeature(
                systemImage: "mic",
                titleKey: "whatsNew.2.0.0.dictation.title",
                detailKey: "whatsNew.2.0.0.dictation.detail"
            ),
        ]),
    ]

    static var versions: [String] {
        releases.map(\.version)
    }

    static func releases(for versions: [String]) -> [WhatsNewRelease] {
        versions.compactMap { version in releases.first { $0.version == version } }
    }

    /// Every release up to this version, newest first, for the changelog.
    static func changelog(upTo currentVersion: String) -> [WhatsNewRelease] {
        releases
            .filter { !WhatsNewPolicy.isNewer($0.version, than: currentVersion) }
            .sorted { WhatsNewPolicy.isNewer($0.version, than: $1.version) }
    }
}

/// A small window listing what changed. After an update it shows the new versions once, ordered front
/// without activating Inklet so it never takes focus from the app the person is typing in. From the
/// menu it shows the whole changelog with the running version highlighted.
@MainActor
final class WhatsNewWindowController: NSWindowController {
    init(releases: [WhatsNewRelease], style: WhatsNewView.Style, currentVersion: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = style == .changelog
            ? L10n.text("whatsNew.changelog.title")
            : L10n.text("whatsNew.window.title")
        window.isReleasedWhenClosed = false
        super.init(window: window)
        shouldCascadeWindows = false
        let hostingView = NSHostingView(rootView: WhatsNewView(
            releases: releases,
            style: style,
            currentVersion: currentVersion
        ) { [weak self] in
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
    enum Style {
        /// The versions added since the last launch, shown once after an update.
        case update
        /// Every release, newest first, opened from the menu.
        case changelog
    }

    let releases: [WhatsNewRelease]
    let style: Style
    let currentVersion: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, InkletTheme.Spacing.xxl)
                .padding(.bottom, InkletTheme.Spacing.lg)

            switch style {
            case .update:
                featureList(releases.flatMap(\.features))
            case .changelog:
                ScrollView {
                    VStack(alignment: .leading, spacing: InkletTheme.Spacing.sm) {
                        ForEach(releases, id: \.version) { release in
                            changelogSection(release)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
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
        .frame(width: 480, height: style == .changelog ? 560 : nil, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: style == .update)
        .background(InkletTheme.surface)
    }

    @ViewBuilder
    private var header: some View {
        switch style {
        case .update:
            VStack(alignment: .leading, spacing: InkletTheme.Spacing.xxs) {
                Text(L10n.text("whatsNew.title"))
                    .font(InkletTheme.Typography.pageTitle)
                    .foregroundStyle(InkletTheme.label)
                Text(L10n.format("whatsNew.version", releases.first?.version ?? ""))
                    .font(InkletTheme.Typography.help)
                    .foregroundStyle(InkletTheme.secondaryLabel)
            }
        case .changelog:
            Text(L10n.text("whatsNew.changelog.title"))
                .font(InkletTheme.Typography.pageTitle)
                .foregroundStyle(InkletTheme.label)
        }
    }

    private func changelogSection(_ release: WhatsNewRelease) -> some View {
        let isCurrent = release.version == currentVersion
        return VStack(alignment: .leading, spacing: InkletTheme.Spacing.sm) {
            HStack(spacing: InkletTheme.Spacing.xs) {
                Text(L10n.format("whatsNew.version", release.version))
                    .font(InkletTheme.Typography.title)
                    .foregroundStyle(InkletTheme.label)
                if isCurrent {
                    // A beta build shares its version's notes, so the running beta is marked here.
                    Text(BuildInfo.isBeta ? "\(L10n.text("whatsNew.changelog.current")) · Beta" : L10n.text("whatsNew.changelog.current"))
                        .font(InkletTheme.Typography.caption)
                        .foregroundStyle(InkletTheme.accentText)
                        .padding(.horizontal, InkletTheme.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(InkletTheme.accentSoft, in: Capsule())
                }
            }
            featureList(release.features)
        }
        .padding(InkletTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isCurrent ? InkletTheme.accentSoft.opacity(0.5) : Color.clear,
            in: RoundedRectangle(cornerRadius: InkletTheme.Radius.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: InkletTheme.Radius.card)
                .stroke(isCurrent ? InkletTheme.accentSoft : InkletTheme.hairline)
        }
    }

    private func featureList(_ features: [WhatsNewFeature]) -> some View {
        VStack(alignment: .leading, spacing: InkletTheme.Spacing.md) {
            ForEach(features, id: \.titleKey) { feature in
                featureRow(feature)
            }
        }
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
