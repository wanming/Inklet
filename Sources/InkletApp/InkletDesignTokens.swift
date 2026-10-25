import AppKit
import SwiftUI

// Design tokens for the "Ink & Paper" design language. docs/DESIGN.md is the
// source of truth for when to use each token; keep the two in sync.

struct InkletRGBA: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(hex: UInt32, alpha: Double = 1) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
        self.alpha = alpha
    }

    static func black(_ alpha: Double) -> InkletRGBA {
        InkletRGBA(hex: 0x000000, alpha: alpha)
    }

    static func white(_ alpha: Double) -> InkletRGBA {
        InkletRGBA(hex: 0xFFFFFF, alpha: alpha)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    /// This color painted over an opaque background.
    func composited(over background: InkletRGBA) -> InkletRGBA {
        InkletRGBA(
            red: red * alpha + background.red * (1 - alpha),
            green: green * alpha + background.green * (1 - alpha),
            blue: blue * alpha + background.blue * (1 - alpha),
            alpha: 1
        )
    }

    /// A blend of this color and `other`; `amount` 0 is this color, 1 is `other`.
    func mixed(with other: InkletRGBA, amount: Double) -> InkletRGBA {
        InkletRGBA(
            red: red + (other.red - red) * amount,
            green: green + (other.green - green) * amount,
            blue: blue + (other.blue - blue) * amount,
            alpha: alpha + (other.alpha - alpha) * amount
        )
    }

    /// The same color with a different alpha.
    func withAlpha(_ alpha: Double) -> InkletRGBA {
        InkletRGBA(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// WCAG 2 relative luminance of the opaque color.
    var relativeLuminance: Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// WCAG 2 contrast ratio between two opaque colors.
    func contrastRatio(against other: InkletRGBA) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Reads an AppKit color as sRGB, resolving dynamic system colors for `appearance`.
    init(_ color: NSColor, appearance: NSAppearance) {
        var resolved = NSColor.black
        appearance.performAsCurrentDrawingAppearance {
            resolved = color.usingColorSpace(.sRGB) ?? .black
        }
        self.init(
            red: Double(resolved.redComponent),
            green: Double(resolved.greenComponent),
            blue: Double(resolved.blueComponent),
            alpha: Double(resolved.alphaComponent)
        )
    }

    private init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// A color with one value for light (Aqua) and one for dark (Dark Aqua) appearances.
struct InkletColorToken: Equatable, Sendable {
    let light: InkletRGBA
    let dark: InkletRGBA

    var nsColor: NSColor {
        let light = light
        let dark = dark
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark.nsColor : light.nsColor
        }
    }

    var color: Color {
        Color(nsColor: nsColor)
    }
}

/// Raw color values. Views use the semantic accessors on `InkletTheme`;
/// tests use these to check contrast.
enum InkletPalette {
    // The accent follows the macOS accent color (System Settings > Appearance),
    // so its colors are derived per appearance in `InkletAccent`.

    // Surfaces.
    static let surface = InkletColorToken(light: InkletRGBA(hex: 0xF6F6F7), dark: InkletRGBA(hex: 0x1E1E21))
    static let surfaceRaised = InkletColorToken(light: InkletRGBA(hex: 0xFFFFFF), dark: InkletRGBA(hex: 0x2A2A2E))
    static let surfaceSunken = InkletColorToken(light: .black(0.03), dark: .black(0.15))

    // Control fills, painted over a surface.
    static let fill = InkletColorToken(light: .black(0.05), dark: .white(0.07))
    static let fillHover = InkletColorToken(light: .black(0.07), dark: .white(0.10))
    static let fillPressed = InkletColorToken(light: .black(0.11), dark: .white(0.14))

    // Strokes.
    static let hairline = InkletColorToken(light: .black(0.08), dark: .white(0.08))
    static let strokeStrong = InkletColorToken(light: .black(0.14), dark: .white(0.14))
    static let topHighlight = InkletColorToken(light: .white(0.70), dark: .white(0.06))

    // Text.
    static let label = InkletColorToken(light: InkletRGBA(hex: 0x1D1D1F), dark: InkletRGBA(hex: 0xF2F2F4))
    static let secondaryLabel = InkletColorToken(light: InkletRGBA(hex: 0x5E5E66), dark: InkletRGBA(hex: 0xA1A1AA))
    static let tertiaryLabel = InkletColorToken(light: InkletRGBA(hex: 0x6A6A72), dark: InkletRGBA(hex: 0x95959D))

    // Status. Used for icons and short text on neutral surfaces, never as large fills.
    static let statusSuccess = InkletColorToken(light: InkletRGBA(hex: 0x16703F), dark: InkletRGBA(hex: 0x3DCB82))
    static let statusWarning = InkletColorToken(light: InkletRGBA(hex: 0xA64B05), dark: InkletRGBA(hex: 0xF2B144))
    static let statusError = InkletColorToken(light: InkletRGBA(hex: 0xC42F2F), dark: InkletRGBA(hex: 0xFF7070))

    // Shadows for floating panels.
    static let shadowAmbient = InkletColorToken(light: .black(0.16), dark: .black(0.45))
    static let shadowKey = InkletColorToken(light: .black(0.08), dark: .black(0.25))
}

/// Colors derived from the user's macOS accent color. The accent itself is used as is
/// for fills; text and tints on top of it are adjusted so they stay readable for every
/// accent, including yellow and graphite.
enum InkletAccent {
    struct Derived: Equatable, Sendable {
        /// The accent fill: primary buttons, toggles, selected sidebar item. Slightly deeper
        /// than the system accent when that is needed for white text.
        let fill: InkletRGBA
        /// Accent text and icons on a surface, at least 4.5:1 on every surface.
        let text: InkletRGBA
        /// Text and icons on the accent fill: white, or near-black on light accents.
        let onFill: InkletRGBA
        /// Selected rows and text selection tint.
        let soft: InkletRGBA
    }

    static let minimumTextContrast = 4.5
    static let softAlphaLight = 0.14
    static let softAlphaDark = 0.22
    /// How far the fill may move toward black so white text reads on it.
    static let maximumFillDeepening = 0.2

    static func derive(from accent: InkletRGBA, isDark: Bool) -> Derived {
        let opaqueAccent = accent.withAlpha(1)
        let surface = isDark ? InkletPalette.surface.dark : InkletPalette.surface.light
        let label = isDark ? InkletPalette.label.dark : InkletPalette.label.light
        let soft = opaqueAccent.withAlpha(isDark ? softAlphaDark : softAlphaLight)
        let backgrounds = [
            surface,
            isDark ? InkletPalette.surfaceRaised.dark : InkletPalette.surfaceRaised.light,
            (isDark ? InkletPalette.surfaceSunken.dark : InkletPalette.surfaceSunken.light).composited(over: surface),
            soft.composited(over: surface),
        ]

        // Move the accent toward the label color until it reads on every background.
        var text = opaqueAccent
        var amount = 0.0
        while amount < 1, backgrounds.contains(where: { text.contrastRatio(against: $0) < minimumTextContrast }) {
            amount = min(amount + 0.05, 1)
            text = opaqueAccent.mixed(with: label, amount: amount)
        }

        // Prefer white on the fill, as macOS does, deepening the accent slightly if needed.
        // Light accents (orange, yellow, green) keep their color and take dark text instead.
        let white = InkletRGBA(hex: 0xFFFFFF)
        let black = InkletRGBA(hex: 0x000000)
        var fill = opaqueAccent
        var deepening = 0.0
        while deepening < maximumFillDeepening, white.contrastRatio(against: fill) < minimumTextContrast {
            deepening = min(deepening + 0.05, maximumFillDeepening)
            fill = opaqueAccent.mixed(with: black, amount: deepening)
        }
        if white.contrastRatio(against: fill) >= minimumTextContrast {
            return Derived(fill: fill, text: text, onFill: white, soft: soft)
        }
        return Derived(fill: opaqueAccent, text: text, onFill: InkletRGBA(hex: 0x1D1D1F), soft: soft)
    }

    static func color(_ part: @escaping @Sendable (Derived) -> InkletRGBA) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let accent = InkletRGBA(.controlAccentColor, appearance: appearance)
            return part(derive(from: accent, isDark: isDark)).nsColor
        })
    }
}

