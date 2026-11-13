import CryptoKit
import Foundation

/// Something the person copied, as clipboard history reads it from the pasteboard.
public struct ClipboardCapture: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        case text(String)
        case image(pngData: Data, pixelWidth: Int, pixelHeight: Int)
    }

    public var content: Content
    public var sourceApplicationName: String?
    public var sourceBundleIdentifier: String?

    public init(
        content: Content,
        sourceApplicationName: String? = nil,
        sourceBundleIdentifier: String? = nil
    ) {
        self.content = content
        self.sourceApplicationName = sourceApplicationName
        self.sourceBundleIdentifier = sourceBundleIdentifier
    }

    /// Identical copies share a hash, so copying the same thing again moves it to the top.
    public var contentHash: String {
        let data: Data
        switch content {
        case .text(let text):
            data = Data(("text:" + text).utf8)
        case .image(let pngData, _, _):
            data = Data("image:".utf8) + pngData
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public struct ClipboardHistoryItem: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case text
        case image
    }

    public struct ImageInfo: Codable, Equatable, Sendable {
        public var fileName: String
        public var pixelWidth: Int
        public var pixelHeight: Int
        public var byteCount: Int
    }

    public let id: UUID
    public var kind: Kind
    public var text: String?
    public var image: ImageInfo?
    public var contentHash: String
    public var firstCopiedAt: Date
    public var lastCopiedAt: Date
    public var isPinned: Bool
    public var pinnedAt: Date?
    public var sourceApplicationName: String?
    public var sourceBundleIdentifier: String?

    public init(
        id: UUID = UUID(),
        kind: Kind,
        text: String? = nil,
        image: ImageInfo? = nil,
        contentHash: String,
        firstCopiedAt: Date,
        lastCopiedAt: Date,
        isPinned: Bool = false,
        pinnedAt: Date? = nil,
        sourceApplicationName: String? = nil,
        sourceBundleIdentifier: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.image = image
        self.contentHash = contentHash
        self.firstCopiedAt = firstCopiedAt
        self.lastCopiedAt = lastCopiedAt
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
        self.sourceApplicationName = sourceApplicationName
        self.sourceBundleIdentifier = sourceBundleIdentifier
    }

    /// The first non-empty line, for one-line list rows.
    public var previewLine: String {
        guard let text else {
            return ""
        }
        let line = text
            .split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return line ?? text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// How long unpinned clipboard history is kept. Pinned items stay until they are unpinned.
public enum ClipboardHistoryRetention: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month
    case threeMonths

    public static let defaultValue: ClipboardHistoryRetention = .month

    public var id: String { rawValue }

    public var days: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        }
    }

    public static func stored(_ rawValue: String?) -> ClipboardHistoryRetention {
        rawValue.flatMap(ClipboardHistoryRetention.init(rawValue:)) ?? defaultValue
    }
}

public enum ClipboardHistoryDefaults {
    public static let hotkey = "⌥⇧V"
    /// Recording is on unless the person turns it off in Settings.
    public static let isEnabled = true
}

/// Clipboard history kept on this Mac: a JSON list of items plus one PNG file per image.
@MainActor
public final class ClipboardHistoryStore {
    /// Unpinned items kept at most, newest first; older ones are dropped.
    public static let maximumUnpinnedItems = 500
    /// Unpinned images kept at most, since images take far more space than text.
    public static let maximumUnpinnedImages = 100
    /// Larger copies are not recorded.
    public static let maximumTextLength = 200_000
    public static let maximumImageBytes = 25 * 1024 * 1024

    public private(set) var items: [ClipboardHistoryItem] = []
    /// Runs after every change, on the main actor.
    public var onChange: (() -> Void)?

    private let fileURL: URL
    private let imagesDirectoryURL: URL
    private let fileManager: FileManager
    private let now: () -> Date

    public init(
        fileURL: URL,
        imagesDirectoryURL: URL,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileURL = fileURL
        self.imagesDirectoryURL = imagesDirectoryURL
        self.fileManager = fileManager
        self.now = now
    }

