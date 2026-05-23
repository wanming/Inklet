import Foundation
import InkletCore

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case korean
    case spanish
    case french
    case german
    case portuguese
    case italian

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .portuguese: "Português"
        case .italian: "Italiano"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .system: L10n.text("language.system")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .portuguese: "Português"
        case .italian: "Italiano"
        }
    }
}

enum InkletLanguageStore {
    private static let key = "InkletInterfaceLanguage"

    static var selectedLanguage: InterfaceLanguage {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: key) else {
                return .english
            }
            return InterfaceLanguage(rawValue: rawValue) ?? .english
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            NotificationCenter.default.post(name: .inkletLanguageDidChange, object: nil)
        }
    }
}

enum L10n {
    static func text(_ key: String) -> String {
        let language = resolvedLanguage
        if let value = localizedOverrides[language]?[key] {
            return value
        }
        return en[key] ?? zhHans[key] ?? key
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), arguments: arguments)
    }

    static var resolvedLanguage: InterfaceLanguage {
        switch InkletLanguageStore.selectedLanguage {
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        case .traditionalChinese:
            return .traditionalChinese
        case .japanese:
            return .japanese
        case .korean:
            return .korean
        case .spanish:
            return .spanish
        case .french:
            return .french
        case .german:
            return .german
        case .portuguese:
            return .portuguese
        case .italian:
            return .italian
        case .system:
            let preferredLanguages = Locale.preferredLanguages.map { $0.lowercased() }
            for languageCode in preferredLanguages {
                if languageCode.hasPrefix("zh-hant") || languageCode.hasPrefix("zh-tw") || languageCode.hasPrefix("zh-hk") {
                    return .traditionalChinese
                }
                if languageCode.hasPrefix("zh") { return .simplifiedChinese }
                if languageCode.hasPrefix("ja") { return .japanese }
                if languageCode.hasPrefix("ko") { return .korean }
                if languageCode.hasPrefix("es") { return .spanish }
                if languageCode.hasPrefix("fr") { return .french }
                if languageCode.hasPrefix("de") { return .german }
                if languageCode.hasPrefix("pt") { return .portuguese }
                if languageCode.hasPrefix("it") { return .italian }
            }
            return .english
        }
    }

    private static var localizedOverrides: [InterfaceLanguage: [String: String]] {
        [
            .simplifiedChinese: zhHans,
            .traditionalChinese: zhHant,
            .japanese: ja,
            .korean: ko,
            .spanish: es,
            .french: fr,
            .german: de,
            .portuguese: pt,
            .italian: it
        ]
    }

    private static let en: [String: String] = [
        "app.menu.openPopover": "Open Inklet",
        "app.menu.settings": "Settings",
        "app.menu.quit": "Quit",
        "language.system": "System",
        "settings.window.title": "Inklet Settings",
        "settings.sidebar.preferences": "Preferences",
        "settings.sidebar.hint": "⌘S Save · ⌘, Open",
        "settings.version": "Version %@",
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
        "settings.row.appearance": "Appearance",
        "settings.help.appearance": "Choose Light, Dark, or follow macOS.",
        "appearance.system": "System",
        "appearance.light": "Light",
        "appearance.dark": "Dark",
        "settings.row.hotkey": "Hotkey",
        "settings.help.hotkey": "For example: ⌥Space, Option+Space, Cmd+Space.",
        "settings.hotkey.record": "Record Shortcut",
        "settings.hotkey.recording": "Press shortcut",
        "settings.hotkey.pressKey": " key",
        "settings.row.temperature": "Temperature",
        "settings.help.temperature": "Lower is more stable; higher is more creative.",
        "settings.row.timeout": "Timeout",
        "settings.help.timeout": "Maximum request duration.",
        "settings.seconds": "%d sec",
        "settings.row.provider": "Provider",
        "settings.help.provider": "Current provider.",
        "settings.row.apiKey": "API Key",
        "settings.help.apiKey": "Stored locally on this Mac. Clear the field and save to remove it.",
        "settings.row.endpoint": "Endpoint",
        "settings.help.endpoint": "Full OpenAI-compatible /chat/completions URL.",
        "settings.row.model": "Model",
        "settings.help.model.default": "Default: %@",
        "settings.model.custom": "Custom...",
        "settings.model.refreshing": "Refreshing model list...",
        "settings.model.customized": "Custom model *",
        "settings.mode.untitled": "Untitled mode",
        "settings.mode.add": "Add Mode",
        "settings.mode.newName": "New Mode",
        "settings.mode.newDescription": "Custom transformation mode",
        "settings.mode.visible": "Visible",
        "settings.mode.hidden": "Hidden",
        "settings.mode.pick": "Select a Prompt Mode",
        "settings.mode.visibleInMenu": "Visible in menu",
        "settings.mode.visibleInMenuHelp": "Show this mode in the mode selector.",
        "settings.mode.moveUp": "Move up",
        "settings.mode.moveDown": "Move down",
        "settings.mode.dragToSort": "Drag to reorder",
        "settings.mode.delete": "Delete mode",
        "settings.mode.deleteConfirmTitle": "Delete prompt mode?",
        "settings.mode.deleteConfirmMessage": "Delete “%@”? This cannot be undone.",
        "settings.cancel": "Cancel",
        "settings.provider.configured": "Configured",
        "settings.provider.notConfigured": "Not configured",
        "settings.provider.active": "Active",
        "settings.provider.saved": "Saved",
        "settings.provider.savedLocally": "Saved locally",
        "settings.provider.pendingKey": "New key ready to save",
        "settings.provider.notLoaded": "Saved keys are not shown",
        "settings.provider.pendingSave": "Pending save",
        "settings.row.name": "Name",
        "settings.help.name": "Name shown in the popover.",
        "settings.row.description": "Description",
        "settings.help.description": "What this mode does.",
        "settings.row.systemPrompt": "Prompt",
        "settings.characters": "%d chars",
        "settings.permission.authorized": "Accessibility authorized",
        "settings.permission.required": "Accessibility permission required",
        "settings.permission.accessibility": "Accessibility",
        "settings.permission.description": "Inklet needs this permission to paste generated text back into the current input field.",
        "settings.permission.open": "Open System Settings",
        "settings.privacy.title": "Privacy & Security",
        "settings.privacy.keychain": "• API keys are stored locally on this Mac",
        "settings.privacy.provider": "• Text is sent directly to the selected provider",
        "settings.privacy.clipboard": "• Clipboard contents are restored after insertion",
        "settings.footer.pending": "Changes apply the next time the popover opens.",
        "settings.save": "Save",
        "settings.saved": "Saved",
        "settings.error.visibleModeRequired": "Keep at least one visible mode.",
        "settings.error.promptModeRequired": "Keep at least one prompt mode.",
        "settings.error.modelRequired": "Model cannot be empty.",
        "settings.error.endpointInvalid": "Endpoint must be a valid HTTP URL.",
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
        "popover.hint.newLine": "New Line",
        "popover.hint.mode": "Mode",
        "popover.hint.back": "Back",
        "popover.hint.close": "Close",
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
        "prompt.simpleCorrectEnglish.description": "Rewrite or translate into simple, correct English",
        "prompt.chineseSummary.description": "Summarize any text into concise Simplified Chinese",
        "prompt.translateToEnglish.description": "Rewrite or translate into simple, correct English",
        "prompt.improveWriting.description": "Improve writing while keeping the original language",
        "prompt.makeConcise.description": "Shorten text while keeping the original language and key points",
        "prompt.professionalTone.description": "Rewrite with a clearer, more professional tone",
        "prompt.friendlyReply.description": "Rewrite as a natural, friendly reply",
        "prompt.custom.description": "Use your custom prompt"
    ]

    private static let zhHans: [String: String] = [
        "app.menu.openPopover": "打开 Inklet",
        "app.menu.settings": "设置",
        "app.menu.quit": "退出",
        "language.system": "跟随系统",
        "settings.window.title": "Inklet 设置",
        "settings.sidebar.preferences": "偏好设置",
        "settings.sidebar.hint": "⌘S 保存 · ⌘, 打开",
        "settings.version": "版本 %@",
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
        "settings.row.appearance": "外观",
        "settings.help.appearance": "选择浅色、深色，或跟随 macOS。",
        "appearance.system": "跟随系统",
        "appearance.light": "浅色",
        "appearance.dark": "深色",
        "settings.row.hotkey": "快捷键",
        "settings.help.hotkey": "例如 ⌥Space、Option+Space、Cmd+Space。",
        "settings.hotkey.record": "录制快捷键",
        "settings.hotkey.recording": "按下快捷键",
        "settings.hotkey.pressKey": " 键",
        "settings.row.temperature": "Temperature",
        "settings.help.temperature": "低值更稳定，高值更发散。",
        "settings.row.timeout": "Timeout",
        "settings.help.timeout": "请求最长等待时间。",
        "settings.seconds": "%d 秒",
        "settings.row.provider": "Provider",
        "settings.help.provider": "当前服务商。",
        "settings.row.apiKey": "API Key",
        "settings.help.apiKey": "API Key 会保存在本机；清空输入框并保存即可删除。",
        "settings.row.endpoint": "Endpoint",
        "settings.help.endpoint": "完整的 OpenAI-compatible /chat/completions URL。",
        "settings.row.model": "Model",
        "settings.help.model.default": "默认：%@",
        "settings.model.custom": "自定义...",
        "settings.model.refreshing": "正在刷新模型列表...",
        "settings.model.customized": "自定义 Model *",
        "settings.mode.untitled": "未命名模式",
        "settings.mode.add": "添加模式",
        "settings.mode.newName": "新模式",
        "settings.mode.newDescription": "自定义转换模式",
        "settings.mode.visible": "Visible",
        "settings.mode.hidden": "Hidden",
        "settings.mode.pick": "选择一个 Prompt Mode",
        "settings.mode.visibleInMenu": "在菜单中显示",
        "settings.mode.visibleInMenuHelp": "在浮窗的模式选择器中显示该模式。",
        "settings.mode.moveUp": "上移",
        "settings.mode.moveDown": "下移",
        "settings.mode.dragToSort": "拖动排序",
        "settings.mode.delete": "删除模式",
        "settings.mode.deleteConfirmTitle": "删除这个 Prompt Mode？",
        "settings.mode.deleteConfirmMessage": "确定删除“%@”？此操作无法撤销。",
        "settings.cancel": "取消",
        "settings.provider.configured": "已配置",
        "settings.provider.notConfigured": "未配置",
        "settings.provider.active": "当前启用",
        "settings.provider.saved": "已保存",
        "settings.provider.savedLocally": "已保存到本机",
        "settings.provider.pendingKey": "新 Key 待保存",
        "settings.provider.notLoaded": "已保存的 Key 不会显示",
        "settings.provider.pendingSave": "待保存",
        "settings.row.name": "Name",
        "settings.help.name": "浮窗中显示的名称。",
        "settings.row.description": "Description",
        "settings.help.description": "模式用途说明。",
        "settings.row.systemPrompt": "Prompt",
        "settings.characters": "%d 字符",
        "settings.permission.authorized": "Accessibility 已授权",
        "settings.permission.required": "需要 Accessibility 权限",
        "settings.permission.accessibility": "辅助功能",
        "settings.permission.description": "Inklet 需要该权限，才能把生成文本粘贴回当前输入框。",
        "settings.permission.open": "打开系统权限设置",
        "settings.privacy.title": "隐私与安全",
        "settings.privacy.keychain": "• API Key 保存在本机",
        "settings.privacy.provider": "• 文本会直接发送到当前选择的服务商",
        "settings.privacy.clipboard": "• 插入后会恢复原剪贴板内容",
        "settings.footer.pending": "更改会在保存后应用到下一次浮窗打开。",
        "settings.save": "保存",
        "settings.saved": "已保存",
        "settings.error.visibleModeRequired": "至少需要保留一个可见模式。",
        "settings.error.promptModeRequired": "至少需要保留一个 Prompt 模式。",
        "settings.error.modelRequired": "Model 不能为空。",
        "settings.error.endpointInvalid": "Endpoint 必须是有效的 HTTP URL。",
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
        "popover.hint.newLine": "换行",
        "popover.hint.mode": "模式",
        "popover.hint.back": "返回",
        "popover.hint.close": "关闭",
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
        "prompt.simpleCorrectEnglish.description": "改写或翻译成简单、正确的英文",
        "prompt.chineseSummary.description": "把任意文本总结成简洁中文",
        "prompt.translateToEnglish.description": "改写或翻译成简单、正确的英文",
        "prompt.improveWriting.description": "保持原语言，润色语法、表达和清晰度",
        "prompt.makeConcise.description": "保持原语言，压缩文字并保留重点",
        "prompt.professionalTone.description": "改成更职业、清楚、礼貌的语气",
        "prompt.friendlyReply.description": "改成自然、友好、适合回复的表达",
        "prompt.custom.description": "使用用户自定义 prompt"
    ]

    private static let zhHant: [String: String] = [
        "app.menu.openPopover": "開啟 Inklet",
        "app.menu.settings": "設定",
        "app.menu.quit": "結束",
        "language.system": "跟隨系統",
        "settings.window.title": "Inklet 設定",
        "settings.sidebar.preferences": "偏好設定",
        "settings.sidebar.hint": "⌘S 儲存 · ⌘, 開啟",
        "settings.section.general": "一般",
        "settings.section.providers": "模型服務商",
        "settings.section.promptModes": "Prompt 模式",
        "settings.section.permissions": "權限",
        "settings.description.general": "基本行為、快捷鍵、介面語言和生成參數。",
        "settings.description.providers": "選擇 LLM 服務商、模型和對應的 API Key。",
        "settings.description.promptModes": "管理浮窗中的轉換模式和系統提示詞。",
        "settings.description.permissions": "檢查插入文字所需的 macOS 權限。",
        "settings.row.language": "介面語言",
        "settings.help.language": "選擇 System 時跟隨 macOS 語言。",
        "settings.row.hotkey": "快捷鍵",
        "settings.help.temperature": "數值越低越穩定，越高越發散。",
        "settings.help.timeout": "請求最長等待時間。",
        "settings.seconds": "%d 秒",
        "settings.help.provider": "目前服務商。",
        "settings.help.apiKey": "API Key 會儲存在本機。",
        "settings.help.model.default": "預設：%@",
        "settings.mode.untitled": "未命名模式",
        "settings.mode.pick": "選擇一個 Prompt Mode",
        "settings.help.name": "浮窗中顯示的名稱。",
        "settings.help.description": "模式用途說明。",
        "settings.characters": "%d 字元",
        "settings.permission.authorized": "Accessibility 已授權",
        "settings.permission.required": "需要 Accessibility 權限",
        "settings.permission.description": "Inklet 需要此權限，才能把生成文字貼回目前輸入框。",
        "settings.permission.open": "開啟系統權限設定",
        "settings.footer.pending": "變更會在儲存後套用到下一次浮窗開啟。",
        "settings.save": "儲存",
        "settings.saved": "已儲存",
        "settings.error.visibleModeRequired": "至少需要保留一個可見模式。",
        "settings.error.modelRequired": "Model 不能為空。",
        "settings.error.openAccessibility": "無法開啟輔助使用設定。",
        "settings.error.saveFailed": "儲存失敗：%@",
        "popover.input.placeholder": "輸入要轉換或插入的文字",
        "popover.result.title": "結果",
        "popover.result.editable": "可編輯後插入",
        "popover.mode.picker": "模式",
        "popover.action.transform": "轉換",
        "popover.action.insert": "插入",
        "popover.action.insertOriginal": "插入原文",
        "popover.hint.transformInsert": "轉換/插入",
        "popover.hint.original": "原文",
        "popover.hint.accessibility": "快捷鍵：Enter 轉換或插入，Command Enter 插入原文，Escape 返回或關閉",
        "popover.busy.inserting": "正在插入...",
        "popover.busy.transforming": "正在轉換...",
        "popover.error.emptyOriginal": "請輸入要插入的文字。",
        "popover.error.missingTarget": "找不到要插入文字的目標 App。",
        "popover.error.missingAPIKey": "請先在設定中配置 %@ API Key。",
        "insertion.error.accessibility": "需要開啟 Accessibility 權限後才能插入文字。",
        "insertion.error.activation": "無法切回原 App，請重試。",
        "insertion.error.pasteEvent": "無法送出貼上快捷鍵。",
        "insertion.error.clipboardRestore": "插入後恢復剪貼簿失敗。",
        "error.emptySource": "請輸入要轉換的文字",
        "error.emptyResponse": "模型回傳了空內容",
        "error.timeout": "請求逾時，請稍後重試",
        "error.provider.urlInvalid": "%@ 請求失敗：URL 無效",
        "error.provider.httpUnknown": "%@ 請求失敗：HTTP unknown",
        "error.provider.prefix": "%@ 請求失敗：%@",
        "hotkey.error.unsupported": "暫不支援快捷鍵「%@」。目前支援 ⌥Space、Option+Space、Alt+Space、⌘Space、Command+Space、Cmd+Space。",
        "hotkey.error.registrationFailed": "快捷鍵註冊失敗（%d）。",
        "prompt.auto.description": "根據輸入語言自動選擇轉換模式",
        "prompt.chineseToEnglish.description": "把中文原意翻譯成自然英文",
        "prompt.polishEnglish.description": "潤飾英文，修正文法和表達",
        "prompt.custom.description": "使用你的自訂 prompt"
    ]

    private static let ja: [String: String] = [
        "app.menu.openPopover": "Inklet を開く",
        "app.menu.settings": "設定",
        "app.menu.quit": "終了",
        "language.system": "システムに合わせる",
        "settings.window.title": "Inklet 設定",
        "settings.sidebar.preferences": "環境設定",
        "settings.sidebar.hint": "⌘S 保存 · ⌘, 開く",
        "settings.section.general": "一般",
        "settings.section.providers": "プロバイダー",
        "settings.section.promptModes": "Prompt モード",
        "settings.section.permissions": "権限",
        "settings.description.general": "基本動作、ショートカット、表示言語、生成パラメータ。",
        "settings.description.providers": "LLM プロバイダー、モデル、API キーを選択します。",
        "settings.description.promptModes": "ポップオーバーに表示する変換モードとシステムプロンプトを管理します。",
        "settings.description.permissions": "テキスト挿入に必要な macOS 権限を確認します。",
        "settings.row.language": "表示言語",
        "settings.help.language": "System を選ぶと macOS の言語に従います。",
        "settings.row.hotkey": "ホットキー",
        "settings.help.temperature": "低いほど安定し、高いほど創造的になります。",
        "settings.help.timeout": "リクエストの最大待ち時間。",
        "settings.seconds": "%d 秒",
        "settings.help.provider": "現在のプロバイダー。",
        "settings.help.apiKey": "この Mac にローカル保存されます。",
        "settings.help.model.default": "既定: %@",
        "settings.mode.untitled": "無題のモード",
        "settings.mode.pick": "Prompt Mode を選択",
        "settings.help.name": "ポップオーバーに表示される名前。",
        "settings.help.description": "このモードの用途。",
        "settings.characters": "%d 文字",
        "settings.permission.authorized": "Accessibility は許可済み",
        "settings.permission.required": "Accessibility 権限が必要です",
        "settings.permission.description": "生成したテキストを現在の入力欄へ貼り戻すために、この権限が必要です。",
        "settings.permission.open": "システム設定を開く",
        "settings.footer.pending": "変更は保存後、次回ポップオーバーを開いたときに適用されます。",
        "settings.save": "保存",
        "settings.saved": "保存しました",
        "settings.error.visibleModeRequired": "少なくとも 1 つの表示モードが必要です。",
        "settings.error.modelRequired": "Model は空にできません。",
        "settings.error.openAccessibility": "Accessibility 設定を開けませんでした。",
        "settings.error.saveFailed": "保存に失敗しました: %@",
        "popover.input.placeholder": "変換または挿入するテキストを入力",
        "popover.result.title": "結果",
        "popover.result.editable": "挿入前に編集できます",
        "popover.mode.picker": "モード",
        "popover.action.transform": "変換",
        "popover.action.insert": "挿入",
        "popover.action.insertOriginal": "原文を挿入",
        "popover.hint.transformInsert": "変換/挿入",
        "popover.hint.original": "原文",
        "popover.hint.accessibility": "ショートカット: Enter で変換または挿入、Command Enter で原文を挿入、Escape で戻るまたは閉じる",
        "popover.busy.inserting": "挿入中...",
        "popover.busy.transforming": "変換中...",
        "popover.error.emptyOriginal": "挿入するテキストを入力してください。",
        "popover.error.missingTarget": "テキストを挿入する対象アプリが見つかりません。",
        "popover.error.missingAPIKey": "先に設定で %@ API Key を設定してください。",
        "insertion.error.accessibility": "テキストを挿入するには Accessibility 権限を有効にしてください。",
        "insertion.error.activation": "元のアプリに戻れませんでした。もう一度お試しください。",
        "insertion.error.pasteEvent": "貼り付けショートカットを送信できませんでした。",
        "insertion.error.clipboardRestore": "挿入後にクリップボードを復元できませんでした。",
        "error.emptySource": "変換するテキストを入力してください",
        "error.emptyResponse": "モデルが空の応答を返しました",
        "error.timeout": "リクエストがタイムアウトしました。もう一度お試しください",
        "error.provider.urlInvalid": "%@ のリクエストに失敗しました: URL が無効です",
        "error.provider.httpUnknown": "%@ のリクエストに失敗しました: HTTP unknown",
        "error.provider.prefix": "%@ のリクエストに失敗しました: %@",
        "hotkey.error.unsupported": "未対応のホットキー “%@”。対応: ⌥Space、Option+Space、Alt+Space、⌘Space、Command+Space、Cmd+Space。",
        "hotkey.error.registrationFailed": "ホットキーの登録に失敗しました（%d）。",
        "prompt.auto.description": "入力言語に基づいて変換モードを自動選択",
        "prompt.chineseToEnglish.description": "中国語の意味を自然な英語に翻訳",
        "prompt.polishEnglish.description": "英語を磨き、文法と表現を修正",
        "prompt.custom.description": "カスタム prompt を使用"
    ]

    private static let ko: [String: String] = [
        "app.menu.openPopover": "Inklet 열기",
        "app.menu.settings": "설정",
        "app.menu.quit": "종료",
        "language.system": "시스템 따르기",
        "settings.window.title": "Inklet 설정",
        "settings.sidebar.preferences": "환경설정",
        "settings.sidebar.hint": "⌘S 저장 · ⌘, 열기",
        "settings.section.general": "일반",
        "settings.section.providers": "Provider",
        "settings.section.promptModes": "Prompt Modes",
        "settings.section.permissions": "권한",
        "settings.description.general": "기본 동작, 단축키, 인터페이스 언어, 생성 파라미터.",
        "settings.description.providers": "LLM provider, model, API key를 선택합니다.",
        "settings.description.promptModes": "팝오버에 표시되는 변환 모드와 시스템 프롬프트를 관리합니다.",
        "settings.description.permissions": "텍스트 삽입에 필요한 macOS 권한을 확인합니다.",
        "settings.row.language": "인터페이스 언어",
        "settings.help.language": "System을 선택하면 macOS 언어를 따릅니다.",
        "settings.row.hotkey": "단축키",
        "settings.help.temperature": "낮을수록 안정적이고 높을수록 창의적입니다.",
        "settings.help.timeout": "요청 최대 대기 시간.",
        "settings.seconds": "%d초",
        "settings.help.provider": "현재 provider.",
        "settings.help.apiKey": "이 Mac에 로컬로 저장됩니다.",
        "settings.help.model.default": "기본값: %@",
        "settings.mode.untitled": "이름 없는 모드",
        "settings.mode.pick": "Prompt Mode 선택",
        "settings.help.name": "팝오버에 표시되는 이름.",
        "settings.help.description": "이 모드의 용도.",
        "settings.characters": "%d자",
        "settings.permission.authorized": "Accessibility 권한 허용됨",
        "settings.permission.required": "Accessibility 권한 필요",
        "settings.permission.description": "생성된 텍스트를 현재 입력 필드에 붙여넣으려면 이 권한이 필요합니다.",
        "settings.permission.open": "시스템 설정 열기",
        "settings.footer.pending": "변경 사항은 저장 후 다음 팝오버부터 적용됩니다.",
        "settings.save": "저장",
        "settings.saved": "저장됨",
        "settings.error.visibleModeRequired": "표시되는 모드를 하나 이상 유지하세요.",
        "settings.error.modelRequired": "Model은 비워 둘 수 없습니다.",
        "settings.error.openAccessibility": "Accessibility 설정을 열 수 없습니다.",
        "settings.error.saveFailed": "저장 실패: %@",
        "popover.input.placeholder": "변환하거나 삽입할 텍스트 입력",
        "popover.result.title": "결과",
        "popover.result.editable": "삽입 전 편집 가능",
        "popover.mode.picker": "모드",
        "popover.action.transform": "변환",
        "popover.action.insert": "삽입",
        "popover.action.insertOriginal": "원문 삽입",
        "popover.hint.transformInsert": "변환/삽입",
        "popover.hint.original": "원문",
        "popover.hint.accessibility": "단축키: Enter 변환 또는 삽입, Command Enter 원문 삽입, Escape 뒤로 또는 닫기",
        "popover.busy.inserting": "삽입 중...",
        "popover.busy.transforming": "변환 중...",
        "popover.error.emptyOriginal": "삽입할 텍스트를 입력하세요.",
        "popover.error.missingTarget": "텍스트를 삽입할 대상 앱을 찾을 수 없습니다.",
        "popover.error.missingAPIKey": "먼저 설정에서 %@ API Key를 설정하세요.",
        "insertion.error.accessibility": "텍스트를 삽입하려면 Accessibility 권한을 활성화하세요.",
        "insertion.error.activation": "원래 앱으로 돌아갈 수 없습니다. 다시 시도하세요.",
        "insertion.error.pasteEvent": "붙여넣기 단축키를 보낼 수 없습니다.",
        "insertion.error.clipboardRestore": "삽입 후 클립보드를 복원하지 못했습니다.",
        "error.emptySource": "변환할 텍스트를 입력하세요",
        "error.emptyResponse": "모델이 빈 응답을 반환했습니다",
        "error.timeout": "요청 시간이 초과되었습니다. 다시 시도하세요",
        "error.provider.urlInvalid": "%@ 요청 실패: URL이 유효하지 않습니다",
        "error.provider.httpUnknown": "%@ 요청 실패: HTTP unknown",
        "error.provider.prefix": "%@ 요청 실패: %@",
        "hotkey.error.unsupported": "지원하지 않는 단축키 “%@”. 지원: ⌥Space, Option+Space, Alt+Space, ⌘Space, Command+Space, Cmd+Space.",
        "hotkey.error.registrationFailed": "단축키 등록 실패(%d).",
        "prompt.auto.description": "입력 언어에 따라 변환 모드를 자동 선택",
        "prompt.chineseToEnglish.description": "중국어 의미를 자연스러운 영어로 번역",
        "prompt.polishEnglish.description": "영어를 다듬고 문법과 표현 수정",
        "prompt.custom.description": "사용자 지정 prompt 사용"
    ]

    private static let es: [String: String] = [
        "app.menu.openPopover": "Abrir Inklet",
        "app.menu.settings": "Ajustes",
        "app.menu.quit": "Salir",
        "language.system": "Sistema",
        "settings.window.title": "Ajustes de Inklet",
        "settings.sidebar.preferences": "Preferencias",
        "settings.sidebar.hint": "⌘S Guardar · ⌘, Abrir",
        "settings.section.general": "General",
        "settings.section.providers": "Proveedores",
        "settings.section.promptModes": "Modos de prompt",
        "settings.section.permissions": "Permisos",
        "settings.description.general": "Comportamiento básico, atajo, idioma de la interfaz y parámetros de generación.",
        "settings.description.providers": "Elige proveedor LLM, modelo y API key.",
        "settings.description.promptModes": "Gestiona modos de conversión y prompts del sistema.",
        "settings.description.permissions": "Comprueba el permiso de macOS necesario para insertar texto.",
        "settings.row.language": "Idioma de interfaz",
        "settings.help.language": "System sigue el idioma de macOS.",
        "settings.row.hotkey": "Atajo",
        "settings.help.temperature": "Más bajo es más estable; más alto es más creativo.",
        "settings.help.timeout": "Duración máxima de la solicitud.",
        "settings.seconds": "%d s",
        "settings.help.provider": "Proveedor actual.",
        "settings.help.apiKey": "Se guarda localmente en este Mac.",
        "settings.help.model.default": "Predeterminado: %@",
        "settings.mode.untitled": "Modo sin título",
        "settings.mode.pick": "Selecciona un modo de prompt",
        "settings.help.name": "Nombre mostrado en el panel.",
        "settings.help.description": "Qué hace este modo.",
        "settings.characters": "%d caracteres",
        "settings.permission.authorized": "Accessibility autorizado",
        "settings.permission.required": "Se requiere permiso de Accessibility",
        "settings.permission.description": "Inklet necesita este permiso para pegar el texto generado en el campo actual.",
        "settings.permission.open": "Abrir ajustes del sistema",
        "settings.footer.pending": "Los cambios se aplican la próxima vez que abras el panel.",
        "settings.save": "Guardar",
        "settings.saved": "Guardado",
        "settings.error.visibleModeRequired": "Mantén al menos un modo visible.",
        "settings.error.modelRequired": "Model no puede estar vacío.",
        "settings.error.openAccessibility": "No se pudo abrir Accessibility.",
        "settings.error.saveFailed": "Error al guardar: %@",
        "popover.input.placeholder": "Escribe texto para transformar o insertar",
        "popover.result.title": "Resultado",
        "popover.result.editable": "Editable antes de insertar",
        "popover.mode.picker": "Modo",
        "popover.action.transform": "Transformar",
        "popover.action.insert": "Insertar",
        "popover.action.insertOriginal": "Insertar original",
        "popover.hint.transformInsert": "Transformar/Insertar",
        "popover.hint.original": "Original",
        "popover.hint.accessibility": "Atajos: Enter transforma o inserta, Command Enter inserta el original, Escape vuelve o cierra",
        "popover.busy.inserting": "Insertando...",
        "popover.busy.transforming": "Transformando...",
        "popover.error.emptyOriginal": "Escribe texto para insertar.",
        "popover.error.missingTarget": "No se encontró la app de destino para insertar texto.",
        "popover.error.missingAPIKey": "Configura la API Key de %@ en Ajustes.",
        "insertion.error.accessibility": "Activa el permiso de Accessibility antes de insertar texto.",
        "insertion.error.activation": "No se pudo volver a la app original. Inténtalo de nuevo.",
        "insertion.error.pasteEvent": "No se pudo enviar el atajo de pegar.",
        "insertion.error.clipboardRestore": "Se insertó el texto, pero no se pudo restaurar el portapapeles.",
        "error.emptySource": "Escribe texto para transformar.",
        "error.emptyResponse": "El modelo devolvió una respuesta vacía.",
        "error.timeout": "La solicitud agotó el tiempo. Inténtalo de nuevo.",
        "error.provider.urlInvalid": "La solicitud a %@ falló: URL no válida",
        "error.provider.httpUnknown": "La solicitud a %@ falló: HTTP unknown",
        "error.provider.prefix": "La solicitud a %@ falló: %@",
        "hotkey.error.unsupported": "Atajo no compatible “%@”. Compatibles: ⌥Space, Option+Space, Alt+Space, ⌘Space, Command+Space, Cmd+Space.",
        "hotkey.error.registrationFailed": "Error al registrar el atajo (%d).",
        "prompt.auto.description": "Elige automáticamente el modo según el idioma de entrada",
        "prompt.chineseToEnglish.description": "Traduce chino a inglés natural",
        "prompt.polishEnglish.description": "Mejora el inglés y corrige gramática y estilo",
        "prompt.custom.description": "Usa tu prompt personalizado"
    ]

    private static let fr: [String: String] = [
        "app.menu.openPopover": "Ouvrir Inklet",
        "app.menu.settings": "Réglages",
        "app.menu.quit": "Quitter",
        "language.system": "Système",
        "settings.window.title": "Réglages de Inklet",
        "settings.sidebar.preferences": "Préférences",
        "settings.sidebar.hint": "⌘S Enregistrer · ⌘, Ouvrir",
        "settings.section.general": "Général",
        "settings.section.providers": "Fournisseurs",
        "settings.section.promptModes": "Modes de prompt",
        "settings.section.permissions": "Autorisations",
        "settings.description.general": "Comportement, raccourci, langue d’interface et paramètres de génération.",
        "settings.description.providers": "Choisissez un fournisseur LLM, un modèle et une clé API.",
        "settings.description.promptModes": "Gérez les modes de conversion et les prompts système.",
        "settings.description.permissions": "Vérifiez l’autorisation macOS nécessaire pour insérer du texte.",
        "settings.row.language": "Langue de l’interface",
        "settings.help.language": "System suit la langue de macOS.",
        "settings.row.hotkey": "Raccourci",
        "settings.help.temperature": "Plus bas est plus stable; plus haut est plus créatif.",
        "settings.help.timeout": "Durée maximale de la requête.",
        "settings.seconds": "%d s",
        "settings.help.provider": "Fournisseur actuel.",
        "settings.help.apiKey": "Enregistrée localement sur ce Mac.",
        "settings.help.model.default": "Par défaut : %@",
        "settings.mode.untitled": "Mode sans titre",
        "settings.mode.pick": "Sélectionnez un mode de prompt",
        "settings.help.name": "Nom affiché dans le panneau.",
        "settings.help.description": "Rôle de ce mode.",
        "settings.characters": "%d caractères",
        "settings.permission.authorized": "Accessibility autorisé",
        "settings.permission.required": "Autorisation Accessibility requise",
        "settings.permission.description": "Inklet a besoin de cette autorisation pour coller le texte généré dans le champ actif.",
        "settings.permission.open": "Ouvrir les réglages système",
        "settings.footer.pending": "Les changements s’appliquent à la prochaine ouverture du panneau.",
        "settings.save": "Enregistrer",
        "settings.saved": "Enregistré",
        "settings.error.visibleModeRequired": "Conservez au moins un mode visible.",
        "settings.error.modelRequired": "Model ne peut pas être vide.",
        "settings.error.openAccessibility": "Impossible d’ouvrir les réglages Accessibility.",
        "settings.error.saveFailed": "Échec de l’enregistrement : %@",
        "popover.input.placeholder": "Saisissez le texte à transformer ou insérer",
        "popover.result.title": "Résultat",
        "popover.result.editable": "Modifiable avant insertion",
        "popover.mode.picker": "Mode",
        "popover.action.transform": "Transformer",
        "popover.action.insert": "Insérer",
        "popover.action.insertOriginal": "Insérer l’original",
        "popover.hint.transformInsert": "Transformer/Insérer",
        "popover.hint.original": "Original",
        "popover.hint.accessibility": "Raccourcis : Enter transforme ou insère, Command Enter insère l’original, Escape revient ou ferme",
        "popover.busy.inserting": "Insertion...",
        "popover.busy.transforming": "Transformation...",
        "popover.error.emptyOriginal": "Saisissez le texte à insérer.",
        "popover.error.missingTarget": "Impossible de trouver l’app cible pour insérer le texte.",
        "popover.error.missingAPIKey": "Configurez la clé API %@ dans les réglages.",
        "insertion.error.accessibility": "Activez l’autorisation Accessibility avant d’insérer du texte.",
        "insertion.error.activation": "Impossible de revenir à l’app d’origine. Réessayez.",
        "insertion.error.pasteEvent": "Impossible d’envoyer le raccourci Coller.",
        "insertion.error.clipboardRestore": "Texte inséré, mais restauration du presse-papiers impossible.",
        "error.emptySource": "Saisissez le texte à transformer.",
        "error.emptyResponse": "Le modèle a renvoyé une réponse vide.",
        "error.timeout": "La requête a expiré. Réessayez.",
        "error.provider.urlInvalid": "La requête %@ a échoué : URL invalide",
        "error.provider.httpUnknown": "La requête %@ a échoué : HTTP unknown",
        "error.provider.prefix": "La requête %@ a échoué : %@",
        "hotkey.error.unsupported": "Raccourci non pris en charge “%@”. Pris en charge : ⌥Space, Option+Space, Alt+Space, ⌘Space, Command+Space, Cmd+Space.",
        "hotkey.error.registrationFailed": "Échec d’enregistrement du raccourci (%d).",
        "prompt.auto.description": "Choisit automatiquement le mode selon la langue d’entrée",
        "prompt.chineseToEnglish.description": "Traduit le chinois en anglais naturel",
        "prompt.polishEnglish.description": "Améliore l’anglais et corrige grammaire et formulation",
        "prompt.custom.description": "Utilise votre prompt personnalisé"
    ]

    private static let de: [String: String] = [
        "app.menu.openPopover": "Inklet öffnen",
        "app.menu.settings": "Einstellungen",
        "app.menu.quit": "Beenden",
        "language.system": "System",
        "settings.window.title": "Inklet Einstellungen",
        "settings.sidebar.preferences": "Einstellungen",
        "settings.sidebar.hint": "⌘S Speichern · ⌘, Öffnen",
        "settings.section.general": "Allgemein",
        "settings.section.providers": "Anbieter",
        "settings.section.promptModes": "Prompt-Modi",
        "settings.section.permissions": "Berechtigungen",
        "settings.description.general": "Grundverhalten, Tastenkürzel, Sprache und Generierungsparameter.",
        "settings.description.providers": "LLM-Anbieter, Modell und API-Key auswählen.",
        "settings.description.promptModes": "Konvertierungsmodi und System-Prompts verwalten.",
        "settings.description.permissions": "macOS-Berechtigung zum Einfügen von Text prüfen.",
        "settings.row.language": "Sprache",
        "settings.help.language": "System folgt der macOS-Sprache.",
        "settings.row.hotkey": "Tastenkürzel",
        "settings.help.temperature": "Niedriger ist stabiler; höher ist kreativer.",
        "settings.help.timeout": "Maximale Dauer der Anfrage.",
        "settings.seconds": "%d s",
        "settings.help.provider": "Aktueller Anbieter.",
        "settings.help.apiKey": "Wird lokal auf diesem Mac gespeichert.",
        "settings.help.model.default": "Standard: %@",
        "settings.mode.untitled": "Unbenannter Modus",
        "settings.mode.pick": "Prompt-Modus auswählen",
        "settings.help.name": "Name im Popover.",
        "settings.help.description": "Was dieser Modus tut.",
        "settings.characters": "%d Zeichen",
        "settings.permission.authorized": "Accessibility autorisiert",
        "settings.permission.required": "Accessibility-Berechtigung erforderlich",
        "settings.permission.description": "Inklet benötigt diese Berechtigung, um generierten Text in das aktuelle Eingabefeld einzufügen.",
        "settings.permission.open": "Systemeinstellungen öffnen",
        "settings.footer.pending": "Änderungen gelten beim nächsten Öffnen des Popovers.",
        "settings.save": "Speichern",
        "settings.saved": "Gespeichert",
        "settings.error.visibleModeRequired": "Mindestens ein sichtbarer Modus ist erforderlich.",
        "settings.error.modelRequired": "Model darf nicht leer sein.",
        "settings.error.openAccessibility": "Accessibility-Einstellungen konnten nicht geöffnet werden.",
        "settings.error.saveFailed": "Speichern fehlgeschlagen: %@",
        "popover.input.placeholder": "Text zum Umwandeln oder Einfügen eingeben",
        "popover.result.title": "Ergebnis",
        "popover.result.editable": "Vor dem Einfügen bearbeitbar",
        "popover.mode.picker": "Modus",
        "popover.action.transform": "Umwandeln",
        "popover.action.insert": "Einfügen",
        "popover.action.insertOriginal": "Original einfügen",
        "popover.hint.transformInsert": "Umwandeln/Einfügen",
        "popover.hint.original": "Original",
        "popover.hint.accessibility": "Kürzel: Enter wandelt um oder fügt ein, Command Enter fügt Original ein, Escape zurück oder schließen",
        "popover.busy.inserting": "Einfügen...",
        "popover.busy.transforming": "Umwandeln...",
        "popover.error.emptyOriginal": "Text zum Einfügen eingeben.",
        "popover.error.missingTarget": "Ziel-App zum Einfügen wurde nicht gefunden.",
        "popover.error.missingAPIKey": "%@ API-Key zuerst in den Einstellungen konfigurieren.",
        "insertion.error.accessibility": "Accessibility-Berechtigung vor dem Einfügen aktivieren.",
        "insertion.error.activation": "Rückkehr zur ursprünglichen App fehlgeschlagen. Bitte erneut versuchen.",
        "insertion.error.pasteEvent": "Einfüge-Kürzel konnte nicht gesendet werden.",
        "insertion.error.clipboardRestore": "Text eingefügt, aber Zwischenablage konnte nicht wiederhergestellt werden.",
        "error.emptySource": "Text zum Umwandeln eingeben.",
        "error.emptyResponse": "Das Modell hat eine leere Antwort zurückgegeben.",
        "error.timeout": "Anfrage abgelaufen. Bitte erneut versuchen.",
        "error.provider.urlInvalid": "%@ Anfrage fehlgeschlagen: ungültige URL",
        "error.provider.httpUnknown": "%@ Anfrage fehlgeschlagen: HTTP unknown",
        "error.provider.prefix": "%@ Anfrage fehlgeschlagen: %@",
        "hotkey.error.unsupported": "Nicht unterstütztes Tastenkürzel “%@”. Unterstützt: ⌥Space, Option+Space, Alt+Space, ⌘Space, Command+Space, Cmd+Space.",
        "hotkey.error.registrationFailed": "Registrierung des Tastenkürzels fehlgeschlagen (%d).",
        "prompt.auto.description": "Wählt den Modus automatisch nach Eingabesprache",
        "prompt.chineseToEnglish.description": "Übersetzt Chinesisch in natürliches Englisch",
        "prompt.polishEnglish.description": "Verbessert Englisch und korrigiert Grammatik und Ausdruck",
        "prompt.custom.description": "Verwendet Ihren eigenen prompt"
    ]

    private static let pt: [String: String] = [
        "app.menu.openPopover": "Abrir Inklet",
        "app.menu.settings": "Ajustes",
        "app.menu.quit": "Sair",
        "language.system": "Sistema",
        "settings.window.title": "Ajustes do Inklet",
        "settings.sidebar.preferences": "Preferências",
        "settings.sidebar.hint": "⌘S Salvar · ⌘, Abrir",
        "settings.section.general": "Geral",
        "settings.section.providers": "Provedores",
        "settings.section.promptModes": "Modos de prompt",
        "settings.section.permissions": "Permissões",
        "settings.description.general": "Comportamento, atalho, idioma da interface e parâmetros de geração.",
        "settings.description.providers": "Escolha provedor LLM, modelo e API key.",
        "settings.description.promptModes": "Gerencie modos de conversão e prompts do sistema.",
        "settings.description.permissions": "Verifique a permissão do macOS necessária para inserir texto.",
        "settings.row.language": "Idioma da interface",
        "settings.help.language": "System segue o idioma do macOS.",
        "settings.row.hotkey": "Atalho",
        "settings.help.temperature": "Mais baixo é mais estável; mais alto é mais criativo.",
        "settings.help.timeout": "Duração máxima da solicitação.",
        "settings.seconds": "%d s",
        "settings.help.provider": "Provedor atual.",
        "settings.help.apiKey": "Salva localmente neste Mac.",
        "settings.help.model.default": "Padrão: %@",
        "settings.mode.untitled": "Modo sem título",
        "settings.mode.pick": "Selecione um modo de prompt",
        "settings.help.name": "Nome mostrado no painel.",
        "settings.help.description": "O que este modo faz.",
        "settings.characters": "%d caracteres",
        "settings.permission.authorized": "Accessibility autorizado",
        "settings.permission.required": "Permissão Accessibility necessária",
        "settings.permission.description": "O Inklet precisa desta permissão para colar o texto gerado no campo atual.",
        "settings.permission.open": "Abrir Ajustes do Sistema",
        "settings.footer.pending": "As alterações se aplicam na próxima vez que o painel abrir.",
        "settings.save": "Salvar",
        "settings.saved": "Salvo",
        "settings.error.visibleModeRequired": "Mantenha pelo menos um modo visível.",
        "settings.error.modelRequired": "Model não pode estar vazio.",
        "settings.error.openAccessibility": "Não foi possível abrir Accessibility.",
        "settings.error.saveFailed": "Falha ao salvar: %@",
        "popover.input.placeholder": "Digite texto para transformar ou inserir",
        "popover.result.title": "Resultado",
        "popover.result.editable": "Editável antes de inserir",
        "popover.mode.picker": "Modo",
        "popover.action.transform": "Transformar",
        "popover.action.insert": "Inserir",
        "popover.action.insertOriginal": "Inserir original",
        "popover.hint.transformInsert": "Transformar/Inserir",
        "popover.hint.original": "Original",
        "popover.hint.accessibility": "Atalhos: Enter transforma ou insere, Command Enter insere o original, Escape volta ou fecha",
        "popover.busy.inserting": "Inserindo...",
        "popover.busy.transforming": "Transformando...",
        "popover.error.emptyOriginal": "Digite texto para inserir.",
        "popover.error.missingTarget": "Não foi possível encontrar o app de destino.",
        "popover.error.missingAPIKey": "Configure a API Key de %@ nos Ajustes.",
        "insertion.error.accessibility": "Ative a permissão Accessibility antes de inserir texto.",
        "insertion.error.activation": "Não foi possível voltar ao app original. Tente novamente.",
        "insertion.error.pasteEvent": "Não foi possível enviar o atalho de colar.",
        "insertion.error.clipboardRestore": "Texto inserido, mas não foi possível restaurar a área de transferência.",
        "error.emptySource": "Digite texto para transformar.",
        "error.emptyResponse": "O modelo retornou uma resposta vazia.",
        "error.timeout": "A solicitação expirou. Tente novamente.",
        "error.provider.urlInvalid": "A solicitação %@ falhou: URL inválida",
        "error.provider.httpUnknown": "A solicitação %@ falhou: HTTP unknown",
        "error.provider.prefix": "A solicitação %@ falhou: %@",
        "hotkey.error.unsupported": "Atalho não suportado “%@”. Suportados: ⌥Space, Option+Space, Alt+Space, ⌘Space, Command+Space, Cmd+Space.",
        "hotkey.error.registrationFailed": "Falha ao registrar atalho (%d).",
        "prompt.auto.description": "Escolhe automaticamente o modo pelo idioma de entrada",
        "prompt.chineseToEnglish.description": "Traduz chinês para inglês natural",
        "prompt.polishEnglish.description": "Melhora o inglês e corrige gramática e expressão",
        "prompt.custom.description": "Usa seu prompt personalizado"
    ]

    private static let it: [String: String] = [
        "app.menu.openPopover": "Apri Inklet",
        "app.menu.settings": "Impostazioni",
        "app.menu.quit": "Esci",
        "language.system": "Sistema",
        "settings.window.title": "Impostazioni Inklet",
        "settings.sidebar.preferences": "Preferenze",
        "settings.sidebar.hint": "⌘S Salva · ⌘, Apri",
        "settings.section.general": "Generale",
        "settings.section.providers": "Provider",
        "settings.section.promptModes": "Modalità prompt",
        "settings.section.permissions": "Permessi",
        "settings.description.general": "Comportamento, scorciatoia, lingua dell’interfaccia e parametri di generazione.",
        "settings.description.providers": "Scegli provider LLM, modello e API key.",
        "settings.description.promptModes": "Gestisci modalità di conversione e prompt di sistema.",
        "settings.description.permissions": "Controlla il permesso macOS necessario per inserire testo.",
        "settings.row.language": "Lingua interfaccia",
        "settings.help.language": "System segue la lingua di macOS.",
        "settings.row.hotkey": "Scorciatoia",
        "settings.help.temperature": "Più basso è più stabile; più alto è più creativo.",
        "settings.help.timeout": "Durata massima della richiesta.",
        "settings.seconds": "%d s",
        "settings.help.provider": "Provider attuale.",
        "settings.help.apiKey": "Salvata localmente su questo Mac.",
        "settings.help.model.default": "Predefinito: %@",
        "settings.mode.untitled": "Modalità senza titolo",
        "settings.mode.pick": "Seleziona una modalità prompt",
        "settings.help.name": "Nome mostrato nel pannello.",
        "settings.help.description": "Cosa fa questa modalità.",
        "settings.characters": "%d caratteri",
        "settings.permission.authorized": "Accessibility autorizzato",
        "settings.permission.required": "Permesso Accessibility richiesto",
        "settings.permission.description": "Inklet ha bisogno di questo permesso per incollare il testo generato nel campo attivo.",
        "settings.permission.open": "Apri Impostazioni di Sistema",
        "settings.footer.pending": "Le modifiche si applicano alla prossima apertura del pannello.",
        "settings.save": "Salva",
        "settings.saved": "Salvato",
        "settings.error.visibleModeRequired": "Mantieni almeno una modalità visibile.",
        "settings.error.modelRequired": "Model non può essere vuoto.",
        "settings.error.openAccessibility": "Impossibile aprire Accessibility.",
        "settings.error.saveFailed": "Salvataggio non riuscito: %@",
        "popover.input.placeholder": "Inserisci testo da trasformare o inserire",
        "popover.result.title": "Risultato",
        "popover.result.editable": "Modificabile prima dell’inserimento",
        "popover.mode.picker": "Modalità",
        "popover.action.transform": "Trasforma",
        "popover.action.insert": "Inserisci",
        "popover.action.insertOriginal": "Inserisci originale",
        "popover.hint.transformInsert": "Trasforma/Inserisci",
        "popover.hint.original": "Originale",
        "popover.hint.accessibility": "Scorciatoie: Enter trasforma o inserisce, Command Enter inserisce l’originale, Escape torna indietro o chiude",
        "popover.busy.inserting": "Inserimento...",
        "popover.busy.transforming": "Trasformazione...",
        "popover.error.emptyOriginal": "Inserisci testo da inserire.",
        "popover.error.missingTarget": "Impossibile trovare l’app di destinazione.",
        "popover.error.missingAPIKey": "Configura la API Key di %@ nelle Impostazioni.",
        "insertion.error.accessibility": "Abilita il permesso Accessibility prima di inserire testo.",
        "insertion.error.activation": "Impossibile tornare all’app originale. Riprova.",
        "insertion.error.pasteEvent": "Impossibile inviare la scorciatoia Incolla.",
        "insertion.error.clipboardRestore": "Testo inserito, ma impossibile ripristinare gli appunti.",
        "error.emptySource": "Inserisci testo da trasformare.",
        "error.emptyResponse": "Il modello ha restituito una risposta vuota.",
        "error.timeout": "La richiesta è scaduta. Riprova.",
        "error.provider.urlInvalid": "Richiesta %@ non riuscita: URL non valido",
        "error.provider.httpUnknown": "Richiesta %@ non riuscita: HTTP unknown",
        "error.provider.prefix": "Richiesta %@ non riuscita: %@",
        "hotkey.error.unsupported": "Scorciatoia non supportata “%@”. Supportate: ⌥Space, Option+Space, Alt+Space, ⌘Space, Command+Space, Cmd+Space.",
        "hotkey.error.registrationFailed": "Registrazione scorciatoia non riuscita (%d).",
        "prompt.auto.description": "Sceglie automaticamente la modalità in base alla lingua di input",
        "prompt.chineseToEnglish.description": "Traduce il cinese in inglese naturale",
        "prompt.polishEnglish.description": "Migliora l’inglese e corregge grammatica ed espressione",
        "prompt.custom.description": "Usa il tuo prompt personalizzato"
    ]
}

extension Notification.Name {
    static let inkletLanguageDidChange = Notification.Name("InkletLanguageDidChange")
}

extension PromptMode {
    var localizedName: String {
        switch id {
        case PromptMode.translateToEnglishID,
             PromptMode.chineseSummaryID,
             PromptMode.improveWritingID,
             PromptMode.makeConciseID,
             PromptMode.professionalToneID,
             PromptMode.friendlyReplyID,
             PromptMode.customPromptID:
            name
        default:
            name
        }
    }

    var localizedDescription: String {
        switch id {
        case PromptMode.translateToEnglishID:
            L10n.text("prompt.simpleCorrectEnglish.description")
        case PromptMode.chineseSummaryID:
            L10n.text("prompt.chineseSummary.description")
        case PromptMode.improveWritingID:
            L10n.text("prompt.improveWriting.description")
        case PromptMode.makeConciseID:
            L10n.text("prompt.makeConcise.description")
        case PromptMode.professionalToneID:
            L10n.text("prompt.professionalTone.description")
        case PromptMode.friendlyReplyID:
            L10n.text("prompt.friendlyReply.description")
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
