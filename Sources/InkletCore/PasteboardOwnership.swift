import AppKit
import Foundation

/// Marks the moments Inklet itself changes the general pasteboard for a moment, such as the
/// synthetic copy that reads a selection or the paste that inserts a result, so clipboard history
/// records only what the person copied.
@MainActor
public final class PasteboardOwnership {
    public static let shared = PasteboardOwnership()

    public struct Claim: Hashable, Sendable {
        fileprivate let id: UUID
    }

    private var activeClaims: Set<UUID> = []

    /// Pasteboard changes up to this change count were Inklet's own, including the restore that put
    /// back what was there before, and are not history.
    public private(set) var ignoredThroughChangeCount: Int?

    /// Runs just before a claim starts, so a watcher can first record a copy the person just made.
    public var willClaim: (() -> Void)?

    public init() {}

    public var isClaimed: Bool {
        !activeClaims.isEmpty
    }

    /// Claims the general pasteboard; other pasteboards (tests use private ones) need no claim.
    public func claim(_ pasteboard: NSPasteboard) -> Claim? {
        guard pasteboard.name == .general else {
            return nil
        }
        return claim()
    }

    public func claim() -> Claim {
        willClaim?()
        let claim = Claim(id: UUID())
        activeClaims.insert(claim.id)
        return claim
    }

    /// Ends a claim. Pass the change count when the pasteboard holds Inklet's own or restored
    /// contents, so those are not recorded; pass nil when it now holds something the person copied.
    public func release(_ claim: Claim?, ignoringThrough changeCount: Int?) {
        guard let claim, activeClaims.remove(claim.id) != nil else {
            return
        }
        if let changeCount {
            ignoredThroughChangeCount = max(ignoredThroughChangeCount ?? changeCount, changeCount)
        }
    }

    public func isIgnored(changeCount: Int) -> Bool {
        guard let ignoredThroughChangeCount else {
            return false
        }
        return changeCount <= ignoredThroughChangeCount
    }
}
