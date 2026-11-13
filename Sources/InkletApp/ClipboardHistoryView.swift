import AppKit
import SwiftUI
import InkletCore

/// State of the clipboard history panel: the search, the visible items and the selection.
@MainActor
final class ClipboardHistoryPanelModel: ObservableObject {
    @Published var query = "" {
        didSet {
            guard query != oldValue else { return }
            refilter(resetSelection: true)
        }
    }
    @Published private(set) var visibleItems: [ClipboardHistoryItem] = []
    @Published var selectedID: UUID?
    @Published private(set) var isEnabled = true
    @Published private(set) var canPaste = true
    @Published private(set) var focusRevision = 0
    @Published private(set) var hasAnyItems = false

    var onPaste: ((ClipboardHistoryItem) -> Void)?
    var onCopy: ((ClipboardHistoryItem) -> Void)?
    var onClose: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private let store: ClipboardHistoryStore
    private var imageCache: [UUID: NSImage] = [:]

    init(store: ClipboardHistoryStore) {
        self.store = store
        store.onChange = { [weak self] in
            self?.refilter(resetSelection: false)
        }
    }

    var selectedItem: ClipboardHistoryItem? {
        guard let selectedID else { return nil }
        return visibleItems.first { $0.id == selectedID }
    }

    var hasPinnedItems: Bool {
        visibleItems.contains { $0.isPinned }
    }

    func prepareForPresentation(isEnabled: Bool, canPaste: Bool) {
        self.isEnabled = isEnabled
        self.canPaste = canPaste
        query = ""
        refilter(resetSelection: true)
        focusRevision += 1
    }

    func didHide() {
        imageCache.removeAll()
    }

    func select(_ item: ClipboardHistoryItem) {
        selectedID = item.id
    }

    func moveSelection(by offset: Int) {
        guard !visibleItems.isEmpty else { return }
        let currentIndex = selectedID.flatMap { id in visibleItems.firstIndex { $0.id == id } } ?? -1
        let nextIndex = min(max(currentIndex + offset, 0), visibleItems.count - 1)
        selectedID = visibleItems[nextIndex].id
    }

    func pasteSelected() {
        guard let selectedItem else { return }
        onPaste?(selectedItem)
    }

    func copySelected() {
        guard let selectedItem else { return }
        onCopy?(selectedItem)
    }

    func togglePinSelected() {
        guard let selectedItem else { return }
        store.setPinned(!selectedItem.isPinned, itemID: selectedItem.id)
    }

    func deleteSelected() {
        guard let selectedItem,
              let index = visibleItems.firstIndex(where: { $0.id == selectedItem.id })
        else {
            return
        }
        let neighbor = visibleItems.indices.contains(index + 1)
            ? visibleItems[index + 1]
            : (index > 0 ? visibleItems[index - 1] : nil)
        imageCache[selectedItem.id] = nil
        store.delete(itemID: selectedItem.id)
        selectedID = neighbor?.id
    }

    func close() {
        onClose?()
    }

    func openSettings() {
        onOpenSettings?()
    }

    func image(for item: ClipboardHistoryItem) -> NSImage? {
        if let cached = imageCache[item.id] {
            return cached
        }
        guard let url = store.imageURL(for: item),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        imageCache[item.id] = image
        return image
    }

    private func refilter(resetSelection: Bool) {
        hasAnyItems = !store.items.isEmpty
        visibleItems = ClipboardHistoryStore.filter(store.items, query: query)
        if resetSelection || !visibleItems.contains(where: { $0.id == selectedID }) {
            selectedID = visibleItems.first?.id
        }
    }
}

struct ClipboardHistoryView: View {
    static let size = NSSize(width: 760, height: 460)
    static let headerHeight: CGFloat = 52
    static let rowHeight: CGFloat = 40
    static let listWidth: CGFloat = 300

    @ObservedObject var model: ClipboardHistoryPanelModel

    /// Dates follow Inklet's interface language rather than the system's.
    private var locale: Locale {
        Locale(identifier: L10n.resolvedLanguage.localeIdentifier)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            hairline
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            hairline
            footer
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .inkletFloatingPanel(cornerRadius: InkletTheme.Radius.panel)
    }

