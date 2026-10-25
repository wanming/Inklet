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
            "accentText": InkletPalette.accentText,
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

    func testOnAccentTextIsReadableOnTheAccentFill() {
        for appearance in Appearance.allCases {
            let accent = value(InkletPalette.accent, appearance)
            let ratio = value(InkletPalette.onAccent, appearance).contrastRatio(against: accent)
            XCTAssertGreaterThanOrEqual(ratio, 4.5, "onAccent on accent (\(appearance)) is \(ratio):1")
        }
    }

    func testLabelsStayReadableOnTheSelectedRowFill() {
        for appearance in Appearance.allCases {
            let surface = value(InkletPalette.surface, appearance)
            let selected = value(InkletPalette.accentSoft, appearance).composited(over: surface)
            for token in [InkletPalette.label, InkletPalette.accentText] {
                let ratio = value(token, appearance).contrastRatio(against: selected)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "text on accentSoft (\(appearance)) is \(ratio):1")
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
