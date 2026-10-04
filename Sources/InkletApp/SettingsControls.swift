import AppKit
import Carbon
import SwiftUI
import InkletCore

struct PromptModeTableView: NSViewRepresentable {
    let modes: [PromptMode]
    @Binding var selectedModeID: String
    let canDelete: Bool
    let onMove: (Int, Int) -> Void
    let onToggleVisibility: (String) -> Void
    let onDelete: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            modes: modes,
            selectedModeID: $selectedModeID,
            canDelete: canDelete,
            onMove: onMove,
            onToggleVisibility: onToggleVisibility,
            onDelete: onDelete
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = NSTableView()
        let column = NSTableColumn(identifier: Coordinator.columnIdentifier)
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 38
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.registerForDraggedTypes([Coordinator.dragPasteboardType])

        let scrollView = PromptModeTableScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = tableView
        context.coordinator.tableView = tableView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.modes = modes
        context.coordinator.selectedModeID = $selectedModeID
        context.coordinator.canDelete = canDelete
        context.coordinator.onMove = onMove
        context.coordinator.onToggleVisibility = onToggleVisibility
        context.coordinator.onDelete = onDelete

        guard let tableView = scrollView.documentView as? NSTableView else {
            return
        }

        PromptModeTableScrollView.syncTableWidth(tableView, to: scrollView.contentView.bounds.width)

        tableView.reloadData()
        context.coordinator.syncSelection()
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        static let columnIdentifier = NSUserInterfaceItemIdentifier("PromptModeColumn")
        static let rowIdentifier = NSUserInterfaceItemIdentifier("PromptModeRow")
        static let dragPasteboardType = NSPasteboard.PasteboardType("com.inklet.prompt-mode")

        var modes: [PromptMode]
        var selectedModeID: Binding<String>
        var canDelete: Bool
        var onMove: (Int, Int) -> Void
        var onToggleVisibility: (String) -> Void
        var onDelete: (String) -> Void
        weak var tableView: NSTableView?
        private var isSyncingSelection = false

        init(
            modes: [PromptMode],
            selectedModeID: Binding<String>,
            canDelete: Bool,
            onMove: @escaping (Int, Int) -> Void,
            onToggleVisibility: @escaping (String) -> Void,
            onDelete: @escaping (String) -> Void
        ) {
            self.modes = modes
            self.selectedModeID = selectedModeID
            self.canDelete = canDelete
            self.onMove = onMove
            self.onToggleVisibility = onToggleVisibility
            self.onDelete = onDelete
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            modes.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard modes.indices.contains(row) else {
                return nil
            }

            let cell = (tableView.makeView(withIdentifier: Self.rowIdentifier, owner: self) as? PromptModeTableCellView)
                ?? PromptModeTableCellView(identifier: Self.rowIdentifier)
            let mode = modes[row]
            cell.configure(
                mode: mode,
                isSelected: mode.id == selectedModeID.wrappedValue,
                canDelete: canDelete,
                target: self
            )
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isSyncingSelection,
                  let tableView,
                  modes.indices.contains(tableView.selectedRow)
            else {
                return
            }

            selectedModeID.wrappedValue = modes[tableView.selectedRow].id
        }

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard modes.indices.contains(row) else {
                return nil
            }

