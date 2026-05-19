import AppKit
import SwiftUI

@MainActor
private final class WritingPopoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class WritingPopoverWindowController: NSWindowController {
    private let model: WritingPopoverViewModel
    private var previousApplication: NSRunningApplication?

    init() {
        self.model = WritingPopoverViewModel()

        let panel = WritingPopoverPanel(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 232),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.title = "Fluenta"
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        panel.contentView = NSHostingView(rootView: WritingPopoverView(model: model))

        super.init(window: panel)
        shouldCascadeWindows = false

        model.onHidePopover = { [weak self] in
            self?.window?.orderOut(nil)
        }
        model.onFocusPopover = { [weak self] in
            self?.focusPopover()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(fallbackApplication: NSRunningApplication? = nil) {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        if frontmostApplication?.processIdentifier == NSRunningApplication.current.processIdentifier {
            previousApplication = fallbackApplication
        } else {
            previousApplication = frontmostApplication ?? fallbackApplication
        }
        model.resetForOpen(previousApplication: previousApplication)
        focusPopover()
    }

    private func focusPopover() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
