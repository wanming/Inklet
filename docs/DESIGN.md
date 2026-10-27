# Inklet design language: Ink & Paper

This is the source of truth for how Inklet looks and moves. Every new or changed screen follows it. The values live in code in `Sources/InkletApp/InkletDesignTokens.swift` (tokens) and `Sources/InkletApp/InkletComponents.swift` (shared components). `Tests/InkletCoreTests/DesignTokensTests.swift` checks contrast and the spacing grid, so a token change that breaks the rules fails CI.

Visual reference (light and dark, every surface): [Inklet design language canvas](https://claude.ai/artifact/CiuZNNoGS4ubGckvduYy3c).

## Principles

1. **Content first.** The user's text is the largest, highest-contrast thing on screen. Chrome recedes into hairlines, tints and secondary text.
2. **One accent, used once.** The accent appears on the single primary action, the focus ring and the current selection. It is never decoration.
3. **Native first.** macOS materials, SF Pro, SF Symbols, system focus, menus and window behaviour. Inklet should feel like part of macOS, not a web page in a panel.
4. **Roomy, not big.** A 4 pt grid with 16–20 pt edges gives air. No text below 11 pt, no control below 24 pt.
5. **Calm motion.** Short, springy transitions that explain a change of state. Fade only when Reduce Motion is on.
6. **Refined by subtraction.** Premium comes from what is left out, not from effects. When a view feels busy, remove a line, a color or a control before adding anything (see Refinement rules).

## Refinement rules

Approved with the Settings refinement pass ("Refinement pass" board on the canvas). They apply to every surface.

1. **Quiet selection.** A selected navigation item is a neutral fill (`fillHover`) with a medium-weight label; only its icon takes `accentText`. List rows use `accentSoft` at most. Solid accent blocks are for the primary button and switches.
2. **Fewer lines, more layers.** Separate groups with spacing and the surface ladder (`surface`, `surfaceRaised`, `surfaceSunken`), not with dividers, dashed boxes or outlines around everything. A hairline is allowed where two scrolling regions meet.
3. **Clear type hierarchy.** One `pageTitle` per pane, `fieldLabel` (12 semibold, `secondaryLabel`) above fields, `body` for content. Headings are not all bold.
4. **Actions on demand.** Rows show their content first; row actions such as visibility and delete appear on hover or selection, so long names keep their width. A state the user must notice (a hidden mode's crossed-out eye) stays visible.
5. **Native window chrome.** Windows use the system titlebar, traffic lights, corners and shadow. No custom close buttons.

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
| `pageTitle` | 22 / 28, tracking −0.2 | semibold | Settings pane title, About title |
| `title` | 15 / 20 | semibold | Section and panel titles |
| `editor` | 15 / 21 (`editorLineSpacing` 3 when measuring) | regular | The user's text in editors and results |
| `control` | 13 / 18 | medium | Buttons, menu items, mode names |
| `body` | 13 / 18 | regular | Row labels, interface text |
| `help` | 12 / 16 | regular | Help under a setting, descriptions, banners |
| `fieldLabel` | 12 / 16 | semibold, `secondaryLabel` | The label above a field or a group |
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
| Settings sidebar item | `SettingsSidebarLabel` | 30 pt, radius 6, `secondaryLabel` icon. Selected: `fillHover`, medium weight, `accentText` icon. Hover: `fill`. |
| Field | `InkletFieldModifier` | `surfaceRaised`, radius 8, `strokeStrong` border, `accent` border when focused. |
| Status banner | `InkletStatusBanner(tone:message:action:)` | Neutral `surfaceSunken`, tone icon, message in `label`, one inline action that resolves the problem (Open Settings, Retry, Copy). |
| Floating panel | `.inkletFloatingPanel()` | See Elevation. |
| Material | `InkletMaterialBackground(material:)` | `.popover` for floating panels, `.sidebar` for the settings sidebar. |

Interaction states follow `AGENTS.md` § Interaction Details: loading replaces the icon with a spinner in place, playing and success swap the icon in place, and no state change moves the layout.

## Surfaces

**Writing popover** (600 wide, radius 16, floating). Header 44: the mode chip (mode icon in `accentText`, name, chevron; opens the mode picker) on the left, the provider and model as a quiet monospaced caption in `tertiaryLabel`, and a settings icon button on the right. Editor: `editor` text, 20 pt horizontal and 14 pt vertical inset. Result: a card inset 8 pt from the panel edges (radius 16 − 8 = 8) with a copy icon button in its corner; a stale result shows a "Generated with" caption row at the top of the card. Action bar 44 on `surfaceSunken`, quiet by default: only the dictation status and the one primary button (Transform, Insert, Regenerate; secondary style while the draft is empty; its tooltip names ↵) on the right. Holding ⌘ on its own for about half a second reveals every shortcut as labeled hints: "Insert original" ⌘↵, "Mode" ⌘↑↓, "Copy result" ⇧⌘C (only with a result) and "New line" ⇧↵ on the left, `esc` Back beside the dictation status; releasing ⌘ or pressing any key hides them, and the Command key used for dictation never reveals them. Every shortcut works whether or not it is shown. Long localized text wraps the revealed hints onto a second row. While generating, the bar shows a spinner, the busy title and `esc` Stop at the same height. Errors use an error status banner above the action bar.

**Mode picker** (same panel). Search row 52 with a 16 pt magnifier and `editor`-size input; 40 pt rows with a 24 pt icon tile, name in `control`, source (Built in, Your mode) in `caption`, shortcut on the right; footer bar with move, choose and close hints.

**Selection bar** (floating, radius 12, 36 tall with a 4 pt inset, so buttons are radius 8). Chromeless 28 pt buttons with a 14 pt icon and a `control` label, 2 pt apart, with a neutral fill on hover; overflow actions sit behind an ellipsis button. Loading swaps the icon for a spinner in place, so the bar never changes width. The whole bar is draggable: a press that moves 4 pt or more drags it (with the closed-hand cursor) instead of clicking, and the bar keeps that spot when it turns into a result; the next selection places it near the text again.

**Translation card** (floating, resizable, radius 12). The card fits its text: 320 wide (440 or 520 for long text, or the width the user last dragged it to), and only as tall as the text and toolbar, so a one-line result is a short strip; it grows up to 360 pt (or a taller height the user dragged it to) and then the text scrolls. Translated text in 14 pt with 3 pt line spacing directly on the surface, 12 pt from the edges; a toolbar under a hairline that spans the text width, 4 pt from the bottom edge like the selection bar, with the copy icon button on the left and the original and translated audio buttons on the right, their icons and labels aligned with the text edges. Errors show a warning icon, the message in `body`, and a Retry button. Planned: the target language as a menu in the toolbar.

**Settings** (860 × 560, native titled window with a transparent titlebar: the system draws the traffic lights, corners and shadow, and Esc closes it). A 210 pt sidebar on the sidebar material, starting 52 pt down to clear the traffic lights, with 30 pt items (14 pt icon, `body` label that wraps for long translations, radius 6); the selected item is a `fillHover` background with a medium-weight label and an `accentText` icon, hover uses `fill`. About sits apart at the bottom of the sidebar. The pane, on `surface`, has a 68 pt header with the `pageTitle` and the last save status as a `caption` (success icon in `statusSuccess`, errors in `statusError`); there is no custom close button. Below it, grouped cards (`settingsGroup`) with an optional 12 pt semibold `secondaryLabel` title: each row (`settingsRow`) is at least 44 pt, label in `body` with optional `help` below on the left, the control on the right, rows separated by inset hairlines. Controls that need the full width (prompt editors, the selection menu list) use a stacked row (`settingsStackedRow`) with the label above and an optional ghost action such as Restore Default on the right. Pickers are native menus at their natural width, booleans are switches, text fields are 220 pt. Prompt Modes is a 240 pt list card (34 pt rows: drag handle, name, and visibility and delete icons that appear on hover or selection; a hidden mode keeps its crossed-out eye and dims its name) next to the mode's cards. Section order: General, AI Models, Write Assistant, Prompt Modes, Live Dictation, Selection Assistant, History, About. AI Models holds one card per capability (text processing, speech to text, text to speech), each starting with an Engine row, then one API keys card where every key is typed once; a capability whose engine needs a missing key shows a short `statusWarning` line under its engine's help. Feature pages keep only their own settings and start with an engine note row (`engineNoteRow`): the engine in `help` `secondaryLabel` and a ghost "Change in AI Models" button. Expert options go in an Advanced disclosure at the end of a pane.

**About** (380 wide, native window). The pen nib on a 76 pt `accentSoft` tile, "Inklet" in `pageTitle`, version in `caption`, tagline in `body` `secondaryLabel`, links in `control` `accentText`, copyright in `caption`.

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

The tokens above were introduced alongside the earlier ones. The earlier names in `InkletTheme.swift` now return the new palette (for example `textSecondary` returns `secondaryLabel`), so surfaces that still use them already get the new colors. Surfaces move to the new names and components one at a time, and the earlier names are removed once nothing uses them.

Status: the writing popover, mode picker, selection bar, translation card, Settings, About and the welcome guide's language picker, step titles and action bar are migrated. What's New and the rest of the welcome guide use the new colors through the earlier names.

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