            let item = NSPasteboardItem()
            item.setString(modes[row].id, forType: Self.dragPasteboardType)
            return item
        }

        func tableView(
            _ tableView: NSTableView,
            validateDrop info: NSDraggingInfo,
            proposedRow row: Int,
            proposedDropOperation dropOperation: NSTableView.DropOperation
        ) -> NSDragOperation {
            tableView.setDropRow(row, dropOperation: .above)
            return .move
        }

        func tableView(
            _ tableView: NSTableView,
            acceptDrop info: NSDraggingInfo,
            row: Int,
            dropOperation: NSTableView.DropOperation
        ) -> Bool {
            guard let draggedModeID = info.draggingPasteboard.string(forType: Self.dragPasteboardType),
                  let sourceIndex = modes.firstIndex(where: { $0.id == draggedModeID })
            else {
                return false
            }

            let destination = max(0, min(row, modes.count))
            guard sourceIndex != destination, sourceIndex + 1 != destination else {
                return false
            }

            onMove(sourceIndex, destination)
            selectedModeID.wrappedValue = draggedModeID
            return true
        }

        @MainActor
        func syncSelection() {
            guard let tableView else {
                return
            }

            isSyncingSelection = true
            defer { isSyncingSelection = false }

            if let selectedIndex = modes.firstIndex(where: { $0.id == selectedModeID.wrappedValue }) {
                tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
            } else {
                tableView.deselectAll(nil)
            }
        }

        @MainActor
        @objc func toggleVisibility(_ sender: NSButton) {
            guard let modeID = sender.identifier?.rawValue else {
                return
            }
            onToggleVisibility(modeID)
        }

        @MainActor
        @objc func deleteMode(_ sender: NSButton) {
            guard let modeID = sender.identifier?.rawValue else {
                return
            }
            onDelete(modeID)
        }
    }
}

private final class PromptModeTableScrollView: NSScrollView {
    override func layout() {
        super.layout()
        guard let tableView = documentView as? NSTableView else {
            return
        }
        Self.syncTableWidth(tableView, to: contentView.bounds.width)
    }

    static func syncTableWidth(_ tableView: NSTableView, to width: CGFloat) {
        let width = max(width, 1)
        guard tableView.tableColumns.first?.width != width else {
            return
        }

        tableView.tableColumns.first?.width = width
        var frame = tableView.frame
        frame.size.width = width
        tableView.frame = frame
    }
}

