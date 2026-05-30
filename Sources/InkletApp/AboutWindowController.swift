import AppKit
import SwiftUI

@MainActor
final class AboutWindowController: NSWindowController {
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
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.title = L10n.text("app.menu.about")
        window?.contentView = NSHostingView(rootView: AboutView())
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            PenNibShape()
                .stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                .foregroundStyle(InkletTheme.primary)
                .padding(18)
                .frame(width: 76, height: 76)
                .background(InkletTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(InkletTheme.primary.opacity(0.20))
                }

            VStack(spacing: 5) {
                Text("Inklet")
                    .font(.title2)
                    .bold()
                Text(L10n.format("settings.version", BuildInfo.displayVersion))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(L10n.text("about.tagline"))
                .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)

            HStack(spacing: 16) {
                Link(L10n.text("about.website"), destination: URL(string: "https://getinklet.app")!)
                Link(L10n.text("about.privacyPolicy"), destination: URL(string: "https://getinklet.app/privacy")!)
                Link(L10n.text("about.support"), destination: URL(string: "mailto:support@getinklet.app")!)
            }
            .font(.callout)

            Text("© 2026 Inklet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(width: 380, height: 292)
    }
}