    private var hairline: some View {
        InkletTheme.hairline.frame(height: 1)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: InkletTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: InkletTheme.IconSize.large, weight: .medium))
                .foregroundStyle(InkletTheme.secondaryLabel)
            ClipboardHistorySearchField(
                text: $model.query,
                placeholder: L10n.text("clipboard.search.placeholder"),
                focusRevision: model.focusRevision,
                onCommand: handleSearchCommand
            )
            .frame(maxWidth: .infinity, minHeight: InkletTheme.ControlHeight.regular)
            .disabled(!model.isEnabled)

            Button {
                model.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(InkletIconButtonStyle())
            .help(L10n.text("clipboard.openSettings"))
            .accessibilityLabel(L10n.text("clipboard.openSettings"))
        }
        .padding(.leading, InkletTheme.Spacing.md)
        .padding(.trailing, InkletTheme.Spacing.xs)
        .frame(height: Self.headerHeight)
    }

    private func handleSearchCommand(_ command: ClipboardHistorySearchField.Command) {
        switch command {
        case .moveUp: model.moveSelection(by: -1)
        case .moveDown: model.moveSelection(by: 1)
        case .submit: model.pasteSelected()
        case .cancel: model.close()
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if !model.isEnabled {
            emptyState(
                systemImage: "clipboard",
                title: L10n.text("clipboard.disabled.title"),
                message: L10n.text("clipboard.disabled.message"),
                showsSettingsButton: true
            )
        } else if model.visibleItems.isEmpty {
            if model.hasAnyItems {
                emptyState(
                    systemImage: "magnifyingglass",
                    title: L10n.text("clipboard.noMatches"),
                    message: "",
                    showsSettingsButton: false
                )
            } else {
                emptyState(
                    systemImage: "clipboard",
                    title: L10n.text("clipboard.empty.title"),
                    message: L10n.text("clipboard.empty.message"),
                    showsSettingsButton: false
                )
            }
        } else {
            HStack(spacing: 0) {
                list
                    .frame(width: Self.listWidth)
                InkletTheme.hairline.frame(width: 1)
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func emptyState(
        systemImage: String,
        title: String,
        message: String,
        showsSettingsButton: Bool
    ) -> some View {
        VStack(spacing: InkletTheme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(InkletTheme.Typography.pageTitle)
                .foregroundStyle(InkletTheme.tertiaryLabel)
            Text(title)
                .font(InkletTheme.Typography.title)
                .foregroundStyle(InkletTheme.label)
            if !message.isEmpty {
                Text(message)
                    .font(InkletTheme.Typography.help)
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showsSettingsButton {
                Button(L10n.text("clipboard.openSettings")) {
                    model.openSettings()
                }
                .buttonStyle(InkletButtonStyle(kind: .primary))
                .padding(.top, InkletTheme.Spacing.xs)
            }
        }
        .padding(InkletTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.visibleItems.enumerated()), id: \.element.id) { index, item in
                        if let title = sectionTitle(at: index) {
                            sectionHeader(title)
                        }
                        ClipboardHistoryRow(
                            item: item,
                            image: item.kind == .image ? model.image(for: item) : nil,
                            isSelected: model.selectedID == item.id,
                            relativeTime: relativeTime(item.lastCopiedAt),
                            onSelect: { model.select(item) },
                            onPaste: {
                                model.select(item)
                                model.pasteSelected()
                            }
                        )
                        .id(item.id)
                        .contextMenu { contextMenu(for: item) }
                    }
                }
                .padding(.vertical, InkletTheme.Spacing.xxs)
            }
            .onChange(of: model.selectedID) { _, selectedID in
                guard let selectedID else { return }
                proxy.scrollTo(selectedID)
            }
        }
    }

    /// Headers appear only when some items are pinned: "Pinned" above them, "Recent" above the rest.
    private func sectionTitle(at index: Int) -> String? {
        guard model.hasPinnedItems else { return nil }
        let item = model.visibleItems[index]
        let previous = index > 0 ? model.visibleItems[index - 1] : nil
        guard previous == nil || previous?.isPinned != item.isPinned else { return nil }
        return L10n.text(item.isPinned ? "clipboard.section.pinned" : "clipboard.section.recent")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(InkletTheme.Typography.caption)
            .foregroundStyle(InkletTheme.tertiaryLabel)
            .padding(.horizontal, InkletTheme.Spacing.md)
            .padding(.top, InkletTheme.Spacing.xs)
            .padding(.bottom, InkletTheme.Spacing.xxs)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func contextMenu(for item: ClipboardHistoryItem) -> some View {
        Button(L10n.text(model.canPaste ? "clipboard.action.paste" : "clipboard.action.copy")) {
            model.select(item)
            model.pasteSelected()
        }
        Button(L10n.text("clipboard.action.copy")) {
            model.select(item)
            model.copySelected()
        }
        Button(L10n.text(item.isPinned ? "clipboard.action.unpin" : "clipboard.action.pin")) {
            model.select(item)
            model.togglePinSelected()
        }
        Divider()
        Button(L10n.text("clipboard.action.delete"), role: .destructive) {
            model.select(item)
            model.deleteSelected()
        }
    }

    // MARK: Preview

    @ViewBuilder
    private var preview: some View {
        if let item = model.selectedItem {
            VStack(spacing: 0) {
                Group {
                    switch item.kind {
                    case .text:
                        ScrollView {
                            Text(item.text ?? "")
                                .font(InkletTheme.Typography.editor)
                                .lineSpacing(InkletTheme.Typography.editorLineSpacing)
                                .foregroundStyle(InkletTheme.label)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(InkletTheme.Spacing.md)
                        }
                    case .image:
                        Group {
                            if let image = model.image(for: item) {
                                Image(nsImage: image)
                                    .resizable()
                                    .interpolation(.high)
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: InkletTheme.Radius.control))
                                    .accessibilityLabel(imageTitle(item))
                            } else {
                                Image(systemName: "photo")
                                    .font(InkletTheme.Typography.pageTitle)
                                    .foregroundStyle(InkletTheme.tertiaryLabel)
                            }
                        }
                        .padding(InkletTheme.Spacing.md)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                InkletTheme.hairline.frame(height: 1)
                details(for: item)
            }
        }
    }

    private func details(for item: ClipboardHistoryItem) -> some View {
        Grid(alignment: .leading, horizontalSpacing: InkletTheme.Spacing.sm, verticalSpacing: InkletTheme.Spacing.xxs) {
            if let source = item.sourceApplicationName {
                detailRow(L10n.text("clipboard.detail.source"), value: source)
            }
            detailRow(L10n.text("clipboard.detail.copied"), value: absoluteTime(item.lastCopiedAt))
            detailRow(L10n.text("clipboard.detail.content"), value: contentSummary(item))
        }
        .padding(.horizontal, InkletTheme.Spacing.md)
        .padding(.vertical, InkletTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(_ title: String, value: String) -> some View {
        GridRow {
            Text(title)
                .font(InkletTheme.Typography.caption)
                .foregroundStyle(InkletTheme.tertiaryLabel)
            Text(value)
                .font(InkletTheme.Typography.caption)
                .foregroundStyle(InkletTheme.secondaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func contentSummary(_ item: ClipboardHistoryItem) -> String {
        switch item.kind {
        case .text:
            return L10n.format("clipboard.detail.characters", (item.text ?? "").count)
        case .image:
            guard let image = item.image else { return "" }
            let size = ByteCountFormatter.string(fromByteCount: Int64(image.byteCount), countStyle: .file)
            return L10n.format("clipboard.detail.imageSize", image.pixelWidth, image.pixelHeight, size)
        }
    }

    private func imageTitle(_ item: ClipboardHistoryItem) -> String {
        L10n.format("clipboard.imageTitle", item.image?.pixelWidth ?? 0, item.image?.pixelHeight ?? 0)
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func absoluteTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 14) {
            footerHint(keys: ["↑", "↓"], label: L10n.text("clipboard.hint.select"))
            footerHint(
                keys: ["↵"],
                label: L10n.text(model.canPaste ? "clipboard.action.paste" : "clipboard.action.copy")
            )
            footerHint(
                keys: ["⌘", "P"],
                label: L10n.text(model.selectedItem?.isPinned == true ? "clipboard.action.unpin" : "clipboard.action.pin")
            )
            footerHint(keys: ["⌘", "⌫"], label: L10n.text("clipboard.action.delete"))
            Spacer(minLength: InkletTheme.Spacing.xs)
            footerHint(keys: ["esc"], label: L10n.text("popover.hint.close"))
        }
        .padding(.horizontal, InkletTheme.Spacing.md)
        .frame(height: 36)
        .background(InkletTheme.surfaceSunken)
        .opacity(model.isEnabled ? 1 : 0.45)
    }

    private func footerHint(keys: [String], label: String) -> some View {
        HStack(spacing: 2) {
            ForEach(keys, id: \.self) { key in
                Keycap(title: key, compact: true)
            }
            Text(label)
                .font(InkletTheme.Typography.caption)
                .foregroundStyle(InkletTheme.secondaryLabel)
                .lineLimit(1)
                .padding(.leading, 2)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ClipboardHistoryRow: View {
    let item: ClipboardHistoryItem
    let image: NSImage?
    let isSelected: Bool
    let relativeTime: String
    let onSelect: () -> Void
    let onPaste: () -> Void
    @State private var isHovered = false

    private var title: String {
        switch item.kind {
        case .text:
            return item.previewLine
        case .image:
            return L10n.format("clipboard.imageTitle", item.image?.pixelWidth ?? 0, item.image?.pixelHeight ?? 0)
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: InkletTheme.Spacing.xs) {
                leadingTile
                Text(title)
                    .font(isSelected ? InkletTheme.Typography.control : InkletTheme.Typography.body)
                    .foregroundStyle(InkletTheme.label)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: InkletTheme.Spacing.xxs)
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: InkletTheme.IconSize.small, weight: .medium))
                        .foregroundStyle(InkletTheme.tertiaryLabel)
                        .accessibilityLabel(L10n.text("clipboard.section.pinned"))
                }
                Text(relativeTime)
                    .font(InkletTheme.Typography.caption)
                    .foregroundStyle(InkletTheme.tertiaryLabel)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, InkletTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: ClipboardHistoryView.rowHeight)
            .background {
                InkletRowBackground(isSelected: isSelected, isHovered: isHovered)
                    .padding(.horizontal, 6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded { onPaste() })
        .onHover { isHovered = $0 }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var leadingTile: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.medium)
                .scaledToFill()
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: InkletTheme.Radius.keycap))
                .overlay {
                    RoundedRectangle(cornerRadius: InkletTheme.Radius.keycap)
                        .stroke(InkletTheme.hairline)
                }
                .padding(.leading, 6)
        } else {
            Image(systemName: item.kind == .image ? "photo" : "text.alignleft")
                .font(.system(size: InkletTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(isSelected ? InkletTheme.accentText : InkletTheme.secondaryLabel)
                .frame(width: 24, height: 24)
                .background(InkletTheme.fill, in: RoundedRectangle(cornerRadius: InkletTheme.Radius.small))
                .padding(.leading, 6)
        }
    }
}

/// The panel's search field. Arrow keys, Return and Esc drive the list while typing.
struct ClipboardHistorySearchField: NSViewRepresentable {
    enum Command {
        case moveUp
        case moveDown
        case submit
        case cancel
    }

    @Binding var text: String
    let placeholder: String
    let focusRevision: Int
    let onCommand: (Command) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommand: onCommand)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(frame: .zero)
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.font = .systemFont(ofSize: InkletTheme.Typography.editorSize)
        field.focusRingType = .none
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.lineBreakMode = .byTruncatingTail
        field.cell?.usesSingleLineMode = true
        field.setAccessibilityLabel(placeholder)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onCommand = onCommand
        field.placeholderString = placeholder
        field.setAccessibilityLabel(placeholder)
        let editor = field.currentEditor() as? NSTextView
        if editor?.hasMarkedText() != true, field.stringValue != text {
            field.stringValue = text
        }
        if context.coordinator.focusedRevision != focusRevision {
            context.coordinator.focusedRevision = focusRevision
            DispatchQueue.main.async { [weak field] in
                guard let field, let window = field.window else { return }
                window.makeFirstResponder(field)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onCommand: (Command) -> Void
        var focusedRevision: Int?

        init(text: Binding<String>, onCommand: @escaping (Command) -> Void) {
            self.text = text
            self.onCommand = onCommand
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                onCommand(.moveUp)
            case #selector(NSResponder.moveDown(_:)):
                onCommand(.moveDown)
            case #selector(NSResponder.insertNewline(_:)):
                onCommand(.submit)
            case #selector(NSResponder.cancelOperation(_:)):
                onCommand(.cancel)
            default:
                return false
            }
            return true
        }
    }
}