private final class PromptModeTableCellView: NSTableCellView {
    private static let rowWidth: CGFloat = 190
    private let rowContainer = NSView()
    private let selectionBackground = NSView()
    private let dragHandle = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let visibilityButton = NSButton()
    private let deleteButton = NSButton()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isCellSelected = false
    private var isModeVisible = true
    private var canDeleteMode = true

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        buildView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        mode: PromptMode,
        isSelected: Bool,
        canDelete: Bool,
        target: PromptModeTableView.Coordinator
    ) {
        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        isCellSelected = isSelected
        isModeVisible = mode.isVisible
        canDeleteMode = canDelete
        titleField.stringValue = mode.name.isEmpty ? L10n.text("settings.mode.untitled") : mode.localizedName
        titleField.font = .systemFont(ofSize: 13, weight: isSelected ? .semibold : .regular)
        visibilityButton.image = NSImage(systemSymbolName: mode.isVisible ? "eye" : "eye.slash", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
        visibilityButton.toolTip = mode.isVisible ? L10n.text("settings.mode.visible") : L10n.text("settings.mode.hidden")
        visibilityButton.identifier = NSUserInterfaceItemIdentifier(mode.id)
        visibilityButton.target = target
        visibilityButton.action = #selector(PromptModeTableView.Coordinator.toggleVisibility(_:))

        deleteButton.identifier = NSUserInterfaceItemIdentifier(mode.id)
        deleteButton.target = target
        deleteButton.action = #selector(PromptModeTableView.Coordinator.deleteMode(_:))
        deleteButton.isEnabled = canDelete
        deleteButton.toolTip = L10n.text("settings.mode.delete")
        applyAppearance()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        applyAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        applyAppearance()
    }

    private func buildView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        rowContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowContainer)

        selectionBackground.wantsLayer = true
        selectionBackground.layer?.cornerRadius = 12
        selectionBackground.layer?.cornerCurve = .continuous
        selectionBackground.layer?.backgroundColor = NSColor.clear.cgColor
        selectionBackground.translatesAutoresizingMaskIntoConstraints = false
        rowContainer.addSubview(selectionBackground)

        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        dragHandle.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
        dragHandle.contentTintColor = NSColor(white: 1, alpha: 0.18)
        dragHandle.setContentHuggingPriority(.required, for: .horizontal)
        dragHandle.setContentCompressionResistancePriority(.required, for: .horizontal)
        dragHandle.toolTip = L10n.text("settings.mode.dragToSort")
        dragHandle.translatesAutoresizingMaskIntoConstraints = false

        titleField.lineBreakMode = .byTruncatingTail
        titleField.textColor = NSColor(white: 0.74, alpha: 1)
        titleField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleField.translatesAutoresizingMaskIntoConstraints = false

        configureIconButton(visibilityButton)
        configureIconButton(deleteButton)
        deleteButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
        deleteButton.contentTintColor = NSColor(white: 1, alpha: 0.32)

        rowContainer.addSubview(dragHandle)
        rowContainer.addSubview(titleField)
        rowContainer.addSubview(visibilityButton)
        rowContainer.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            rowContainer.widthAnchor.constraint(equalToConstant: Self.rowWidth),
            rowContainer.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -16),
            rowContainer.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            rowContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            selectionBackground.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor),
            selectionBackground.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor),
            selectionBackground.topAnchor.constraint(equalTo: rowContainer.topAnchor),
            selectionBackground.bottomAnchor.constraint(equalTo: rowContainer.bottomAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 18),
            visibilityButton.widthAnchor.constraint(equalToConstant: 24),
            visibilityButton.heightAnchor.constraint(equalToConstant: 24),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24),
            dragHandle.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor, constant: 14),
            dragHandle.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor),
            titleField.leadingAnchor.constraint(equalTo: dragHandle.trailingAnchor, constant: 10),
            titleField.trailingAnchor.constraint(equalTo: visibilityButton.leadingAnchor, constant: -8),
            titleField.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor),
            visibilityButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -4),
            visibilityButton.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor, constant: -10),
            deleteButton.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor)
        ])
    }

    private func applyAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        selectionBackground.layer?.backgroundColor = isCellSelected
            ? NSColor.controlAccentColor.withAlphaComponent(isDark ? 0.20 : 0.14).cgColor
            : (isHovered ? NSColor.labelColor.withAlphaComponent(isDark ? 0.04 : 0.045).cgColor : NSColor.clear.cgColor)
        titleField.textColor = isCellSelected
            ? NSColor.controlAccentColor
            : (isHovered ? .labelColor : .secondaryLabelColor)
        dragHandle.contentTintColor = isHovered || isCellSelected
            ? .secondaryLabelColor
            : .tertiaryLabelColor
        visibilityButton.contentTintColor = isModeVisible
            ? .secondaryLabelColor
            : .tertiaryLabelColor
        visibilityButton.alphaValue = isHovered || isCellSelected ? 1 : 0.78
        deleteButton.contentTintColor = canDeleteMode
            ? .secondaryLabelColor
            : .tertiaryLabelColor
        deleteButton.alphaValue = isHovered || isCellSelected ? 1 : 0.64
    }

    private func configureIconButton(_ button: NSButton) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryChange)
        button.imagePosition = .imageOnly
        button.focusRingType = .none
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}

struct SettingsPromptTextView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.contentInsets = NSEdgeInsetsZero
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.horizontalScrollElasticity = .none

        let textView = NSTextView()
        textView.string = text
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        context.coordinator.text = $text
        context.coordinator.textView = textView
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor

        if !textView.hasMarkedText(), textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate, @unchecked Sendable {
        var text: Binding<String>
        weak var textView: NSTextView?

        init(text: Binding<String>) {
            self.text = text
            super.init()
        }

        @MainActor
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            text.wrappedValue = textView.string
        }
    }
}

struct HotkeyRecorderField: NSViewRepresentable {
    @Binding var hotkey: String

