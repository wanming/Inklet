import XCTest

final class SettingsViewSourceTests: XCTestCase {
    func testHistoryRowsExposeSingleCopyResultAction() throws {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourceURL = packageRoot.appendingPathComponent("Sources/InkletApp/SettingsView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let rowRange = try XCTUnwrap(source.range(of: "private func historyRow"))
        let textBlockRange = try XCTUnwrap(source.range(
            of: "\n    private func historyTextBlock",
            range: rowRange.upperBound..<source.endIndex
        ))
        let rowBlock = source[rowRange.lowerBound..<textBlockRange.lowerBound]
        let copyButtonCount = rowBlock.components(separatedBy: "historyCopyButton(").count - 1

        XCTAssertEqual(copyButtonCount, 1)
        XCTAssertTrue(rowBlock.contains("settings.history.copyResult"))
        XCTAssertFalse(rowBlock.contains("settings.history.copyOriginal"))
    }
}
