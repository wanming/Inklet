import XCTest

final class VoiceShortcutMonitorSourceTests: XCTestCase {
    func testVoiceShortcutMonitorUsesConfiguredRecordingMode() throws {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let monitorURL = packageRoot.appendingPathComponent("Sources/InkletApp/VoiceShortcutMonitor.swift")
        let coordinatorURL = packageRoot.appendingPathComponent("Sources/InkletApp/AppCoordinator.swift")
        let settingsURL = packageRoot.appendingPathComponent("Sources/InkletApp/SettingsView.swift")

        let monitorSource = try String(contentsOf: monitorURL, encoding: .utf8)
        let coordinatorSource = try String(contentsOf: coordinatorURL, encoding: .utf8)
        let settingsSource = try String(contentsOf: settingsURL, encoding: .utf8)

        XCTAssertTrue(monitorSource.contains("recordingMode: VoiceInputConfig.RecordingMode"))
        XCTAssertTrue(monitorSource.contains("VoiceShortcutModifierPressTracker"))
        XCTAssertTrue(monitorSource.contains("modifierPressTracker.transition"))
        XCTAssertTrue(monitorSource.contains("VoiceShortcutGestureRecognizer"))
        XCTAssertTrue(monitorSource.contains("holdDelayElapsed"))
        XCTAssertTrue(monitorSource.contains("pressBegan"))
        XCTAssertTrue(monitorSource.contains("pressEnded"))
        XCTAssertTrue(monitorSource.contains("onToggle"))
        XCTAssertTrue(monitorSource.contains("onStart"))
        XCTAssertTrue(monitorSource.contains("onStop"))

        XCTAssertTrue(coordinatorSource.contains("recordingMode: config.voiceInput.recordingMode"))
        XCTAssertTrue(coordinatorSource.contains("await self?.voiceCoordinator.toggle()"))
        XCTAssertTrue(coordinatorSource.contains("await self?.voiceCoordinator.start()"))
        XCTAssertTrue(coordinatorSource.contains("await self?.voiceCoordinator.stop()"))

        XCTAssertTrue(settingsSource.contains("settings.row.voiceRecordingMode"))
        XCTAssertTrue(settingsSource.contains("VoiceInputConfig.RecordingMode.allCases"))
    }
}