    func makeCoordinator() -> Coordinator {
        Coordinator(hotkey: $hotkey)
    }

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onChange = { context.coordinator.hotkey.wrappedValue = $0 }
        view.hotkey = hotkey
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.hotkey = hotkey
        nsView.onChange = { context.coordinator.hotkey.wrappedValue = $0 }
        nsView.updateDisplay()
    }

    final class Coordinator {
        var hotkey: Binding<String>

        init(hotkey: Binding<String>) {
            self.hotkey = hotkey
        }
    }

    final class RecorderView: NSView {
        var hotkey = ""
        var onChange: ((String) -> Void)?
        private var isRecording = false
        private let label = NSTextField(labelWithString: "")

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.cornerRadius = 8
            layer?.borderWidth = 1
            label.translatesAutoresizingMaskIntoConstraints = false
            label.alignment = .center
            label.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
            addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                label.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            updateDisplay()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var acceptsFirstResponder: Bool { true }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            updateDisplay()
        }

        override func mouseDown(with event: NSEvent) {
            isRecording = true
            publishRecordingState()
            window?.makeFirstResponder(self)
            updateDisplay()
        }

        override func resignFirstResponder() -> Bool {
            isRecording = false
            publishRecordingState()
            updateDisplay()
            return super.resignFirstResponder()
        }

        override func keyDown(with event: NSEvent) {
            guard isRecording else {
                super.keyDown(with: event)
                return
            }

            if event.keyCode == UInt16(kVK_Escape) {
                isRecording = false
                publishRecordingState()
                window?.makeFirstResponder(nil)
                updateDisplay()
                return
            }

            guard let recordedHotkey = recordedHotkey(from: event) else {
                NSSound.beep()
                return
            }

            hotkey = recordedHotkey.displayString
            onChange?(hotkey)
            isRecording = false
            publishRecordingState()
            window?.makeFirstResponder(nil)
            updateDisplay()
        }

        override func flagsChanged(with event: NSEvent) {
            if isRecording {
                updateDisplay(pressedModifiers: modifierDisplayString(from: event.modifierFlags))
            } else {
                super.flagsChanged(with: event)
            }
        }

        func updateDisplay(pressedModifiers: String = "") {
            let backgroundColor = isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.16) : NSColor.controlBackgroundColor
            layer?.backgroundColor = resolvedCGColor(backgroundColor)
            layer?.borderColor = resolvedCGColor(isRecording ? .controlAccentColor : .separatorColor)
            label.textColor = isRecording ? .controlAccentColor : .labelColor
            if isRecording {
                label.stringValue = pressedModifiers.isEmpty
                    ? L10n.text("settings.hotkey.recording")
                    : "\(pressedModifiers)\(L10n.text("settings.hotkey.pressKey"))"
            } else {
                label.stringValue = hotkey.isEmpty ? L10n.text("settings.hotkey.record") : hotkey
            }
        }

        private func resolvedCGColor(_ color: NSColor) -> CGColor {
            var resolvedColor = color.cgColor
            effectiveAppearance.performAsCurrentDrawingAppearance {
                resolvedColor = color.cgColor
            }
            return resolvedColor
        }

        private func recordedHotkey(from event: NSEvent) -> Hotkey? {
            var modifiers: Hotkey.Modifier = []
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.command) { modifiers.insert(.command) }
            if flags.contains(.option) { modifiers.insert(.option) }
            if flags.contains(.control) { modifiers.insert(.control) }
            if flags.contains(.shift) { modifiers.insert(.shift) }

            guard !modifiers.isEmpty,
                  modifiers != [.shift],
                  Hotkey.displayName(for: UInt32(event.keyCode)) != nil
            else {
                return nil
            }

            return Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        }

        private func modifierDisplayString(from flags: NSEvent.ModifierFlags) -> String {
            var modifiers: Hotkey.Modifier = []
            let filteredFlags = flags.intersection(.deviceIndependentFlagsMask)
            if filteredFlags.contains(.command) { modifiers.insert(.command) }
            if filteredFlags.contains(.option) { modifiers.insert(.option) }
            if filteredFlags.contains(.control) { modifiers.insert(.control) }
            if filteredFlags.contains(.shift) { modifiers.insert(.shift) }
            return modifiers.displayString
        }

        private func publishRecordingState() {
            NotificationCenter.default.post(
                name: .hotkeyRecordingDidChange,
                object: nil,
                userInfo: ["isRecording": isRecording]
            )
        }
    }
}
