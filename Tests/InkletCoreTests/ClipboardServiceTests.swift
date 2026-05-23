import AppKit
import XCTest
@testable import InkletCore

final class ClipboardServiceTests: XCTestCase {
    @MainActor
    func testWritesAndRestoresPlainText() {
        let pasteboard = NSPasteboard.withUniqueName()
        let service = ClipboardService(pasteboard: pasteboard)
        let original = "Original clipboard text"
        let generated = "Generated replacement text"

        pasteboard.clearContents()
        pasteboard.setString(original, forType: .string)

        let snapshot = service.save()
        service.writePlainText(generated)

        XCTAssertEqual(pasteboard.string(forType: .string), generated)

        XCTAssertTrue(service.restore(snapshot))

        XCTAssertEqual(pasteboard.string(forType: .string), original)
    }

    @MainActor
    func testRestoresMultipleItemsAndTypes() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        let service = ClipboardService(pasteboard: pasteboard)
        let customType = NSPasteboard.PasteboardType("com.inklet.test.binary")
        let customData = Data([0x01, 0x02, 0x03])
        let firstItem = NSPasteboardItem()
        let secondItem = NSPasteboardItem()

        XCTAssertTrue(firstItem.setString("First", forType: .string))
        XCTAssertTrue(firstItem.setData(customData, forType: customType))
        XCTAssertTrue(secondItem.setString("Second", forType: .string))
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([firstItem, secondItem]))

        let snapshot = service.save()
        service.writePlainText("Generated replacement text")

        XCTAssertTrue(service.restore(snapshot))

        let restoredItems = try XCTUnwrap(pasteboard.pasteboardItems)
        XCTAssertEqual(restoredItems.count, 2)
        XCTAssertEqual(restoredItems[0].string(forType: .string), "First")
        XCTAssertEqual(restoredItems[0].data(forType: customType), customData)
        XCTAssertEqual(restoredItems[1].string(forType: .string), "Second")
    }

    @MainActor
    func testInsertionRestoresClipboardWhenPasteEventCreationFails() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        let clipboardService = ClipboardService(pasteboard: pasteboard)
        let original = "Original clipboard text"
        let generated = "Generated replacement text"
        var activationCallCount = 0
        var requestedDelays: [UInt64] = []
        let service = InsertionService(
            clipboardService: clipboardService,
            eventSource: nil,
            restoreDelayNanoseconds: 1,
            activationDelayNanoseconds: 1,
            accessibilityTrustProvider: { true },
            applicationActivator: { _ in
                activationCallCount += 1
                return true
            },
            applicationActivityProvider: { _ in true },
            pasteShortcutSender: { _ in
                throw InsertionError.cannotCreatePasteEvent
            },
            delayProvider: { nanoseconds in
                requestedDelays.append(nanoseconds)
            }
        )

        pasteboard.clearContents()
        pasteboard.setString(original, forType: .string)

        do {
            try await service.insert(text: generated, into: .current)
            XCTFail("Expected cannotCreatePasteEvent")
        } catch let error as InsertionError {
            XCTAssertEqual(error, .cannotCreatePasteEvent)
        }

        XCTAssertEqual(activationCallCount, 1)
        XCTAssertTrue(requestedDelays.isEmpty)
        XCTAssertEqual(pasteboard.string(forType: .string), original)
    }

    @MainActor
    func testInsertionRestoresClipboardAndSkipsPasteWhenActivationFails() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        let clipboardService = ClipboardService(pasteboard: pasteboard)
        let original = "Original clipboard text"
        var pasteShortcutCallCount = 0
        var requestedDelays: [UInt64] = []
        let service = InsertionService(
            clipboardService: clipboardService,
            restoreDelayNanoseconds: 1,
            activationDelayNanoseconds: 1,
            accessibilityTrustProvider: { true },
            applicationActivator: { _ in false },
            applicationActivityProvider: { _ in false },
            pasteShortcutSender: { _ in
                pasteShortcutCallCount += 1
            },
            delayProvider: { nanoseconds in
                requestedDelays.append(nanoseconds)
            }
        )

        pasteboard.clearContents()
        pasteboard.setString(original, forType: .string)

        do {
            try await service.insert(text: "Generated replacement text", into: .current)
            XCTFail("Expected activationFailed")
        } catch let error as InsertionError {
            XCTAssertEqual(error, .activationFailed)
        }

        XCTAssertEqual(pasteShortcutCallCount, 0)
        XCTAssertTrue(requestedDelays.isEmpty)
        XCTAssertEqual(pasteboard.string(forType: .string), original)
    }

    @MainActor
    func testInsertionRestoresClipboardAndSkipsPasteWhenTargetNeverBecomesActive() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        let clipboardService = ClipboardService(pasteboard: pasteboard)
        let original = "Original clipboard text"
        var pasteShortcutCallCount = 0
        var requestedDelays: [UInt64] = []
        let service = InsertionService(
            clipboardService: clipboardService,
            restoreDelayNanoseconds: 1,
            activationDelayNanoseconds: 1,
            activationTimeoutNanoseconds: 3,
            accessibilityTrustProvider: { true },
            applicationActivator: { _ in true },
            applicationActivityProvider: { _ in false },
            pasteShortcutSender: { _ in
                pasteShortcutCallCount += 1
            },
            delayProvider: { nanoseconds in
                requestedDelays.append(nanoseconds)
            }
        )

        pasteboard.clearContents()
        pasteboard.setString(original, forType: .string)

        do {
            try await service.insert(text: "Generated replacement text", into: .current)
            XCTFail("Expected activationFailed")
        } catch let error as InsertionError {
            XCTAssertEqual(error, .activationFailed)
        }

        XCTAssertEqual(pasteShortcutCallCount, 0)
        XCTAssertEqual(requestedDelays.reduce(0, +), 3)
        XCTAssertTrue(requestedDelays.allSatisfy { $0 > 0 })
        XCTAssertEqual(pasteboard.string(forType: .string), original)
    }
}
