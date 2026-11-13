import AppKit
import XCTest
@testable import InkletCore

@MainActor
final class ClipboardHistoryStoreTests: XCTestCase {
    private var directory: URL!
    private var now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardHistoryTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStore() -> ClipboardHistoryStore {
        ClipboardHistoryStore(
            fileURL: directory.appendingPathComponent("clipboard-history.json"),
            imagesDirectoryURL: directory.appendingPathComponent("clipboard-images", isDirectory: true),
            now: { [unowned self] in self.now }
        )
    }

    private func text(_ value: String, app: String? = nil) -> ClipboardCapture {
        ClipboardCapture(content: .text(value), sourceApplicationName: app)
    }

    func testRecordsNewestFirstAndMovesARepeatedCopyToTheTop() {
        let store = makeStore()
        store.record(text("first"), retention: .month)
        now += 1
        store.record(text("second"), retention: .month)
        now += 1
        store.record(text("first", app: "Notes"), retention: .month)

        XCTAssertEqual(store.items.map(\.text), ["first", "second"])
        XCTAssertEqual(store.items.first?.sourceApplicationName, "Notes")
        XCTAssertEqual(store.items.first?.lastCopiedAt, now)
    }

    func testSkipsBlankAndOversizedText() {
        let store = makeStore()
        XCTAssertNil(store.record(text("  \n "), retention: .month))
        XCTAssertNil(store.record(
            text(String(repeating: "a", count: ClipboardHistoryStore.maximumTextLength + 1)),
            retention: .month
        ))
        XCTAssertTrue(store.items.isEmpty)
    }

    func testPinnedItemsStayOnTopAndSurviveClearingAndRetention() {
        let store = makeStore()
        store.record(text("keep me"), retention: .month)
        now += 1
        store.record(text("newer"), retention: .month)
        let pinned = store.items.first { $0.text == "keep me" }!
        store.setPinned(true, itemID: pinned.id)

        XCTAssertEqual(store.items.map(\.text), ["keep me", "newer"])

        now += TimeInterval(2 * 24 * 60 * 60)
        store.prune(retention: .day)
        XCTAssertEqual(store.items.map(\.text), ["keep me"])

        store.record(text("another"), retention: .month)
        store.clearUnpinned()
        XCTAssertEqual(store.items.map(\.text), ["keep me"])
    }

    func testKeepsAtMostTheUnpinnedLimit() {
        let store = makeStore()
        for index in 0...ClipboardHistoryStore.maximumUnpinnedItems {
            now += 1
            store.record(text("item \(index)"), retention: .threeMonths)
        }
        XCTAssertEqual(store.items.count, ClipboardHistoryStore.maximumUnpinnedItems)
        XCTAssertEqual(store.items.first?.text, "item \(ClipboardHistoryStore.maximumUnpinnedItems)")
        XCTAssertFalse(store.items.contains { $0.text == "item 0" })
    }

    func testSavesAndReloadsHistoryWithImages() throws {
        let store = makeStore()
        let png = try XCTUnwrap(Self.pngData(width: 3, height: 2))
        store.record(ClipboardCapture(content: .image(pngData: png, pixelWidth: 3, pixelHeight: 2)), retention: .month)
        now += 1
        store.record(text("hello"), retention: .month)

        let reloaded = makeStore()
        reloaded.load()
        XCTAssertEqual(reloaded.items.map(\.kind), [.text, .image])
        let image = try XCTUnwrap(reloaded.items.last)
        XCTAssertEqual(image.image?.pixelWidth, 3)
        let imageURL = try XCTUnwrap(reloaded.imageURL(for: image))
        XCTAssertEqual(try Data(contentsOf: imageURL), png)

        reloaded.delete(itemID: image.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: imageURL.path))
    }

    func testFilterMatchesEveryWordInTextOrSourceApp() {
        let store = makeStore()
        store.record(text("Meeting notes for Friday", app: "Notes"), retention: .month)
        now += 1
        store.record(text("café menu", app: "Safari"), retention: .month)

        XCTAssertEqual(ClipboardHistoryStore.filter(store.items, query: "").count, 2)
        XCTAssertEqual(ClipboardHistoryStore.filter(store.items, query: "friday MEETING").map(\.text), ["Meeting notes for Friday"])
        XCTAssertEqual(ClipboardHistoryStore.filter(store.items, query: "cafe").map(\.text), ["café menu"])
        XCTAssertEqual(ClipboardHistoryStore.filter(store.items, query: "safari").map(\.text), ["café menu"])
        XCTAssertTrue(ClipboardHistoryStore.filter(store.items, query: "nothing").isEmpty)
    }

    func testPreviewLineIsTheFirstNonEmptyLine() {
        let item = ClipboardHistoryItem(
            kind: .text,
            text: "\n\n  Hello world  \nsecond",
            contentHash: "x",
            firstCopiedAt: now,
            lastCopiedAt: now
        )
        XCTAssertEqual(item.previewLine, "Hello world")
    }

    func testRetentionFallsBackToTheDefault() {
        XCTAssertEqual(ClipboardHistoryRetention.stored(nil), .month)
        XCTAssertEqual(ClipboardHistoryRetention.stored("unknown"), .month)
        XCTAssertEqual(ClipboardHistoryRetention.stored("week"), .week)
    }

    func testDefaultShortcutParses() throws {
        let hotkey = try Hotkey.parse(ClipboardHistoryDefaults.hotkey)
        XCTAssertEqual(hotkey.modifiers, [.option, .shift])
        XCTAssertEqual(hotkey.displayString, "⌥⇧V")
    }

    static func pngData(width: Int, height: Int) -> Data? {
        let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        return representation?.representation(using: .png, properties: [:])
    }
}

