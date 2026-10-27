import AppKit
import SwiftUI
import XCTest
@testable import Inklet
import InkletCore

/// Temporary: records the selection bar at 2x so the grip can be reviewed. Removed before merge.
@MainActor
final class TempGripSnapshotTests: XCTestCase {
    func testTempGripSnapshots() throws {
        guard let directory = ProcessInfo.processInfo.environment["INKLET_LOCALIZATION_SNAPSHOT_DIR"] else {
            return
        }
        let modes = (0..<3).map {
            SelectionMenuItem(action: .promptMode("mode-\($0)"), promptModeName: ["Polish", "Make shorter", "Very long prompt mode name here"][$0])
        }
        let key = InkletPreferenceKeys.interfaceLanguage
        let previous = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        for language in [InterfaceLanguage.english, .german, .simplifiedChinese] {
            UserDefaults.standard.set(language.rawValue, forKey: key)
            for (name, items) in [("default", SelectionMenuItem.defaults), ("four-more", SelectionMenuItem.defaults + modes)] {
                let view = SelectionActionView(
                    state: .menu(errorMessage: nil, feedback: nil),
                    menuItems: items,
                    onTranslate: {}, onPronounce: {}, onPronounceOriginal: {},
                    onPronounceTranslation: {}, onCopyTranslation: {}, onRetryTranslation: {}
                )
                .padding(12)
                .background(Color(nsColor: .windowBackgroundColor))
                try record2x(view, name: "grip-\(name)-\(language.localeIdentifier)", directory: directory)
            }
        }
    }

    private func record2x(_ view: some View, name: String, directory: String) throws {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let isDark = ProcessInfo.processInfo.environment["INKLET_SNAPSHOT_APPEARANCE"] == "dark"
        window.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(host.bounds.width * 2), pixelsHigh: Int(host.bounds.height * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        bitmap.size = host.bounds.size
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: folder.appendingPathComponent(name).appendingPathExtension("png"))
    }
}
