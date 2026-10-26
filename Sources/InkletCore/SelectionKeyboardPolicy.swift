import Foundation

/// Decides which Shift key releases can mean "the user just extended a text selection".
/// Shift with letters, digits or punctuation is plain typing and must not open the selection bar.
public enum SelectionKeyboardPolicy {
    /// Virtual key codes of keys that move the caret, so Shift + key extends a selection.
    public static let selectionExtendingKeyCodes: Set<UInt16> = [
        123, // left arrow
        124, // right arrow
        125, // down arrow
        126, // up arrow
        115, // home
        119, // end
        116, // page up
        121, // page down
    ]

    public static func isSelectionExtendingKey(keyCode: UInt16) -> Bool {
        selectionExtendingKeyCodes.contains(keyCode)
    }
}
