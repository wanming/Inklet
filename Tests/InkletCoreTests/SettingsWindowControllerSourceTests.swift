import XCTest

final class SettingsWindowControllerSourceTests: XCTestCase {
    func testMigrationWorkflowIdlePropagatesFromRetainedSettingsModel() throws {
        let source = try controllerSource()

        XCTAssertTrue(source.contains("var onMigrationWorkflowIdleChange: ((Bool) -> Void)?"))
        XCTAssertTrue(source.contains("var isMigrationWorkflowIdle: Bool"))
        XCTAssertTrue(source.contains("model.isMigrationWorkflowIdle"))
        XCTAssertTrue(source.contains("model.$isMigrationWorkflowIdle"))
        XCTAssertTrue(source.contains("removeDuplicates()"))
        XCTAssertTrue(source.contains("onMigrationWorkflowIdleChange?(isIdle)"))
    }

    func testSettingsUsesNativeTitledWindow() throws {
        let source = try controllerSource()

        XCTAssertTrue(source.contains("styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView]"))
        XCTAssertTrue(source.contains("window.titlebarAppearsTransparent = true"))
        XCTAssertTrue(source.contains("window.titleVisibility = .hidden"))
        XCTAssertTrue(source.contains("window.isMovableByWindowBackground = false"))
        XCTAssertTrue(source.contains("override func cancelOperation(_ sender: Any?)"))
        XCTAssertFalse(source.contains("styleMask: [.borderless]"))
        XCTAssertFalse(source.contains("setFrameOrigin(newOrigin)"))
    }

    private func controllerSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourceURL = packageRoot.appendingPathComponent("Sources/InkletApp/SettingsWindowController.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
