# Inklet design language: Ink & Paper

This is the source of truth for how Inklet looks and moves. Every new or changed screen follows it. The values live in code in `Sources/InkletApp/InkletDesignTokens.swift` (tokens) and `Sources/InkletApp/InkletComponents.swift` (shared components). `Tests/InkletCoreTests/DesignTokensTests.swift` checks contrast and the spacing grid, so a token change that breaks the rules fails CI.

Visual reference (light and dark, every surface): [Inklet design language canvas](https://claude.ai/artifact/CiuZNNoGS4ubGckvduYy3c).

## Principles

1. **Content first.** The user's text is the largest, highest-contrast thing on screen. Chrome recedes into hairlines, tints and secondary text.
2. **One accent, used once.** The accent appears on the single primary action, the focus ring and the current selection. It is never decoration.
3. **Native first.** macOS materials, SF Pro, SF Symbols, system focus, menus and window behaviour. Inklet should feel like part of macOS, not a web page in a panel.
4. **Roomy, not big.** A 4 pt grid with 16–20 pt edges gives air. No text below 11 pt, no control below 24 pt.
5. **Calm motion.** Short, springy transitions that explain a change of state. Fade only when Reduce Motion is on.

## Color

Use the semantic accessors on `InkletTheme` in views. `InkletPalette` holds the raw light and dark values and is for tests and AppKit code that needs an `NSColor`.

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `accent` | macOS accent | macOS accent | Primary button fill, toggles, selected sidebar item, focus ring |
| `accentText` | accent, toward `label` as needed | same | Accent text and icons on a surface |
| `accentSoft` | accent 14% | accent 22% | Selected list row, text selection tint |
| `onAccent` | white, or `#1D1D1F` on light accents | same | Text and icons on an `accent` fill |
| `surface` | `#F6F6F7` | `#1E1E21` | Panel and window background (tint over the material) |
| `surfaceRaised` | white | `#2A2A2E` | Cards, settings groups, fields, the result card |
| `surfaceSunken` | black 3% | black 15% | Action bars, toolbars, banners |
| `fill` / `fillHover` / `fillPressed` | black 5 / 7 / 11% | white 7 / 10 / 14% | Control backgrounds and their hover and pressed states |
| `hairline` | black 8% | white 8% | Dividers, card borders |
| `strokeStrong` | black 14% | white 14% | Floating panel border, keycaps, field borders |
| `topHighlight` | white 70% | white 6% | 1 pt highlight along the top edge of a floating panel |
| `label` | `#1D1D1F` | `#F2F2F4` | Primary text |
| `secondaryLabel` | `#5E5E66` | `#A1A1AA` | Help text, idle icons, hints |
| `tertiaryLabel` | `#6A6A72` | `#95959D` | Placeholders, disabled text, counts |
| `statusSuccess` | `#16703F` | `#3DCB82` | Copied, verified |
| `statusWarning` | `#A64B05` | `#F2B144` | Recoverable problems |
| `statusError` | `#C42F2F` | `#FF7070` | Failures |

Rules:

- All text tokens reach WCAG AA (4.5:1) on `surface`, `surfaceRaised` and `surfaceSunken` in both appearances. `DesignTokensTests` enforces it.
- Status colors tint an icon or a short word. Never fill a strip or a panel with red or yellow; use `InkletStatusBanner`.
- Do not write `Color.white.opacity(…)`, `Color.black.opacity(…)` or `Color(red:…)` in a view. Those break in the other appearance. Add or reuse a token.
- The accent follows the macOS accent color the user picked in System Settings > Appearance. `InkletAccent.derive(from:isDark:)` keeps it readable for every choice: `accentText` moves toward `label` until it reaches 4.5:1 on every surface; the `accent` fill deepens by up to 20% so white text reaches 4.5:1, and light accents (orange, yellow, green, light graphite) keep their color and take `#1D1D1F` text instead. `DesignTokensTests` checks all eight macOS accents in both appearances.
- Never hard-code a brand color for emphasis; use the accent tokens.

## Typography

SF Pro through `InkletTheme.Typography`. Nothing is smaller than 11 pt.

| Token | Size / line | Weight | Use |
| --- | --- | --- | --- |
| `pageTitle` | 20 / 26 | semibold | Settings pane title |
| `title` | 15 / 20 | semibold | Section and panel titles |
| `editor` | 15 / 21 (`editorLineSpacing` 3 when measuring) | regular | The user's text in editors and results |
| `control` | 13 / 18 | medium | Buttons, menu items, mode names |
| `body` | 13 / 18 | regular | Row labels, interface text |
| `help` | 12 / 16 | regular | Help under a setting, descriptions, banners |
| `caption` | 11 / 14 | medium | Shortcut hints, badges, small headers |
| `keycap` | 11 | medium, monospaced | Key labels inside keycaps |

Use sentence case everywhere. Chinese and English must both fit at these sizes; check the longest translation, not English.

## Layout

**Spacing** (`InkletTheme.Spacing`, 4 pt grid): `xxs` 4 icon to label, `xs` 8 between related controls, `sm` 12 inside rows and banners, `md` 16 panel edges, `lg` 20 editor text inset, `xl` 24 between groups, `xxl` 32 page margins.

**Radius** (`InkletTheme.Radius`): `keycap` 4, `small` 6 (icon buttons, rows inside a card), `control` 8 (buttons, fields, chips, list rows), `card` 12 (cards, settings groups, selection bar, translation card), `panel` 16 (popover, windows). A shape inset inside a rounded container uses `Radius.concentric(outer:inset:)`, for example the result card inside the popover is 16 − 8 = 8.

**Control heights** (`InkletTheme.ControlHeight`): `small` 24, `regular` 28, `large` 32, `bar` 44 for headers, action bars and toolbars.

**Icons** (`InkletTheme.IconSize`): SF Symbols at medium weight, 12 inline with captions, 14 in buttons and toolbars, 16 as row leading icons. Map SF Symbol names for modes and actions in one function (today `writingModeIconName(for:)`) rather than at each call site.

## Elevation and material

- **Flat:** cards and groups. `surfaceRaised` with a `hairline` border, no shadow (`.inkletCard()`).
- **Floating:** the popover, selection bar and translation card float above other apps. `.inkletFloatingPanel()` gives the popover material with a `surface` tint at 82%, a `strokeStrong` border and the 1 pt `topHighlight`. The shadow is the panel's own window shadow (`hasShadow`), which follows the hosting view's rounded mask, the same as native popovers.
- Do not draw SwiftUI shadows on panels or windows; a masked hosting view clips them anyway.

The previous 75% black, radius 48 shadow is retired.

## Motion

`InkletTheme.Motion`:

| Token | Value | Use |
| --- | --- | --- |
| `fast` | 0.12 s ease-out | Hover and press |
| `standard` | 0.20 s ease-in-out | Icon swaps, state changes inside a view |
| `panel` | spring, response 0.32, damping 0.86 | Panels opening and resizing |
| `appear(reduceMotion:)` | fade + scale 0.98 → 1 | Content appearing; fade only with Reduce Motion |

Read `@Environment(\.accessibilityReduceMotion)` and pass it to `appear(reduceMotion:)`. Never animate text the user is reading or typing.

## Components

| Component | Code | Notes |
| --- | --- | --- |
| Primary button | `.buttonStyle(InkletButtonStyle(kind: .primary))` | `accent` fill, `onAccent` text, 28 pt, radius 8. At most one per view. Shows its shortcut glyph at 80% opacity after the title. |
| Secondary button | `InkletButtonStyle(kind: .secondary)` | Raised surface with a hairline. |
| Ghost button | `InkletButtonStyle(kind: .ghost)` | No chrome until hovered. Toolbars and inline actions. |
| Icon button | `.buttonStyle(InkletIconButtonStyle())` | 28 × 28, radius 6, `secondaryLabel` glyph, hover fill. `isActive` tints the glyph with the accent (for example while playing). Always add `.help` and `.accessibilityLabel`. |
| Keycap | `Keycap` | 18 pt tall (20 when not compact), radius 4, `keycap` font, `surfaceRaised` with a `strokeStrong` border. Paired with a `caption` label as a shortcut hint; without a label it needs `.help`. |
| Mode chip | (popover header) | 28 pt, radius 8, `fill` background; mode icon in `accentText`, name in `control` semibold, chevron. Opens the mode picker. |
| Card | `.inkletCard()` | Settings groups and the result card. Rows inside are separated by `InkletRowDivider`. |
| List row | `InkletRowBackground` | 40 pt rows in the mode picker. Selected: `accentSoft` with an `accentText` icon. Hover: `fill`. |
| Status banner | `InkletStatusBanner(tone:message:action:)` | Neutral `surfaceSunken`, tone icon, message in `label`, one inline action that resolves the problem (Open Settings, Retry, Copy). |
| Floating panel | `.inkletFloatingPanel()` | See Elevation. |
| Material | `InkletMaterialBackground(material:)` | `.popover` for floating panels, `.sidebar` for the settings sidebar. |

Interaction states follow `AGENTS.md` § Interaction Details: loading replaces the icon with a spinner in place, playing and success swap the icon in place, and no state change moves the layout.

## Surfaces

**Writing popover** (600 wide, radius 16, floating). Header 44: the mode chip (mode icon in `accentText`, name, chevron; opens the mode picker) on the left, the provider and model as a quiet monospaced caption in `tertiaryLabel`, and a settings icon button on the right. Editor: `editor` text, 20 pt horizontal and 14 pt vertical inset. Result: a card inset 8 pt from the panel edges (radius 16 − 8 = 8) with a copy icon button in its corner; a stale result shows a "Generated with" caption row at the top of the card. Action bar 44 on `surfaceSunken`: "Insert original" with its keycaps, then keycap-only hints for new line and mode cycling (named by tooltips) on the left; the dictation status, `esc` Back and the one primary button (Transform, Insert, Regenerate; secondary style while the draft is empty) on the right. Long localized text wraps the leading hints onto a second row. While generating, the bar shows a spinner, the busy title and `esc` Stop at the same height. Errors use an error status banner above the action bar.

**Mode picker** (same panel). Search row 52 with a 16 pt magnifier and `editor`-size input; 40 pt rows with a 24 pt icon tile, name in `control`, source (Built in, Your mode) in `caption`, shortcut on the right; footer bar with move, choose and close hints.

**Selection bar** (floating, radius 12, 36 tall with a 4 pt inset, so buttons are radius 8). Chromeless 28 pt buttons with a 14 pt icon and a `control` label, 2 pt apart, with a neutral fill on hover; overflow actions sit behind an ellipsis button. Loading swaps the icon for a spinner in place, so the bar never changes width.

**Translation card** (floating, 300 wide by default, resizable, radius 12). Translated text in 14 pt with 3 pt line spacing directly on the surface; a toolbar under a hairline with the copy icon button on the left and the original and translated audio buttons on the right. Errors show a warning icon, the message in `body`, and a Retry button. Planned: the target language as a menu in the toolbar.

**Settings** (target; not migrated yet, native titled window). A 210 pt sidebar on the sidebar material with 30 pt items; the selected item uses the `accent` fill with `onAccent` text. The pane has a `pageTitle`, then grouped cards: each row is at least 44 pt, label in `body` with optional `help` below on the left, control on the right, rows separated by inset hairlines. Section order: General, Write Assistant, Prompt Modes, Selection Assistant, History, About. Expert options go in an Advanced disclosure at the end of a pane.

## Do and don't

- Do let the user's text carry the screen. Don't add cards, gradients, glows or colored backgrounds for emphasis.
- Do use one primary button. Don't color secondary actions with the accent.
- Do use tokens. Don't type a font size, radius, color or shadow in a view; if a token is missing, add it here and in `InkletDesignTokens.swift` in the same change.
- Do keep icon-only buttons labeled (`.help` and `.accessibilityLabel`). Don't rely on color alone to show state; pair it with an icon or text.
- Do check both appearances and both Chinese and English at the real window size.

## Adding something new

1. Compose it from the components above. If none fits, build it from tokens only.
2. If a new pattern will be reused, add it to `InkletComponents.swift` and to the Components table here.
3. If it needs a new token, add it to `InkletPalette` or `InkletTheme` and to the tables here; add a contrast case to `DesignTokensTests` for any new text color.
4. Add the surface to the canvas linked above when it is a new screen.

## Migration from the earlier style

The tokens above were introduced alongside the earlier ones. Surfaces move over one at a time, and the earlier tokens in `InkletTheme.swift` are removed once nothing uses them.

| Earlier | Now |
| --- | --- |
| `panelBackground` | `surface` |
| `elevatedBackground`, `fieldBackground` | `surfaceRaised` |
| `toolbarBackground` | `surfaceSunken` |
| `controlFill`, `Color.white.opacity(…)` hovers | `fill`, `fillHover` |
| `subtleBorder` / `strongBorder` | `hairline` / `strokeStrong` |
| `glassHighlight` | `topHighlight` |
| `textPrimary` / `textSecondary` | `label` / `secondaryLabel` |
| `textTertiary`, `textFaint` | `tertiaryLabel` |
| `primary` (raw system accent) | `accent` for fills, `accentText` for text and icons |
| `success`, `warning`, `.red` | `statusSuccess`, `statusWarning`, `statusError` |
| `cornerRadius` 12, `controlRadius` 8 | `Radius.card`, `Radius.control` |
| `.shadow(color: .black.opacity(0.75), radius: 48, …)` | `.inkletFloatingPanel()` |
| 8–10 pt labels | `Typography.caption` (11 pt) |

Migrated: the writing popover, the mode picker, the selection bar and the translation card. Next: Settings and About, after the open Settings changes land, to avoid conflicts.
