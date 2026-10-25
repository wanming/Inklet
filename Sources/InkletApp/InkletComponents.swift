import AppKit
import SwiftUI

// Shared building blocks of the "Ink & Paper" design language (docs/DESIGN.md).
// New UI composes these instead of styling controls by hand.

// MARK: - Buttons

/// Text buttons. One `.primary` per view at most; everything else is `.secondary` or `.ghost`.
struct InkletButtonStyle: ButtonStyle {
    enum Kind {
        /// Ink fill, the single main action of a view.
        case primary
        /// Raised surface with a hairline, for secondary commands.
        case secondary
        /// No chrome until hovered, for toolbar and inline commands.
        case ghost
    }

    enum Size {
        case small
        case regular
    }

    var kind: Kind = .secondary
    var size: Size = .regular

    func makeBody(configuration: Configuration) -> some View {
        InkletButtonBody(configuration: configuration, kind: kind, size: size)
    }
}

private struct InkletButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: InkletButtonStyle.Kind
    let size: InkletButtonStyle.Size
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var height: CGFloat {
        size == .small ? InkletTheme.ControlHeight.small : InkletTheme.ControlHeight.regular
    }

    private var radius: CGFloat {
        size == .small ? InkletTheme.Radius.small : InkletTheme.Radius.control
    }

    private var font: Font {
        size == .small ? .system(size: 12, weight: .medium) : InkletTheme.Typography.control
    }

    private var foreground: Color {
        kind == .primary ? InkletTheme.onAccent : InkletTheme.label
    }

    private var background: Color {
        switch kind {
        case .primary:
            return configuration.isPressed ? InkletTheme.accent.opacity(0.82) : InkletTheme.accent
        case .secondary:
            if configuration.isPressed { return InkletTheme.fillPressed }
            return isHovered ? InkletTheme.fillHover : InkletTheme.surfaceRaised
        case .ghost:
            if configuration.isPressed { return InkletTheme.fillPressed }
            return isHovered ? InkletTheme.fillHover : .clear
        }
    }

    var body: some View {
        configuration.label
            .font(font)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, size == .small ? 10 : InkletTheme.Spacing.sm)
            .frame(minHeight: height)
            .background(background, in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(InkletTheme.hairline)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: radius))
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovered = $0 }
            .animation(InkletTheme.Motion.fast, value: isHovered)
            .animation(InkletTheme.Motion.fast, value: configuration.isPressed)
    }
}

/// Square icon-only buttons. Always pair with `.help(_:)` and `.accessibilityLabel(_:)`.
struct InkletIconButtonStyle: ButtonStyle {
    var size: CGFloat = InkletTheme.ControlHeight.regular
    /// Tints the glyph with the accent, for an icon showing an active state such as playing.
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        InkletIconButtonBody(configuration: configuration, size: size, isActive: isActive)
    }
}

private struct InkletIconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let size: CGFloat
    let isActive: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var background: Color {
        if configuration.isPressed { return InkletTheme.fillPressed }
        return isHovered || isActive ? InkletTheme.fillHover : .clear
    }

    var body: some View {
        configuration.label
            .font(.system(size: InkletTheme.IconSize.regular, weight: .medium))
            .foregroundStyle(isActive ? InkletTheme.accentText : InkletTheme.secondaryLabel)
            .frame(width: size, height: size)
            .background(background, in: RoundedRectangle(cornerRadius: InkletTheme.Radius.small))
            .contentShape(RoundedRectangle(cornerRadius: InkletTheme.Radius.small))
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovered = $0 }
            .animation(InkletTheme.Motion.fast, value: isHovered)
            .animation(InkletTheme.Motion.fast, value: configuration.isPressed)
    }
}

// MARK: - Surfaces

/// NSVisualEffectView behind floating panels and sidebars.
struct InkletMaterialBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

private struct InkletFloatingPanelModifier: ViewModifier {
    var cornerRadius: CGFloat
    var usesMaterial: Bool

