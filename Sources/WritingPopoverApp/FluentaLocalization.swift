import Foundation
import WritingPopoverCore

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .system: L10n.text("language.system")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
}

enum FluentaLanguageStore {
    private static let key = "FluentaInterfaceLanguage"

    static var selectedLanguage: InterfaceLanguage {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: key) else {
                return .english
            }
            return InterfaceLanguage(rawValue: rawValue) ?? .english
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            NotificationCenter.default.post(name: .fluentaLanguageDidChange, object: nil)
        }
    }
}

enum L10n {
    static func text(_ key: String) -> String {
        let language = resolvedLanguage
        if language == .simplifiedChinese, let value = zhHans[key] {
            return value
        }
        return en[key] ?? zhHans[key] ?? key
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), arguments: arguments)
    }

    static var resolvedLanguage: InterfaceLanguage {
        switch FluentaLanguageStore.selectedLanguage {
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        case .system:
            let preferredLanguages = Locale.preferredLanguages.map { $0.lowercased() }
            return preferredLanguages.contains { $0.hasPrefix("zh") } ? .simplifiedChinese : .english
        }
    }

    private static let en: [String: String] = [
        "app.menu.openPopover": "Open Fluenta",
        "app.menu.settings": "Settings",
        "app.menu.quit": "Quit",
        "language.system": "System",
        "settings.window.title": "Fluenta Settings",
        "settings.sidebar.preferences": "Preferences",
        "settings.sidebar.hint": "⌘S Save · ⌘, Open",
        "settings.section.general": "General",
        "settings.section.providers": "Providers",
        "settings.section.promptModes": "Prompt Modes",
        "settings.section.permissions": "Permissions",
        "settings.description.general": "Basic behavior, shortcut, interface language, and generation parameters.",
        "settings.description.providers": "Choose an LLM provider, model, and API key.",
        "settings.description.promptModes": "Manage conversion modes and system prompts shown in the popover.",
        "settings.description.permissions": "Check the macOS permission needed to insert text.",
        "settings.row.language": "Interface Language",
        "settings.help.language": "Use System to follow your macOS language.",
        "settings.row.hotkey": "Hotkey",
        "settings.help.hotkey": "For example: ⌥Space, Option+Space, Cmd+Space.",
        "settings.row.defaultMode": "Default Mode",
        "settings.help.defaultMode": "The mode selected when the popover opens.",
        "settings.row.temperature": "Temperature",
        "settings.help.temperature": "Lower is more stable; higher is more creative.",
        "settings.row.timeout": "Timeout",
        "settings.help.timeout": "Maximum request duration.",
        "settings.seconds": "%d sec",
        "settings.row.provider": "Provider",
        "settings.help.provider": "Current provider.",
        "settings.row.apiKey": "API Key",
        "settings.help.apiKey": "Saved to the provider-specific Keychain item.",
        "settings.row.model": "Model",
        "settings.help.model.default": "Default: %@",
        "settings.mode.untitled": "Untitled mode",
        "settings.mode.visible": "Visible",
        "settings.mode.hidden": "Hidden",
        "settings.mode.pick": "Select a Prompt Mode",
        "settings.row.name": "Name",
        "settings.help.name": "Name shown in the popover.",
        "settings.row.description": "Description",
        "settings.help.description": "What this mode does.",
        "settings.row.systemPrompt": "System Prompt",
        "settings.characters": "%d chars",
        "settings.permission.authorized": "Accessibility authorized",
        "settings.permission.required": "Accessibility permission required",
        "settings.permission.description": "Fluenta needs this permission to paste generated text back into the current input field.",
        "settings.permission.open": "Open System Settings",
        "settings.footer.pending": "Changes apply the next time the popover opens.",
        "settings.save": "Save",
        "settings.saved": "Saved",
        "settings.error.visibleModeRequired": "Keep at least one visible mode.",
        "settings.error.modelRequired": "Model cannot be empty.",
        "settings.error.openAccessibility": "Could not open Accessibility settings.",
        "settings.error.saveFailed": "Save failed: %@",
        "popover.input.placeholder": "Enter text to transform or insert",
        "popover.result.title": "Result",
        "popover.result.editable": "Editable before inserting",
        "popover.mode.picker": "Mode",
        "popover.status.ready": "Ready",
        "popover.status.preview": "Preview",
        "popover.action.transform": "Transform",
        "popover.action.insert": "Insert",
        "popover.action.insertOriginal": "Insert Original",
        "popover.hint.transformInsert": "Transform/Insert",
        "popover.hint.original": "Original",
        "popover.hint.accessibility": "Shortcuts: Enter transforms or inserts, Command Enter inserts original text, Escape goes back or closes",
        "popover.busy.inserting": "Inserting...",
        "popover.busy.transforming": "Transforming...",
        "popover.error.emptyOriginal": "Enter text to insert.",
        "popover.error.missingTarget": "Could not find the target app to insert text.",
        "popover.error.missingAPIKey": "Configure the %@ API Key in Settings first.",
        "insertion.error.accessibility": "Enable Accessibility permission before inserting text.",
        "insertion.error.activation": "Could not return to the original app. Please try again.",
        "insertion.error.pasteEvent": "Could not send the paste shortcut.",
        "insertion.error.clipboardRestore": "Inserted text, but failed to restore the clipboard.",
        "error.emptySource": "Enter text to transform.",
        "error.emptyResponse": "The model returned an empty response.",
        "error.timeout": "Request timed out. Please try again.",
        "error.provider.urlInvalid": "%@ request failed: invalid URL",
        "error.provider.httpUnknown": "%@ request failed: HTTP unknown",
        "error.provider.prefix": "%@ request failed: %@",
        "hotkey.error.unsupported": "Unsupported hotkey “%@”. Supported: ⌥Space, Option+Space, Alt+Space, ⌘Space, Command+Space, Cmd+Space.",
        "hotkey.error.registrationFailed": "Hotkey registration failed (%d).",
        "prompt.auto.description": "Automatically choose a conversion mode based on the input language",
        "prompt.chineseToEnglish.description": "Translate Chinese meaning into natural English",
        "prompt.polishEnglish.description": "Polish English, fixing grammar and wording",
        "prompt.custom.description": "Use your custom prompt"
    ]

    private static let zhHans: [String: String] = [
        "app.menu.openPopover": "打开 Fluenta",
        "app.menu.settings": "设置",
        "app.menu.quit": "退出",
        "language.system": "跟随系统",
        "settings.window.title": "Fluenta 设置",
        "settings.sidebar.preferences": "偏好设置",
        "settings.sidebar.hint": "⌘S 保存 · ⌘, 打开",
        "settings.section.general": "通用",
        "settings.section.providers": "模型服务商",
        "settings.section.promptModes": "Prompt 模式",
        "settings.section.permissions": "权限",
        "settings.description.general": "基础行为、快捷键、界面语言和生成参数。",
        "settings.description.providers": "选择 LLM 服务商、模型和对应的 API Key。",
        "settings.description.promptModes": "管理浮窗中的转换模式和系统提示词。",
        "settings.description.permissions": "检查插入文本所需的 macOS 权限。",
        "settings.row.language": "界面语言",
        "settings.help.language": "选择 System 时跟随 macOS 语言。",
        "settings.row.hotkey": "快捷键",
        "settings.help.hotkey": "例如 ⌥Space、Option+Space、Cmd+Space。",
        "settings.row.defaultMode": "默认模式",
        "settings.help.defaultMode": "浮窗打开时默认选中的模式。",
        "settings.row.temperature": "Temperature",
        "settings.help.temperature": "低值更稳定，高值更发散。",
        "settings.row.timeout": "Timeout",
        "settings.help.timeout": "请求最长等待时间。",
        "settings.seconds": "%d 秒",
        "settings.row.provider": "Provider",
        "settings.help.provider": "当前服务商。",
        "settings.row.apiKey": "API Key",
        "settings.help.apiKey": "保存到对应 provider 的 Keychain item。",
        "settings.row.model": "Model",
        "settings.help.model.default": "默认：%@",
        "settings.mode.untitled": "未命名模式",
        "settings.mode.visible": "Visible",
        "settings.mode.hidden": "Hidden",
        "settings.mode.pick": "选择一个 Prompt Mode",
        "settings.row.name": "Name",
        "settings.help.name": "浮窗中显示的名称。",
        "settings.row.description": "Description",
        "settings.help.description": "模式用途说明。",
        "settings.row.systemPrompt": "System Prompt",
        "settings.characters": "%d 字符",
        "settings.permission.authorized": "Accessibility 已授权",
        "settings.permission.required": "需要 Accessibility 权限",
        "settings.permission.description": "Fluenta 需要该权限，才能把生成文本粘贴回当前输入框。",
        "settings.permission.open": "打开系统权限设置",
        "settings.footer.pending": "更改会在保存后应用到下一次浮窗打开。",
        "settings.save": "保存",
        "settings.saved": "已保存",
        "settings.error.visibleModeRequired": "至少需要保留一个可见模式。",
        "settings.error.modelRequired": "Model 不能为空。",
        "settings.error.openAccessibility": "无法打开辅助功能设置。",
        "settings.error.saveFailed": "保存失败：%@",
        "popover.input.placeholder": "输入要转换或插入的文本",
        "popover.result.title": "结果",
        "popover.result.editable": "可编辑后插入",
        "popover.mode.picker": "模式",
        "popover.status.ready": "Ready",
        "popover.status.preview": "Preview",
        "popover.action.transform": "转换",
        "popover.action.insert": "插入",
        "popover.action.insertOriginal": "插入原文",
        "popover.hint.transformInsert": "转换/插入",
        "popover.hint.original": "原文",
        "popover.hint.accessibility": "快捷键：Enter 转换或插入，Command Enter 插入原文，Escape 返回或关闭",
        "popover.busy.inserting": "正在插入...",
        "popover.busy.transforming": "正在转换...",
        "popover.error.emptyOriginal": "请输入要插入的文本。",
        "popover.error.missingTarget": "找不到要插入文本的目标应用。",
        "popover.error.missingAPIKey": "请先在设置中配置 %@ API Key。",
        "insertion.error.accessibility": "需要开启辅助功能权限后才能插入文本。",
        "insertion.error.activation": "无法切回原应用，请重试。",
        "insertion.error.pasteEvent": "无法发送粘贴快捷键。",
        "insertion.error.clipboardRestore": "插入后恢复剪贴板失败。",
        "error.emptySource": "请输入要转换的文本",
        "error.emptyResponse": "模型返回了空内容",
        "error.timeout": "请求超时，请稍后重试",
        "error.provider.urlInvalid": "%@ 请求失败：URL 无效",
        "error.provider.httpUnknown": "%@ 请求失败：HTTP unknown",
        "error.provider.prefix": "%@ 请求失败：%@",
        "hotkey.error.unsupported": "暂不支持快捷键“%@”。目前支持 ⌥Space、Option+Space、Alt+Space、⌘Space、Command+Space、Cmd+Space。",
        "hotkey.error.registrationFailed": "快捷键注册失败（%d）。",
        "prompt.auto.description": "根据输入语言自动选择转换模式",
        "prompt.chineseToEnglish.description": "把中文原意翻译成自然英文",
        "prompt.polishEnglish.description": "润色英文，修正语法和表达",
        "prompt.custom.description": "使用用户自定义 prompt"
    ]
}

extension Notification.Name {
    static let fluentaLanguageDidChange = Notification.Name("FluentaLanguageDidChange")
}

extension PromptMode {
    var localizedName: String {
        switch id {
        case PromptMode.autoID, PromptMode.chineseToEnglishID, PromptMode.polishEnglishID, PromptMode.customPromptID:
            name
        default:
            name
        }
    }

    var localizedDescription: String {
        switch id {
        case PromptMode.autoID:
            L10n.text("prompt.auto.description")
        case PromptMode.chineseToEnglishID:
            L10n.text("prompt.chineseToEnglish.description")
        case PromptMode.polishEnglishID:
            L10n.text("prompt.polishEnglish.description")
        case PromptMode.customPromptID:
            L10n.text("prompt.custom.description")
        default:
            description
        }
    }
}

extension HotkeyError {
    var userFacingMessage: String {
        switch self {
        case .unsupported(let value):
            L10n.format("hotkey.error.unsupported", value)
        case .registrationFailed(let status):
            L10n.format("hotkey.error.registrationFailed", Int(status))
        }
    }
}
