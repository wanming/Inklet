import Carbon
import Foundation

public struct Hotkey: Equatable, Sendable {
    public struct Modifier: OptionSet, Equatable, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let command = Modifier(rawValue: UInt32(cmdKey))
        public static let option = Modifier(rawValue: UInt32(optionKey))
        public static let control = Modifier(rawValue: UInt32(controlKey))
        public static let shift = Modifier(rawValue: UInt32(shiftKey))
    }

    public let keyCode: UInt32
    public let modifiers: Modifier

    public init(keyCode: UInt32, modifiers: Modifier) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static func parse(_ value: String) throws -> Hotkey {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "⌥space", "option+space":
            Hotkey(keyCode: 49, modifiers: [.option])
        case "⌘space", "command+space":
            Hotkey(keyCode: 49, modifiers: [.command])
        default:
            throw HotkeyError.unsupported(value)
        }
    }
}

public enum HotkeyError: Error, Equatable {
    case unsupported(String)
    case registrationFailed(OSStatus)
}

public final class GlobalHotkeyManager: @unchecked Sendable {
    public typealias Handler = @Sendable () -> Void

    private let signature: OSType
    private let id: UInt32
    private var hotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var handler: Handler?

    public init(signature: OSType = 0x46554C54, id: UInt32 = 1) {
        self.signature = signature
        self.id = id
    }

    deinit {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
        }

        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    public func register(_ hotkey: Hotkey, handler: @escaping Handler) throws {
        try installHandlerIfNeeded()

        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }

        self.handler = handler

        let eventHotkeyID = EventHotKeyID(signature: signature, id: id)
        var registeredHotkeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers.rawValue,
            eventHotkeyID,
            GetApplicationEventTarget(),
            0,
            &registeredHotkeyRef
        )

        guard status == noErr else {
            self.handler = nil
            throw HotkeyError.registrationFailed(status)
        }

        hotkeyRef = registeredHotkeyRef
    }

    public func unregister() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }

        handler = nil
    }

    private func installHandlerIfNeeded() throws {
        guard handlerRef == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var installedHandlerRef: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            globalHotkeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &installedHandlerRef
        )

        guard status == noErr else {
            throw HotkeyError.registrationFailed(status)
        }

        handlerRef = installedHandlerRef
    }

    fileprivate func handleHotkeyPressed() {
        handler?()
    }
}

private let globalHotkeyEventHandler: EventHandlerUPP = { _, _, userData in
    guard let userData else {
        return OSStatus(eventNotHandledErr)
    }

    let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleHotkeyPressed()

    return noErr
}