extension InkletTheme {
    // MARK: Color

    static var accent: Color { InkletAccent.color { $0.fill } }
    static var accentText: Color { InkletAccent.color { $0.text } }
    static var accentSoft: Color { InkletAccent.color { $0.soft } }
    static var onAccent: Color { InkletAccent.color { $0.onFill } }

    static var surface: Color { InkletPalette.surface.color }
    static var surfaceRaised: Color { InkletPalette.surfaceRaised.color }
    static var surfaceSunken: Color { InkletPalette.surfaceSunken.color }

    static var fill: Color { InkletPalette.fill.color }
    static var fillHover: Color { InkletPalette.fillHover.color }
    static var fillPressed: Color { InkletPalette.fillPressed.color }

    static var hairline: Color { InkletPalette.hairline.color }
    static var strokeStrong: Color { InkletPalette.strokeStrong.color }
    static var topHighlight: Color { InkletPalette.topHighlight.color }

    static var label: Color { InkletPalette.label.color }
    static var secondaryLabel: Color { InkletPalette.secondaryLabel.color }
    static var tertiaryLabel: Color { InkletPalette.tertiaryLabel.color }

    static var statusSuccess: Color { InkletPalette.statusSuccess.color }
    static var statusWarning: Color { InkletPalette.statusWarning.color }
    static var statusError: Color { InkletPalette.statusError.color }

