import AppKit
import XCTest
@testable import Inklet
@testable import InkletCore

@MainActor
final class WritingPopoverStreamingResultTests: XCTestCase {
    func testStreamedOutputIsVisibleWhileTransformingAndReplacedByFinalResult() async throws {
        let gate = StreamingGate()
        let harness = try makeHarness(provider: GatedStreamingProvider(gate: gate))
        let model = harness.model
        model.commitMode(modeID: model.selectedModeID)
        model.updateSourceText("hello")

        model.submit()
        try await waitUntil { model.streamingResultText == "Hel" }

        XCTAssertTrue(model.isTransforming)
        XCTAssertEqual(model.resultText, "")

        gate.open()
        try await waitUntil { !model.isTransforming }

        XCTAssertEqual(model.resultText, "Hello.")
        XCTAssertEqual(model.streamingResultText, "")
    }

    func testEscapeWhileStreamingStopsAndDiscardsPartialOutput() async throws {
        let gate = StreamingGate()
        let harness = try makeHarness(provider: GatedStreamingProvider(gate: gate))
        let model = harness.model
        model.commitMode(modeID: model.selectedModeID)
        model.updateSourceText("hello")

        model.submit()
        try await waitUntil { model.streamingResultText == "Hel" }
        model.escape()

        XCTAssertFalse(model.isTransforming)
        XCTAssertEqual(model.streamingResultText, "")
        XCTAssertEqual(model.resultText, "")
        XCTAssertEqual(model.route, .editor)
        XCTAssertEqual(model.sourceText, "hello")
        gate.open()
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        _ condition: () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Timed out waiting for condition")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func makeHarness(provider: some LLMProvider) throws -> StreamingHarness {
        let identifier = "WritingPopoverStreaming-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: identifier))
        defaults.removePersistentDomain(forName: identifier)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(identifier, isDirectory: true)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: identifier)
            try? FileManager.default.removeItem(at: root)
        }
        let configStore = UserDefaultsConfigStore(userDefaults: defaults)
        try configStore.save(AppConfig.defaultConfig())
        let model = InkletPopoverViewModel(
            configStore: configStore,
            transformationServiceFactory: { _ in TransformationService(provider: provider) },
            historyStore: JSONLHistoryStore(fileURL: root.appendingPathComponent("history.jsonl")),
            writingModePreferenceStore: WritingModePreferenceStore(userDefaults: defaults)
        )
        model.resetForOpen(previousApplication: nil)
        return StreamingHarness(model: model)
    }
}

private struct StreamingHarness {
    let model: InkletPopoverViewModel
}

private final class StreamingGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpenStorage: Bool

    init(isOpen: Bool = false) {
        isOpenStorage = isOpen
    }

    var isOpen: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isOpenStorage
    }

    func open() {
        lock.lock()
        isOpenStorage = true
        lock.unlock()
    }
}

private struct GatedStreamingProvider: LLMProvider {
    let gate: StreamingGate

    func transform(_ request: TransformationRequest) async throws -> TransformationResult {
        TransformationResult(outputText: "Hello.", providerMetadata: [:], elapsedMilliseconds: 1)
    }

    func streamTransform(
        _ request: TransformationRequest,
        onPartialOutput: @escaping @Sendable (String) -> Void
    ) async throws -> TransformationResult {
        onPartialOutput("Hel")
        while !gate.isOpen {
            try await Task.sleep(for: .milliseconds(5))
        }
        onPartialOutput("Hello.")
        return TransformationResult(outputText: "Hello.", providerMetadata: [:], elapsedMilliseconds: 1)
    }
}
