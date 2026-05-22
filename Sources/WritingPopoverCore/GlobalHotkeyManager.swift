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

    public var displayString: String {
        "\(modifiers.displayString)\(Self.displayName(for: keyCode) ?? "Key\(keyCode)")"
    }

    public static func parse(_ value: String) throws -> Hotkey {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmedValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")

        switch normalized {
        case "⌥space", "option+space", "alt+space":
            return Hotkey(keyCode: 49, modifiers: [.option])
        case "⌘space", "command+space", "cmd+space":
            return Hotkey(keyCode: 49, modifiers: [.command])
        default:
            break
        }

        var modifiers: Modifier = []
        var keyPart = normalized
        let replacements: [(String, Modifier)] = [
            ("command+", .command), ("cmd+", .command), ("⌘", .command),
            ("option+", .option), ("alt+", .option), ("⌥", .option),
            ("control+", .control), ("ctrl+", .control), ("⌃", .control),
            ("shift+", .shift), ("⇧", .shift)
        ]
        var didConsumeModifier = true
        while didConsumeModifier {
            didConsumeModifier = false
            for (prefix, modifier) in replacements where keyPart.hasPrefix(prefix) {
                modifiers.insert(modifier)
                keyPart.removeFirst(prefix.count)
                didConsumeModifier = true
            }
        }

        guard !modifiers.isEmpty,
              modifiers != [.shift],
              let keyCode = keyCode(for: keyPart)
        else {
            throw HotkeyError.unsupported(trimmedValue)
        }

        return Hotkey(keyCode: keyCode, modifiers: modifiers)
    }

    public static func displayName(for keyCode: UInt32) -> String? {
        keyNamesByCode[keyCode]
    }

    public static func keyCode(for keyName: String) -> UInt32? {
        keyCodesByName[keyName.lowercased()]
    }

    private static let keyNamesByCode: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Return): "Return",
        UInt32(kVK_Tab): "Tab",
        UInt32(kVK_Escape): "Esc",
        UInt32(kVK_LeftArrow): "←",
        UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑",
        UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3", UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6", UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9", UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
        UInt32(kVK_F13): "F13", UInt32(kVK_F14): "F14", UInt32(kVK_F15): "F15", UInt32(kVK_F16): "F16",
        UInt32(kVK_F17): "F17", UInt32(kVK_F18): "F18", UInt32(kVK_F19): "F19", UInt32(kVK_F20): "F20"
    ]

    private static let keyCodesByName: [String: UInt32] = {
        var values = Dictionary(uniqueKeysWithValues: keyNamesByCode.map { ($0.value.lowercased(), $0.key) })
        values["enter"] = UInt32(kVK_Return)
        values["return"] = UInt32(kVK_Return)
        values["escape"] = UInt32(kVK_Escape)
        values["esc"] = UInt32(kVK_Escape)
        values["left"] = UInt32(kVK_LeftArrow)
        values["right"] = UInt32(kVK_RightArrow)
        values["up"] = UInt32(kVK_UpArrow)
        values["down"] = UInt32(kVK_DownArrow)
        return values
    }()
}

public extension Hotkey.Modifier {
    var displayString: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }
}

public enum HotkeyError: Error, Equatable, LocalizedError {
    case unsupported(String)
    case registrationFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .unsupported(let value):
            return "暂不支持快捷键“\(value)”。目前支持 ⌥Space、Option+Space、Alt+Space、⌘Space、Command+Space、Cmd+Space。"
        case .registrationFailed(let status):
            return "快捷键注册失败（\(status)）。"
        }
    }
}

struct HotkeyRegistrationIdentity: Equatable, Sendable {
    let signature: OSType
    let id: UInt32

    init(signature: OSType, id: UInt32) {
        self.signature = signature
        self.id = id
    }

    init(_ eventHotkeyID: EventHotKeyID) {
        self.init(signature: eventHotkeyID.signature, id: eventHotkeyID.id)
    }

    func matches(_ eventHotkeyID: EventHotKeyID) -> Bool {
        self == HotkeyRegistrationIdentity(eventHotkeyID)
    }
}

@MainActor
public final class GlobalHotkeyManager {
    public typealias Handler = @Sendable () -> Void

    nonisolated private let identity: HotkeyRegistrationIdentity
    nonisolated(unsafe) private var hotkeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var handlerRef: EventHandlerRef?
    private var handler: Handler?

    private static var nextHotkeyID: UInt32 = 1

    public init(signature: OSType = 0x46554C54, id: UInt32? = nil) {
        self.identity = HotkeyRegistrationIdentity(
            signature: signature,
            id: id ?? Self.allocateHotkeyID()
        )
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

        let eventHotkeyID = EventHotKeyID(signature: identity.signature, id: identity.id)
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

    private static func allocateHotkeyID() -> UInt32 {
        let id = nextHotkeyID
        nextHotkeyID = nextHotkeyID == UInt32.max ? 1 : nextHotkeyID + 1
        return id
    }

    nonisolated func handles(_ eventHotkeyID: EventHotKeyID) -> Bool {
        identity.matches(eventHotkeyID)
    }

    nonisolated var registrationIdentity: HotkeyRegistrationIdentity {
        identity
    }

    fileprivate func handleHotkeyPressed() {
        handler?()
    }
}

private let globalHotkeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else {
        return OSStatus(eventNotHandledErr)
    }

    var eventHotkeyID = EventHotKeyID()
    let parameterStatus = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &eventHotkeyID
    )

    guard parameterStatus == noErr else {
        return OSStatus(eventNotHandledErr)
    }

    let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    guard manager.handles(eventHotkeyID) else {
        return OSStatus(eventNotHandledErr)
    }

    MainActor.assumeIsolated {
        manager.handleHotkeyPressed()
    }

    return noErr
}
