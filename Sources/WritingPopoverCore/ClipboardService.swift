import AppKit
import Foundation

public struct PasteboardSnapshot {
    public let items: [[NSPasteboard.PasteboardType: Data]]

    public init(items: [[NSPasteboard.PasteboardType: Data]]) {
        self.items = items
    }
}

@MainActor
public final class ClipboardService {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public func save() -> PasteboardSnapshot {
        let items = pasteboard.pasteboardItems?.map { item in
            item.types.reduce(into: [NSPasteboard.PasteboardType: Data]()) { values, type in
                values[type] = item.data(forType: type)
            }
        } ?? []

        return PasteboardSnapshot(items: items)
    }

    public func writePlainText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    @discardableResult
    public func restore(_ snapshot: PasteboardSnapshot) -> Bool {
        var items: [NSPasteboardItem] = []

        for savedItem in snapshot.items {
            let pasteboardItem = NSPasteboardItem()
            for (type, data) in savedItem {
                guard pasteboardItem.setData(data, forType: type) else {
                    return false
                }
            }
            items.append(pasteboardItem)
        }

        pasteboard.clearContents()
        guard !items.isEmpty else {
            return true
        }

        return pasteboard.writeObjects(items)
    }
}
