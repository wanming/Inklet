import XCTest
@testable import Inklet

final class DesignTokensTests: XCTestCase {
    private enum Appearance: CaseIterable {
        case light
        case dark
    }

    private func value(_ token: InkletColorToken, _ appearance: Appearance) -> InkletRGBA {
        appearance == .light ? token.light : token.dark
    }

    /// Every surface text can sit on, resolved to an opaque color.
    private func backgrounds(_ appearance: Appearance) -> [String: InkletRGBA] {
        let surface = value(InkletPalette.surface, appearance)
        return [
            "surface": surface,
            "surfaceRaised": value(InkletPalette.surfaceRaised, appearance),
            "surfaceSunken": value(InkletPalette.surfaceSunken, appearance).composited(over: surface),
        ]
    }

    func testTextTokensMeetWCAGAAOnEverySurface() {
        let textTokens: [String: InkletColorToken] = [
            "label": InkletPalette.label,
            "secondaryLabel": InkletPalette.secondaryLabel,
            "tertiaryLabel": InkletPalette.tertiaryLabel,
            "statusSuccess": InkletPalette.statusSuccess,
            "statusWarning": InkletPalette.statusWarning,
            "statusError": InkletPalette.statusError,
        ]

        for appearance in Appearance.allCases {
            for (backgroundName, background) in backgrounds(appearance) {
                for (textName, token) in textTokens {
                    let ratio = value(token, appearance).composited(over: background).contrastRatio(against: background)
                    XCTAssertGreaterThanOrEqual(
                        ratio,
                        4.5,
                        "\(textName) on \(backgroundName) (\(appearance)) is \(ratio):1"
                    )
                }
            }
        }
    }

    /// The macOS accent colors (System Settings > Appearance), light then dark, in sRGB.
    private let systemAccents: [(name: String, light: UInt32, dark: UInt32)] = [
        ("blue", 0x007AFF, 0x0A84FF),
        ("purple", 0x953D96, 0xA550A7),
        ("pink", 0xE0457B, 0xF74F9E),
        ("red", 0xE0383E, 0xFF5257),
        ("orange", 0xF7821B, 0xF7821B),
        ("yellow", 0xFFC600, 0xFFC600),
        ("green", 0x62BA46, 0x62BA46),
        ("graphite", 0x989898, 0x8C8C8C),
    ]

    func testAccentTextIsReadableOnEverySurfaceForEverySystemAccent() {
        for accent in systemAccents {
            for appearance in Appearance.allCases {
                let isDark = appearance == .dark
                let derived = InkletAccent.derive(
                    from: InkletRGBA(hex: isDark ? accent.dark : accent.light),
                    isDark: isDark
                )
                var surfaces = backgrounds(appearance)
                surfaces["accentSoft"] = derived.soft.composited(over: value(InkletPalette.surface, appearance))
                for (backgroundName, background) in surfaces {
                    let ratio = derived.text.contrastRatio(against: background)
                    XCTAssertGreaterThanOrEqual(
                        ratio,
                        4.5,
                        "\(accent.name) accentText on \(backgroundName) (\(appearance)) is \(ratio):1"
                    )
                }
            }
        }
    }

    func testTextOnTheAccentFillIsReadableForEverySystemAccent() {
        for accent in systemAccents {
            for appearance in Appearance.allCases {
                let isDark = appearance == .dark
                let derived = InkletAccent.derive(
                    from: InkletRGBA(hex: isDark ? accent.dark : accent.light),
                    isDark: isDark
                )
                let ratio = derived.onFill.contrastRatio(against: derived.fill)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "onAccent on \(accent.name) (\(appearance)) is \(ratio):1")
            }
        }
    }

    func testBlueAccentTakesWhiteTextOnTheFill() {
        let derived = InkletAccent.derive(from: InkletRGBA(hex: 0x007AFF), isDark: false)
        XCTAssertEqual(derived.onFill, InkletRGBA(hex: 0xFFFFFF))
        XCTAssertGreaterThanOrEqual(derived.text.contrastRatio(against: InkletPalette.surfaceRaised.light), 4.5)
    }

    func testYellowAccentKeepsItsColorAndTakesDarkText() {
        let accent = InkletRGBA(hex: 0xFFC600)
        let derived = InkletAccent.derive(from: accent, isDark: false)
        XCTAssertEqual(derived.fill, accent)
        XCTAssertEqual(derived.onFill, InkletRGBA(hex: 0x1D1D1F))
    }

    func testLabelsStayReadableOnTheSelectedRowFill() {
        for accent in systemAccents {
            for appearance in Appearance.allCases {
                let isDark = appearance == .dark
                let derived = InkletAccent.derive(
                    from: InkletRGBA(hex: isDark ? accent.dark : accent.light),
                    isDark: isDark
                )
                let selected = derived.soft.composited(over: value(InkletPalette.surface, appearance))
                let ratio = value(InkletPalette.label, appearance).contrastRatio(against: selected)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "label on \(accent.name) accentSoft (\(appearance)) is \(ratio):1")
            }
        }
    }

    func testSpacingFollowsTheFourPointGrid() {
        let spacing: [CGFloat] = [
            InkletTheme.Spacing.xxs,
            InkletTheme.Spacing.xs,
            InkletTheme.Spacing.sm,
            InkletTheme.Spacing.md,
            InkletTheme.Spacing.lg,
            InkletTheme.Spacing.xl,
            InkletTheme.Spacing.xxl,
        ]
        XCTAssertEqual(spacing, spacing.sorted())
        for value in spacing {
            XCTAssertEqual(value.truncatingRemainder(dividingBy: 4), 0, "\(value) is off the 4 pt grid")
        }
    }

    func testRadiiStepUpFromKeycapToPanel() {
        let radii: [CGFloat] = [
            InkletTheme.Radius.keycap,
            InkletTheme.Radius.small,
            InkletTheme.Radius.control,
            InkletTheme.Radius.card,
            InkletTheme.Radius.panel,
        ]
        XCTAssertEqual(radii, [4, 6, 8, 12, 16])
    }

    func testConcentricRadiusSubtractsTheInset() {
        XCTAssertEqual(InkletTheme.Radius.concentric(outer: 16, inset: 8), 8)
        XCTAssertEqual(InkletTheme.Radius.concentric(outer: 12, inset: 4), 8)
        XCTAssertEqual(InkletTheme.Radius.concentric(outer: 6, inset: 8), 0)
    }

    func testControlHeightsLeaveRoomForTheMinimumTextSize() {
        XCTAssertGreaterThanOrEqual(InkletTheme.ControlHeight.small, InkletTheme.Typography.minimumSize * 2)
        XCTAssertLessThan(InkletTheme.ControlHeight.small, InkletTheme.ControlHeight.regular)
        XCTAssertLessThan(InkletTheme.ControlHeight.regular, InkletTheme.ControlHeight.large)
        XCTAssertLessThan(InkletTheme.ControlHeight.large, InkletTheme.ControlHeight.bar)
    }
}
