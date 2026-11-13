import XCTest
@testable import InkletCore

@MainActor
final class SnippetStoreTests: XCTestCase {
    private var directory: URL!
    private var now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnippetsTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStore() -> SnippetStore {
        SnippetStore(
            fileURL: directory.appendingPathComponent("snippets.json"),
            now: { [unowned self] in self.now }
        )
    }

    func testAddsUpdatesDeletesAndReloadsSortedByName() {
        let store = makeStore()
        var changes = 0
        store.onChange = { changes += 1 }

        let zebra = store.add(name: "Zebra", text: "z")
        now += 1
        let apple = store.add(name: "apple", text: "a", keyword: ";a")
        now += 1
        store.add(text: "\n  Untitled first line\nsecond")
        XCTAssertEqual(store.snippets.map(\.displayName), ["apple", "Untitled first line", "Zebra"])
        XCTAssertEqual(changes, 3)

        var renamed = zebra
        renamed.name = "Banana"
        now += 1
        store.update(renamed)
        XCTAssertEqual(store.snippets.map(\.displayName), ["apple", "Banana", "Untitled first line"])
        XCTAssertEqual(store.snippet(id: zebra.id)?.updatedAt, now)
        XCTAssertEqual(store.snippet(id: zebra.id)?.createdAt, zebra.createdAt)

        // An unchanged snippet isn't saved again.
        store.update(store.snippet(id: zebra.id)!)
        XCTAssertEqual(changes, 4)

        store.delete(id: apple.id)
        store.delete(id: UUID())
        XCTAssertEqual(changes, 5)

        let reloaded = makeStore()
        reloaded.load()
        XCTAssertEqual(reloaded.snippets, store.snippets)
    }

    func testMissingOrBrokenFileStartsEmpty() throws {
        let store = makeStore()
        store.load()
        XCTAssertTrue(store.snippets.isEmpty)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("snippets.json"))
        store.load()
        XCTAssertTrue(store.snippets.isEmpty)
    }

    func testKeywordIssues() {
        let store = makeStore()
        let address = store.add(name: "Address", text: "1 Main St", keyword: ";addr")
        let other = store.add(name: "Other", text: "x")

        XCTAssertNil(store.keywordIssue("", for: other.id))
        XCTAssertEqual(store.keywordIssue("a b", for: other.id), .containsWhitespace)
        XCTAssertEqual(store.keywordIssue("x", for: other.id), .tooShort)
        XCTAssertEqual(store.keywordIssue(";addr", for: other.id), .duplicate(name: "Address"))
        XCTAssertNil(store.keywordIssue(";addr", for: address.id))
        XCTAssertNil(store.keywordIssue(";ad", for: other.id))
    }

    func testTypedTextMatchesTheLongestValidKeyword() {
        let store = makeStore()
        store.add(name: "Short", text: "short", keyword: "sig")
        store.add(name: "Long", text: "long", keyword: ";sig")
        store.add(name: "Too short", text: "never", keyword: "g")
        store.add(name: "No keyword", text: "never")

        XCTAssertEqual(store.snippet(endingTypedText: "hello ;sig")?.name, "Long")
        XCTAssertEqual(store.snippet(endingTypedText: "hello sig")?.name, "Short")
        XCTAssertNil(store.snippet(endingTypedText: "hello si"))
        XCTAssertNil(store.snippet(endingTypedText: "dog"))
        XCTAssertNil(store.snippet(endingTypedText: ""))
    }

    func testFilterMatchesEveryWordInNameKeywordOrText() {
        let store = makeStore()
        store.add(name: "Home address", text: "1 Main St", keyword: ";addr")
        store.add(name: "Thanks", text: "Merci beaucoup, à bientôt")

        XCTAssertEqual(SnippetStore.filter(store.snippets, query: "  ").count, 2)
        XCTAssertEqual(SnippetStore.filter(store.snippets, query: "HOME main").map(\.name), ["Home address"])
        XCTAssertEqual(SnippetStore.filter(store.snippets, query: ";addr").map(\.name), ["Home address"])
        XCTAssertEqual(SnippetStore.filter(store.snippets, query: "a bientot").map(\.name), ["Thanks"])
        XCTAssertTrue(SnippetStore.filter(store.snippets, query: "nothing").isEmpty)
    }

    func testKeywordExpansionIsOffByDefault() {
        XCTAssertFalse(SnippetDefaults.expandsKeywords)
    }
}

final class SnippetTypingBufferTests: XCTestCase {
    func testTypesDeletesAndResets() {
        var buffer = SnippetTypingBuffer()
        buffer.handle(.characters(";ad"))
        buffer.handle(.characters("x"))
        buffer.handle(.deleteBackward)
        buffer.handle(.characters("dr"))
        XCTAssertEqual(buffer.text, ";addr")

        buffer.handle(.reset)
        XCTAssertEqual(buffer.text, "")
        buffer.handle(.deleteBackward)
        XCTAssertEqual(buffer.text, "")
    }

    func testControlCharactersAndEmptyInputClearIt() {
        var buffer = SnippetTypingBuffer()
        buffer.handle(.characters("abc"))
        buffer.handle(.characters("\u{1B}"))
        XCTAssertEqual(buffer.text, "")

        buffer.handle(.characters("abc"))
        buffer.handle(.characters(""))
        XCTAssertEqual(buffer.text, "")
    }

    func testKeepsOnlyTheLatestCharacters() {
        var buffer = SnippetTypingBuffer()
        for _ in 0..<SnippetTypingBuffer.capacity {
            buffer.handle(.characters("a"))
        }
        buffer.handle(.characters("bc"))
        XCTAssertEqual(buffer.text.count, SnippetTypingBuffer.capacity)
        XCTAssertTrue(buffer.text.hasSuffix("abc"))
        XCTAssertGreaterThanOrEqual(SnippetTypingBuffer.capacity, SnippetDefaults.maximumKeywordLength)
    }
}