    // MARK: Typography

    /// SF Pro type scale. Nothing in the UI is smaller than `minimumSize`.
    enum Typography {
        static let minimumSize: CGFloat = 11

        /// Settings pane titles.
        static var pageTitle: Font { .system(size: 20, weight: .semibold) }
        /// Section and panel titles.
        static var title: Font { .system(size: 15, weight: .semibold) }
        /// The user's text in editors and results.
        static var editor: Font { .system(size: editorSize) }
        static let editorSize: CGFloat = 15
        /// Added to the font's natural line height so editor lines are 23 pt.
        static let editorLineSpacing: CGFloat = 5
        /// Button titles, menu items, mode names.
        static var control: Font { .system(size: 13, weight: .medium) }
        /// Row labels and ordinary interface text.
        static var body: Font { .system(size: 13) }
        /// Help text under a setting, secondary descriptions.
        static var help: Font { .system(size: 12) }
        /// Shortcut hints, badges, section headers in small panels.
        static var caption: Font { .system(size: 11, weight: .medium) }
        /// Key labels inside keycaps.
        static var keycap: Font { .system(size: 11, weight: .medium, design: .monospaced) }
    }

    // MARK: Layout

    /// 4 pt grid.
    enum Spacing {
        /// Icon to its label.
        static let xxs: CGFloat = 4
        /// Between related controls.
        static let xs: CGFloat = 8
        /// Inside rows and banners.
        static let sm: CGFloat = 12
        /// Panel edges.
        static let md: CGFloat = 16
        /// Editor text inset.
        static let lg: CGFloat = 20
        /// Between groups.
        static let xl: CGFloat = 24
        /// Page margins.
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let keycap: CGFloat = 4
        /// Icon buttons, small controls, rows inside a card.
        static let small: CGFloat = 6
        /// Buttons, fields, chips, list rows.
        static let control: CGFloat = 8
        /// Cards, setting groups, the selection bar, the translation card.
        static let card: CGFloat = 12
        /// The writing popover and windows.
        static let panel: CGFloat = 16

        /// The radius for a shape inset inside a rounded container, so the corners stay concentric.
        static func concentric(outer: CGFloat, inset: CGFloat) -> CGFloat {
            max(outer - inset, 0)
        }
    }

    enum ControlHeight {
        static let small: CGFloat = 24
        static let regular: CGFloat = 28
        static let large: CGFloat = 32
        /// Headers, action bars and toolbars.
        static let bar: CGFloat = 44
    }

    enum IconSize {
        /// Inline with captions.
        static let small: CGFloat = 12
        /// Toolbar and icon buttons.
        static let regular: CGFloat = 14
        /// Row leading icons.
        static let large: CGFloat = 16
    }

    // MARK: Motion

    enum Motion {
        static let fastDuration: Double = 0.12
        static let standardDuration: Double = 0.2

        /// Hover and press feedback.
        static var fast: Animation { .easeOut(duration: fastDuration) }
        /// Icon swaps and state changes inside a view.
        static var standard: Animation { .easeInOut(duration: standardDuration) }
        /// Panels opening and resizing.
        static var panel: Animation { .spring(response: 0.32, dampingFraction: 0.86) }

        /// How content appears. Only fades when Reduce Motion is on.
        static func appear(reduceMotion: Bool) -> AnyTransition {
            reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98))
        }
    }

    // MARK: Elevation

    enum Elevation {
        static let floatingAmbientRadius: CGFloat = 16
        static let floatingAmbientY: CGFloat = 12
        static let floatingKeyRadius: CGFloat = 3
        static let floatingKeyY: CGFloat = 2
        /// Opacity of the surface tint laid over the vibrancy material.
        static let materialTintOpacity: Double = 0.82
    }
}
