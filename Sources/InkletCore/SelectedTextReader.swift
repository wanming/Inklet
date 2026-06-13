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
    public typealias ApplicationFocusedElementProvider = @Sendable (pid_t) -> SelectedTextElement?
    public typealias ElementAtPositionProvider = @Sendable (SelectionPoint) -> SelectedTextElement?
    public typealias SelectedTextProvider = @Sendable (SelectedTextElement) -> Result<String, SelectedTextReadError>

    private let isTrusted: TrustChecker
    private let focusedElementProvider: FocusedElementProvider
    private let applicationFocusedElementProvider: ApplicationFocusedElementProvider
    private let elementAtPositionProvider: ElementAtPositionProvider
    private let selectedTextProvider: SelectedTextProvider

    public init(
        isTrusted: @escaping TrustChecker = { AXIsProcessTrusted() },
        focusedElementProvider: @escaping FocusedElementProvider = { Self.systemFocusedElement() },
        applicationFocusedElementProvider: @escaping ApplicationFocusedElementProvider = {
            Self.systemFocusedElement(forProcessIdentifier: $0)
        },
        elementAtPositionProvider: @escaping ElementAtPositionProvider = { Self.systemElement(at: $0) },
        selectedTextProvider: @escaping SelectedTextProvider = { Self.systemSelectedText(from: $0) }
    ) {
        self.isTrusted = isTrusted
        self.focusedElementProvider = focusedElementProvider
        self.applicationFocusedElementProvider = applicationFocusedElementProvider
        self.elementAtPositionProvider = elementAtPositionProvider
        self.selectedTextProvider = selectedTextProvider
    }

    public func readSelectedText(
        sourceProcessIdentifier: pid_t? = nil,
        mouseLocation: SelectionPoint? = nil
    ) -> SelectedTextReadResult {
        guard isTrusted() else {
            return .permissionDenied
        }

        let elements = candidateElements(
            sourceProcessIdentifier: sourceProcessIdentifier,
            mouseLocation: mouseLocation
        )
        guard !elements.isEmpty else {
            return .missingFocusedElement
        }

        var fallbackResult: SelectedTextReadResult = .emptySelection
        for element in elements {
            switch selectedTextProvider(element) {
            case .success(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return .success(trimmed)
                }
                fallbackResult = .emptySelection
            case .failure(.unsupported):
                if fallbackResult == .emptySelection {
                    fallbackResult = .unsupported
                }
            case .failure(.accessibilityFailure(let message)):
                fallbackResult = .failed(message)
            }
        }

        return fallbackResult
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

    public static func systemFocusedElement(forProcessIdentifier processIdentifier: pid_t) -> SelectedTextElement? {
        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        var focusedObject: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(
            applicationElement,
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

    public static func systemElement(at point: SelectionPoint) -> SelectedTextElement? {
        let systemWide = AXUIElementCreateSystemWide()
        let accessibilityPoint = accessibilityPoint(fromMouseLocation: point)
        var elementObject: AXUIElement?
        let status = AXUIElementCopyElementAtPosition(
            systemWide,
            Float(accessibilityPoint.x),
            Float(accessibilityPoint.y),
            &elementObject
        )

        guard status == .success,
              let element = elementObject
        else {
            return nil
        }

        return SelectedTextElement(rawValue: AXElementBox(element))
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

    private func candidateElements(
        sourceProcessIdentifier: pid_t?,
        mouseLocation: SelectionPoint?
    ) -> [SelectedTextElement] {
        [
            focusedElementProvider(),
            sourceProcessIdentifier.flatMap(applicationFocusedElementProvider),
            mouseLocation.flatMap(elementAtPositionProvider)
        ].compactMap { $0 }
    }

    private static func accessibilityPoint(fromMouseLocation point: SelectionPoint) -> SelectionPoint {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            let mainDisplayBounds = CGDisplayBounds(CGMainDisplayID())
            return SelectionPoint(x: point.x, y: Double(mainDisplayBounds.height) - point.y)
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success else {
            let mainDisplayBounds = CGDisplayBounds(CGMainDisplayID())
            return SelectionPoint(x: point.x, y: Double(mainDisplayBounds.height) - point.y)
        }

        let mainDisplayBounds = CGDisplayBounds(CGMainDisplayID())
        return SelectionPoint(x: point.x, y: Double(mainDisplayBounds.height) - point.y)
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
