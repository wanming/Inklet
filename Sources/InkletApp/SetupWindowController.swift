import AppKit
import SwiftUI
import InkletCore

@MainActor
final class SetupWindowController: NSWindowController {
    var onOpenSettings: (() -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text("setup.window.title")
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SetupView())

        super.init(window: window)

        if let setupView = window.contentView as? NSHostingView<SetupView> {
            setupView.rootView = SetupView(
                onOpenSettings: { [weak self] in
                    self?.close()
                    self?.onOpenSettings?()
                },
                onDone: { [weak self] in
                    self?.close()
                }
            )
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.title = L10n.text("setup.window.title")
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SetupView: View {
    var onOpenSettings: () -> Void = {}
    var onDone: () -> Void = {}

    @State private var isAccessibilityTrusted = AccessibilityPermissionService().isTrusted

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(InkletTheme.primary)
                    .frame(width: 48, height: 48)
                    .background(InkletTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("setup.title"))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(InkletTheme.textPrimary)
                    Text(L10n.text("setup.subtitle"))
                        .font(.system(size: 13))
                        .foregroundStyle(InkletTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                setupRow(
                    icon: "menubar.rectangle",
                    title: L10n.text("setup.menubar.title"),
                    description: L10n.text("setup.menubar.description"),
                    color: InkletTheme.primary
                )
                setupRow(
                    icon: "keyboard",
                    title: L10n.text("setup.shortcut.title"),
                    description: L10n.format("setup.shortcut.description", AppConfig.defaultConfig().hotkey),
                    color: InkletTheme.primary
                )
                setupRow(
                    icon: isAccessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                    title: isAccessibilityTrusted ? L10n.text("settings.permission.authorized") : L10n.text("settings.permission.required"),
                    description: L10n.text("settings.permission.description"),
                    color: isAccessibilityTrusted ? InkletTheme.success : InkletTheme.warning
                )
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    openAccessibilitySettings()
                } label: {
                    Label(L10n.text("settings.permission.open"), systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onOpenSettings()
                } label: {
                    Label(L10n.text("app.menu.settings"), systemImage: "gearshape")
                }

                Spacer()

                Button(L10n.text("setup.done")) {
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26)
        .frame(width: 500, height: 360)
        .background(InkletTheme.panelBackground)
        .onAppear {
            isAccessibilityTrusted = AccessibilityPermissionService().isTrusted
        }
    }

    private func setupRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(InkletTheme.textPrimary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(InkletTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