    /// Reads the saved history; a missing or unreadable file starts an empty one.
    public func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            items = []
            return
        }
        items = Self.sorted((try? JSONDecoder().decode([ClipboardHistoryItem].self, from: data)) ?? [])
    }

    public func imageURL(for item: ClipboardHistoryItem) -> URL? {
        guard let image = item.image else {
            return nil
        }
        return imagesDirectoryURL.appendingPathComponent(image.fileName)
    }

    /// Adds a copy, or moves an identical earlier copy to the top. Returns the recorded item.
    @discardableResult
    public func record(
        _ capture: ClipboardCapture,
        retention: ClipboardHistoryRetention
    ) -> ClipboardHistoryItem? {
        let date = now()
        let hash = capture.contentHash

        if let index = items.firstIndex(where: { $0.contentHash == hash }) {
            var item = items[index]
            item.lastCopiedAt = date
            item.sourceApplicationName = capture.sourceApplicationName ?? item.sourceApplicationName
            item.sourceBundleIdentifier = capture.sourceBundleIdentifier ?? item.sourceBundleIdentifier
            items[index] = item
            finishChange(retention: retention)
            return item
        }

        let item: ClipboardHistoryItem
        switch capture.content {
        case .text(let text):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  text.utf16.count <= Self.maximumTextLength
            else {
                return nil
            }
            item = ClipboardHistoryItem(
                kind: .text,
                text: text,
                contentHash: hash,
                firstCopiedAt: date,
                lastCopiedAt: date,
                sourceApplicationName: capture.sourceApplicationName,
                sourceBundleIdentifier: capture.sourceBundleIdentifier
            )
        case .image(let pngData, let pixelWidth, let pixelHeight):
            guard !pngData.isEmpty, pngData.count <= Self.maximumImageBytes else {
                return nil
            }
            let id = UUID()
            let fileName = "\(id.uuidString).png"
            do {
                try fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
                try pngData.write(to: imagesDirectoryURL.appendingPathComponent(fileName), options: .atomic)
            } catch {
                NSLog("Clipboard history could not save an image: \(error)")
                return nil
            }
            item = ClipboardHistoryItem(
                id: id,
                kind: .image,
                image: ClipboardHistoryItem.ImageInfo(
                    fileName: fileName,
                    pixelWidth: pixelWidth,
                    pixelHeight: pixelHeight,
                    byteCount: pngData.count
                ),
                contentHash: hash,
                firstCopiedAt: date,
                lastCopiedAt: date,
                sourceApplicationName: capture.sourceApplicationName,
                sourceBundleIdentifier: capture.sourceBundleIdentifier
            )
        }

        items.append(item)
        finishChange(retention: retention)
        return item
    }

    /// Moves an item back to the top after Inklet put it on the clipboard again, keeping where
    /// it was first copied from.
    public func touch(itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            return
        }
        items[index].lastCopiedAt = now()
        items = Self.sorted(items)
        save()
        onChange?()
    }

    public func setPinned(_ isPinned: Bool, itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              items[index].isPinned != isPinned
        else {
            return
        }
        items[index].isPinned = isPinned
        items[index].pinnedAt = isPinned ? now() : nil
        items = Self.sorted(items)
        save()
        onChange?()
    }

    public func delete(itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            return
        }
        let removed = items.remove(at: index)
        removeImageFile(of: removed)
        save()
        onChange?()
    }

    /// Removes every unpinned item. Pinned items stay.
    public func clearUnpinned() {
        let removed = items.filter { !$0.isPinned }
        guard !removed.isEmpty else {
            return
        }
        items.removeAll { !$0.isPinned }
        removed.forEach(removeImageFile)
        save()
        onChange?()
    }

    /// Drops unpinned items older than the retention period or beyond the item limits.
    public func prune(retention: ClipboardHistoryRetention) {
        let removedCount = applyLimits(retention: retention)
        guard removedCount > 0 else {
            return
        }
        save()
        onChange?()
    }

    /// Items whose text or source app matches every word of the query, in history order.
    public static func filter(_ items: [ClipboardHistoryItem], query: String) -> [ClipboardHistoryItem] {
        let words = query
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !words.isEmpty else {
            return items
        }
        return items.filter { item in
            let haystack = [item.text, item.sourceApplicationName]
                .compactMap { $0 }
                .joined(separator: "\n")
            return words.allSatisfy { word in
                haystack.range(of: word, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil
            }
        }
    }

    /// Pinned items first (most recently pinned on top), then the rest, most recently copied first.
    static func sorted(_ items: [ClipboardHistoryItem]) -> [ClipboardHistoryItem] {
        items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            if lhs.isPinned {
                return (lhs.pinnedAt ?? lhs.lastCopiedAt) > (rhs.pinnedAt ?? rhs.lastCopiedAt)
            }
            return lhs.lastCopiedAt > rhs.lastCopiedAt
        }
    }

    private func finishChange(retention: ClipboardHistoryRetention) {
        items = Self.sorted(items)
        applyLimits(retention: retention)
        save()
        onChange?()
    }

    @discardableResult
    private func applyLimits(retention: ClipboardHistoryRetention) -> Int {
        let cutoff = now().addingTimeInterval(-TimeInterval(retention.days) * 24 * 60 * 60)
        var keptUnpinned = 0
        var keptUnpinnedImages = 0
        var kept: [ClipboardHistoryItem] = []
        var removed: [ClipboardHistoryItem] = []

        for item in Self.sorted(items) {
            guard !item.isPinned else {
                kept.append(item)
                continue
            }
            let isImage = item.kind == .image
            if item.lastCopiedAt < cutoff
                || keptUnpinned >= Self.maximumUnpinnedItems
                || (isImage && keptUnpinnedImages >= Self.maximumUnpinnedImages) {
                removed.append(item)
                continue
            }
            keptUnpinned += 1
            if isImage {
                keptUnpinnedImages += 1
            }
            kept.append(item)
        }

        items = kept
        removed.forEach(removeImageFile)
        return removed.count
    }

    private func removeImageFile(of item: ClipboardHistoryItem) {
        guard let url = imageURL(for: item) else {
            return
        }
        try? fileManager.removeItem(at: url)
    }

    private func save() {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(items).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Clipboard history could not be saved: \(error)")
        }
    }
}
