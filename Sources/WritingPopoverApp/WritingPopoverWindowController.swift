import AppKit
import Combine
import SwiftUI

@MainActor
private final class WritingPopoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class ClearHostingView<Content: View>: NSHostingView<Content> {
    private let cornerRadius: CGFloat = 12

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureLayer()
    }

    override func layout() {
        super.layout()
        configureLayer()
    }

    private func configureLayer() {
        wantsLayer = true
        guard let layer else { return }
        layer.backgroundColor = NSColor.clear.cgColor
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
    }
}

@MainActor
final class WritingPopoverWindowController: NSWindowController {
    private let model: WritingPopoverViewModel
    private var previousApplication: NSRunningApplication?
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.model = WritingPopoverViewModel()

        let panel = WritingPopoverPanel(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 168),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.title = "Fluenta"
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        panel.contentView = ClearHostingView(rootView: WritingPopoverView(model: model))

        super.init(window: panel)
        shouldCascadeWindows = false

        model.$preferredPopoverHeight
            .removeDuplicates()
            .sink { [weak self] height in
                self?.resizePopover(to: height)
            }
            .store(in: &cancellables)

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

    private func resizePopover(to height: CGFloat) {
        guard let window else {
            return
        }

        var frame = window.frame
        guard abs(frame.height - height) > 0.5 else {
            return
        }

        let topY = frame.maxY
        frame.size.height = height
        frame.origin.y = topY - height
        window.setFrame(frame, display: true, animate: false)
    }
}