    func body(content: Content) -> some View {
        content
            .background {
                if usesMaterial {
                    ZStack {
                        InkletMaterialBackground(material: .popover)
                        InkletTheme.surface.opacity(InkletTheme.Elevation.materialTintOpacity)
                    }
                } else {
                    InkletTheme.surface
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(InkletTheme.strokeStrong)
            }
            .overlay(alignment: .top) {
                InkletTheme.topHighlight
                    .frame(height: 1)
                    .padding(.horizontal, cornerRadius)
            }
            .shadow(
                color: InkletPalette.shadowAmbient.color,
                radius: InkletTheme.Elevation.floatingAmbientRadius,
                x: 0,
                y: InkletTheme.Elevation.floatingAmbientY
            )
            .shadow(
                color: InkletPalette.shadowKey.color,
                radius: InkletTheme.Elevation.floatingKeyRadius,
                x: 0,
                y: InkletTheme.Elevation.floatingKeyY
            )
    }
}

private struct InkletCardModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(InkletTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(InkletTheme.hairline)
            }
    }
}

extension View {
    /// The popover, the selection bar and other panels that float above other apps.
    /// The hosting window needs room around the view for the shadow.
    func inkletFloatingPanel(
        cornerRadius: CGFloat = InkletTheme.Radius.panel,
        usesMaterial: Bool = true
    ) -> some View {
        modifier(InkletFloatingPanelModifier(cornerRadius: cornerRadius, usesMaterial: usesMaterial))
    }

    /// A raised group on a surface, such as a settings group or a result card.
    func inkletCard(cornerRadius: CGFloat = InkletTheme.Radius.card) -> some View {
        modifier(InkletCardModifier(cornerRadius: cornerRadius))
    }
}

/// A hairline between rows of a card, inset from the leading edge.
struct InkletRowDivider: View {
    var leadingInset: CGFloat = InkletTheme.Spacing.sm

    var body: some View {
        InkletTheme.hairline
            .frame(height: 1)
            .padding(.leading, leadingInset)
    }
}

/// Background for a selectable list row: accent-soft when selected, neutral fill on hover.
struct InkletRowBackground: View {
    var isSelected: Bool
    var isHovered = false

    var body: some View {
        RoundedRectangle(cornerRadius: InkletTheme.Radius.control)
            .fill(isSelected ? InkletTheme.accentSoft : isHovered ? InkletTheme.fill : .clear)
            .animation(InkletTheme.Motion.fast, value: isHovered)
    }
}

// MARK: - Feedback

/// An inline message with a tone icon and an optional action that resolves it.
/// Neutral background in every tone; only the icon carries the color.
struct InkletStatusBanner<Action: View>: View {
    enum Tone {
        case info
        case success
        case warning
        case error

        var systemImage: String {
            switch self {
            case .info: "info.circle"
            case .success: "checkmark.circle"
            case .warning: "exclamationmark.triangle"
            case .error: "exclamationmark.octagon"
            }
        }

        var color: Color {
            switch self {
            case .info: InkletTheme.secondaryLabel
            case .success: InkletTheme.statusSuccess
            case .warning: InkletTheme.statusWarning
            case .error: InkletTheme.statusError
            }
        }
    }

    var tone: Tone
    var message: String
    @ViewBuilder var action: () -> Action

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: tone.systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tone.color)
                .accessibilityHidden(true)
            Text(message)
                .font(InkletTheme.Typography.help)
                .foregroundStyle(InkletTheme.label)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            action()
        }
        .padding(.leading, InkletTheme.Spacing.sm)
        .padding(.trailing, InkletTheme.Spacing.xs)
        .padding(.vertical, InkletTheme.Spacing.xs)
        .background(InkletTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: InkletTheme.Radius.control))
        .accessibilityElement(children: .contain)
    }
}

extension InkletStatusBanner where Action == EmptyView {
    init(tone: Tone, message: String) {
        self.init(tone: tone, message: message) { EmptyView() }
    }
}
