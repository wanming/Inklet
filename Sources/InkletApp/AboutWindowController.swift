import AppKit
import Combine
import SwiftUI

@MainActor
final class AboutWindowController: NSWindowController {
    private var languageChangeCancellable: AnyCancellable?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text("app.menu.about")
        window.contentView = NSHostingView(rootView: AboutView())
        window.isReleasedWhenClosed = false

        super.init(window: window)
        shouldCascadeWindows = false
        refreshLocalizedContent()
        languageChangeCancellable = NotificationCenter.default.publisher(for: .inkletLanguageDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLocalizedContent()
            }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        refreshLocalizedContent()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func refreshLocalizedContent() {
        window?.title = L10n.text("app.menu.about")
        guard let hostingView = window?.contentView as? NSHostingView<AboutView> else { return }
        hostingView.rootView = AboutView()
        window?.setContentSize(hostingView.fittingSize)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: InkletTheme.Spacing.md) {
            PenNibShape()
                .stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                .foregroundStyle(InkletTheme.accentText)
                .padding(18)
                .frame(width: 76, height: 76)
                .background(InkletTheme.accentSoft, in: RoundedRectangle(cornerRadius: 20))

            VStack(spacing: InkletTheme.Spacing.xxs) {
                Text("Inklet")
                    .font(InkletTheme.Typography.pageTitle)
                    .tracking(-0.2)
                    .foregroundStyle(InkletTheme.label)
                Text(L10n.format("settings.version", BuildInfo.displayVersion))
                    .font(InkletTheme.Typography.caption)
                    .foregroundStyle(InkletTheme.tertiaryLabel)
            }

            Text(L10n.text("about.tagline"))
                .font(InkletTheme.Typography.body)
                .foregroundStyle(InkletTheme.secondaryLabel)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: InkletTheme.Spacing.md) { links }
                VStack(spacing: InkletTheme.Spacing.xs) { links }
            }
            .font(InkletTheme.Typography.control)
            .tint(InkletTheme.accentText)

            Text("© 2026 Inklet")
                .font(InkletTheme.Typography.caption)
                .foregroundStyle(InkletTheme.tertiaryLabel)
        }
        .padding(28)
        .frame(width: 380)
        .frame(minHeight: 292)
        .environment(\.locale, Locale(identifier: L10n.resolvedLanguage.localeIdentifier))
    }

    private var links: some View {
        Group {
            Link(L10n.text("about.website"), destination: URL(string: "https://getinklet.app")!)
            Link(L10n.text("about.privacyPolicy"), destination: URL(string: "https://getinklet.app/privacy")!)
            Link(L10n.text("about.support"), destination: URL(string: "mailto:support@getinklet.app")!)
        }
    }
}