@MainActor
final class ClipboardPasteboardTests: XCTestCase {
    private var pasteboard: NSPasteboard!

    override func setUp() {
        pasteboard = NSPasteboard(name: NSPasteboard.Name("InkletClipboardTests-\(UUID().uuidString)"))
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
    }

    func testCapturesTextAndSkipsPrivateOrTemporaryCopies() {
        pasteboard.clearContents()
        pasteboard.setString("hello", forType: .string)
        XCTAssertEqual(ClipboardPasteboard.capture(from: pasteboard, sourceApplication: nil)?.content, .text("hello"))

        for marker in ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"] {
            pasteboard.clearContents()
            pasteboard.setString("secret", forType: .string)
            pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType(marker))
            XCTAssertNil(ClipboardPasteboard.capture(from: pasteboard, sourceApplication: nil), marker)
        }
    }

    func testCapturesImagesAndWritesThemBack() throws {
        let png = try XCTUnwrap(ClipboardHistoryStoreTests.pngData(width: 4, height: 5))
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)

        let capture = try XCTUnwrap(ClipboardPasteboard.capture(from: pasteboard, sourceApplication: nil))
        XCTAssertEqual(capture.content, .image(pngData: png, pixelWidth: 4, pixelHeight: 5))

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardPasteboardTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ClipboardHistoryStore(
            fileURL: directory.appendingPathComponent("history.json"),
            imagesDirectoryURL: directory
        )
        let item = try XCTUnwrap(store.record(capture, retention: .month))

        pasteboard.clearContents()
        XCTAssertTrue(ClipboardPasteboard.write(item, imageURL: store.imageURL(for: item), to: pasteboard))
        XCTAssertEqual(pasteboard.data(forType: .png), png)
        XCTAssertNotNil(pasteboard.data(forType: .tiff))
        // Pasting from history and copying again keeps a single entry.
        let again = try XCTUnwrap(ClipboardPasteboard.capture(from: pasteboard, sourceApplication: nil))
        XCTAssertEqual(again.contentHash, capture.contentHash)
    }

    func testSkipsCopiedFiles() {
        pasteboard.clearContents()
        pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/example.txt") as NSURL])
        XCTAssertNil(ClipboardPasteboard.capture(from: pasteboard, sourceApplication: nil))
    }
}

@MainActor
final class PasteboardOwnershipTests: XCTestCase {
    func testClaimsDeferAndIgnoreInkletsOwnChanges() {
        let ownership = PasteboardOwnership()
        var pendingCopyChecks = 0
        ownership.willClaim = { pendingCopyChecks += 1 }

        let claim = ownership.claim()
        XCTAssertEqual(pendingCopyChecks, 1)
        XCTAssertTrue(ownership.isClaimed)

        ownership.release(claim, ignoringThrough: 12)
        XCTAssertFalse(ownership.isClaimed)
        XCTAssertTrue(ownership.isIgnored(changeCount: 12))
        XCTAssertFalse(ownership.isIgnored(changeCount: 13))

        // A copy the person made during the claim is kept.
        let userCopyClaim = ownership.claim()
        ownership.release(userCopyClaim, ignoringThrough: nil)
        XCTAssertFalse(ownership.isIgnored(changeCount: 14))
    }

    func testOnlyTheGeneralPasteboardIsClaimed() {
        let ownership = PasteboardOwnership()
        let privatePasteboard = NSPasteboard(name: NSPasteboard.Name("InkletOwnershipTests-\(UUID().uuidString)"))
        defer { privatePasteboard.releaseGlobally() }
        XCTAssertNil(ownership.claim(privatePasteboard))
        XCTAssertFalse(ownership.isClaimed)
    }
}
