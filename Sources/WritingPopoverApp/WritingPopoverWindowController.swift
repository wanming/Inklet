import AppKit
import SwiftUI

@MainActor
final class WritingPopoverWindowController: NSWindowController {
    private let model: WritingPopoverViewModel

    init() {
        self.model = WritingPopoverViewModel()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Fluenta"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        panel.contentView = NSHostingView(rootView: WritingPopoverView(model: model))

        super.init(window: panel)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        model.resetForOpen()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
