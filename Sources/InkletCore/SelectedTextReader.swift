import ApplicationServices
import Foundation

public struct SelectedTextElement: Equatable, @unchecked Sendable {
    public let rawValue: AnyHashable

    public init(rawValue: AnyHashable) {
        self.rawValue = rawValue
    }
}

public enum SelectedTextReadError: Error, Equatable, Sendable {
    case unsupported
    case accessibilityFailure(String)
}

public enum SelectedTextReadResult: Equatable, Sendable {
    case success(String)
    case permissionDenied
    case emptySelection
    case unsupported
    case missingFocusedElement
    case failed(String)
}

public struct SelectedTextReader: Sendable {
    public typealias TrustChecker = @Sendable () -> Bool
    public typealias FocusedElementProvider = @Sendable () -> SelectedTextElement?
    public typealias SelectedTextProvider = @Sendable (SelectedTextElement) -> Result<String, SelectedTextReadError>

    private let isTrusted: TrustChecker
    private let focusedElementProvider: FocusedElementProvider
    private let selectedTextProvider: SelectedTextProvider

    public init(
        isTrusted: @escaping TrustChecker = { AXIsProcessTrusted() },
        focusedElementProvider: @escaping FocusedElementProvider = { Self.systemFocusedElement() },
        selectedTextProvider: @escaping SelectedTextProvider = { Self.systemSelectedText(from: $0) }
    ) {
        self.isTrusted = isTrusted
        self.focusedElementProvider = focusedElementProvider
        self.selectedTextProvider = selectedTextProvider
    }

    public func readSelectedText() -> SelectedTextReadResult {
        guard isTrusted() else {
            return .permissionDenied
        }
        guard let element = focusedElementProvider() else {
            return .missingFocusedElement
        }

        switch selectedTextProvider(element) {
        case .success(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? .emptySelection : .success(trimmed)
        case .failure(.unsupported):
            return .unsupported
        case .failure(.accessibilityFailure(let message)):
            return .failed(message)
        }
    }

    public static func systemFocusedElement() -> SelectedTextElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedObject: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )

        guard focusedStatus == .success,
              let focusedElement = focusedObject as! AXUIElement?
        else {
            return nil
        }

        return SelectedTextElement(rawValue: AXElementBox(focusedElement))
    }

    public static func systemSelectedText(from element: SelectedTextElement) -> Result<String, SelectedTextReadError> {
        guard let box = element.rawValue.base as? AXElementBox else {
            return .failure(.accessibilityFailure("Invalid focused element."))
        }

        var selectedTextObject: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            box.element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextObject
        )

        guard status == .success else {
            if status == .attributeUnsupported {
                return .failure(.unsupported)
            }
            return .failure(.accessibilityFailure("Accessibility read failed with status \(status.rawValue)."))
        }

        guard let selectedText = selectedTextObject as? String else {
            return .success("")
        }
        return .success(selectedText)
    }
}

private final class AXElementBox: Hashable, @unchecked Sendable {
    let element: AXUIElement

    init(_ element: AXUIElement) {
        self.element = element
    }

    static func == (lhs: AXElementBox, rhs: AXElementBox) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
