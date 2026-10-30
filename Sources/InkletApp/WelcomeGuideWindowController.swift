import AVFoundation
import AppKit
import Combine
import SwiftUI
import InkletCore

/// The first-launch guide: it asks for the permissions Inklet needs one at a time and downloads the
/// built-in model when the person keeps it. It edits the Settings window's own model, so neither saves
/// over the other, and every step starts from the current settings when the guide is opened again.
@MainActor
final class WelcomeGuideWindowController: NSWindowController, NSWindowDelegate {
    private let model: WelcomeGuideViewModel
    /// Called whenever the window closes, by its close button or after the last step.
    var onClose: (() -> Void)?
    private var languageChangeCancellable: AnyCancellable?
    private var hasShownWindow = false

    init(
        settings: SettingsViewModel,
        onAccessibilityTrusted: @escaping () -> Void,
        onFinish: @escaping () -> Void
    ) {
        let model = WelcomeGuideViewModel(settings: settings)
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: WelcomeGuideView(model: model, settings: settings))

        super.init(window: window)
        shouldCascadeWindows = false
        window.delegate = self
        model.onAccessibilityTrusted = { [weak window] in
            onAccessibilityTrusted()
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
        }
        model.onFinish = onFinish
        refreshLocalizedContent()
        languageChangeCancellable = NotificationCenter.default.publisher(for: .inkletLanguageDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLocalizedContent()
            }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Centers the window the first time only; later calls bring it back where the person left it.
    func show() {
        if !hasShownWindow {
            window?.center()
            hasShownWindow = true
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    private func refreshLocalizedContent() {
        window?.title = L10n.text("welcome.window.title")
        guard let hostingView = window?.contentView as? NSHostingView<WelcomeGuideView> else { return }
        hostingView.rootView = WelcomeGuideView(model: model, settings: model.settings)
    }
}

@MainActor
final class WelcomeGuideViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome
        case accessibility
        case writingModel
        case dictation
        case selectionBar
        case ready
    }

    enum WritingChoice {
        case builtIn
        case cloud
    }

    @Published private(set) var step: Step = .welcome
    @Published private(set) var writingChoice: WritingChoice
    @Published private(set) var isAccessibilityTrusted: Bool
    @Published private(set) var microphoneStatus: AVAuthorizationStatus
    /// The cloud provider picked on the model step; it starts as the provider from before the guide.
    @Published private(set) var cloudProviderID: String

    let settings: SettingsViewModel
    /// The provider the person had before the guide, or OpenAI on a new install. Picking it again
    /// switches back to it.
    let otherProviderID: String
    /// An existing user's provider that already works, so the guide offers to keep it as it is.
    let isOtherProviderSetUp: Bool
    var onAccessibilityTrusted: (() -> Void)?
    var onFinish: (() -> Void)?
    private var accessibilityPollTask: Task<Void, Never>?

    init(settings: SettingsViewModel) {
        self.settings = settings
        let currentProvider = settings.selectedProvider
        self.otherProviderID = currentProvider.isBuiltIn ? LLMProviderPreset.openAI.id : currentProvider.id
        self.cloudProviderID = currentProvider.isBuiltIn ? LLMProviderPreset.openAI.id : currentProvider.id
        self.isOtherProviderSetUp = !currentProvider.isBuiltIn
            && (!currentProvider.requiresAPIKey || !settings.providerAPIKey.isEmpty)
        self.writingChoice = settings.isBuiltInEngineAvailable && currentProvider.isBuiltIn
            ? .builtIn
            : .cloud
        self.isAccessibilityTrusted = settings.isAccessibilityTrusted
        self.microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    var otherProviderName: String {
        LLMProviderPreset.preset(id: otherProviderID).localizedPickerName
    }

    /// Cloud providers, plus the person's own local server if that is what they used before.
    var cloudProviderOptions: [LLMProviderPreset] {
        let cloudProviders = settings.cloudProviders
        guard !cloudProviders.contains(where: { $0.id == otherProviderID }) else {
            return cloudProviders
        }
        return [LLMProviderPreset.preset(id: otherProviderID)] + cloudProviders
    }

    /// A provider that already works needs no key; any other one asks for its key.
    var needsCloudAPIKey: Bool {
        let provider = LLMProviderPreset.preset(id: cloudProviderID)
        guard provider.requiresAPIKey else { return false }
        return !(isOtherProviderSetUp && cloudProviderID == otherProviderID)
    }

    var canUseBuiltIn: Bool {
        settings.isBuiltInEngineAvailable
    }

    var builtInModel: BuiltInModel {
        settings.selectedProvider.isBuiltIn ? settings.selectedBuiltInModel : settings.recommendedBuiltInModel
    }

    var builtInModelState: BuiltInModelDownloadState {
        settings.builtInModelState(builtInModel)
    }

    var primaryActionTitle: String {
        switch step {
        case .welcome:
            L10n.text("welcome.action.start")
        case .accessibility:
            isAccessibilityTrusted ? L10n.text("welcome.action.continue") : L10n.text("welcome.action.later")
        case .writingModel:
            needsBuiltInDownload ? L10n.text("welcome.action.downloadAndContinue") : L10n.text("welcome.action.continue")
        case .dictation:
            microphoneStatus == .authorized ? L10n.text("welcome.action.continue") : L10n.text("welcome.action.later")
        case .selectionBar:
            L10n.text("welcome.action.continue")
        case .ready:
            L10n.text("welcome.action.finish")
        }
    }

    private var needsBuiltInDownload: Bool {
        guard writingChoice == .builtIn else { return false }
        switch builtInModelState {
        case .notDownloaded, .failed:
            return true
        case .downloading, .verifying, .ready:
            return false
        }
    }

    func selectWritingChoice(_ choice: WritingChoice) {
        guard choice != writingChoice else { return }
        writingChoice = choice
        // The API key field edits the selected provider's key, so switch providers right away.
        switch choice {
        case .builtIn:
            settings.selectProvider(LLMProviderPreset.builtIn.id)
        case .cloud:
            settings.selectProvider(cloudProviderID)
        }
    }

    func selectCloudProvider(_ providerID: String) {
        cloudProviderID = providerID
        if writingChoice != .cloud {
            writingChoice = .cloud
        }
        settings.selectProvider(providerID)
    }

    /// Applies right away, so the rest of the guide is in the chosen language.
    func selectLanguage(_ language: InterfaceLanguage) {
        guard language != settings.interfaceLanguage else { return }
        settings.interfaceLanguage = language
        _ = settings.flushPendingEdits()
    }

    func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        show(previous)
    }

    func performPrimaryAction() {
        switch step {
        case .writingModel:
            if needsBuiltInDownload {
                settings.downloadBuiltInModel(builtInModel)
            }
            _ = settings.flushPendingEdits()
        case .dictation:
            if microphoneStatus == .authorized {
                downloadDictationModelIfNeeded()
            }
            _ = settings.flushPendingEdits()
        case .welcome, .selectionBar:
            _ = settings.flushPendingEdits()
        case .accessibility:
            break
        case .ready:
            onFinish?()
            return
        }
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        show(next)
    }

    func openAccessibilitySettings() {
        settings.openAccessibilitySettings()
    }

    /// Dictation on this Mac needs its speech model; OpenAI dictation needs only the microphone.
    var usesBuiltInDictation: Bool {
        settings.usesBuiltInDictation
    }

    var dictationModel: BuiltInDictationModel {
        settings.dictationModel
    }

    var dictationModelState: BuiltInModelDownloadState {
        settings.dictationModelState
    }

    /// Asks for the microphone so the dictation shortcut works the first time it is held, and
    /// starts the speech model's download when dictation runs on this Mac.
    func enableDictation() {
        downloadDictationModelIfNeeded()
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                }
            }
        case .denied, .restricted:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        case .authorized:
            break
        @unknown default:
            break
        }
    }

    private func downloadDictationModelIfNeeded() {
        guard usesBuiltInDictation else { return }
        switch dictationModelState {
        case .notDownloaded, .failed:
            settings.downloadDictationModel()
        case .downloading, .verifying, .ready:
            break
        }
    }

    private func show(_ newStep: Step) {
        step = newStep
        accessibilityPollTask?.cancel()
        accessibilityPollTask = nil
        isAccessibilityTrusted = settings.isAccessibilityTrusted
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if newStep == .accessibility, !isAccessibilityTrusted {
            pollAccessibilityTrust()
        }
    }

    /// System Settings grants the permission outside Inklet, so check until it turns on.
    private func pollAccessibilityTrust() {
        accessibilityPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                if self.settings.isAccessibilityTrusted {
                    self.isAccessibilityTrusted = true
                    self.accessibilityPollTask = nil
                    self.onAccessibilityTrusted?()
                    return
                }
            }
        }
    }
}

struct WelcomeGuideView: View {
    @ObservedObject var model: WelcomeGuideViewModel
    @ObservedObject var settings: SettingsViewModel
    @StateObject private var launchAtLogin = LaunchAtLoginController()

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.top, 34)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 44)
                .padding(.top, 26)
            if model.step == .ready, let warning = launchAtLogin.warning {
                launchAtLoginNote(warning)
            }
            actionBar
        }
        .frame(width: 560, height: 520)
        .background(InkletTheme.surface)
        // Picks up an approval given in System Settings › Login Items on the way back.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(WelcomeGuideViewModel.Step.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= model.step.rawValue ? InkletTheme.primary : InkletTheme.subtleBorder)
                    .frame(width: step == model.step ? 22 : 8, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.step)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .welcome:
            WelcomeLanguageStep(model: model, settings: settings)
        case .accessibility:
            accessibilityStep
        case .writingModel:
            writingModelStep
        case .dictation:
            dictationStep
        case .selectionBar:
            WelcomeSelectionStep(model: model, settings: settings)
        case .ready:
            WelcomeReadyStep(model: model, settings: settings)
        }
    }

    private var accessibilityStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepHeader(
                systemImage: "hand.raised",
                title: L10n.text("welcome.accessibility.title"),
                message: L10n.text("welcome.accessibility.message")
            )
            permissionRow(
                isGranted: model.isAccessibilityTrusted,
                grantedText: L10n.text("welcome.permission.granted"),
                pendingText: L10n.text("settings.permission.description"),
                actionTitle: L10n.text("settings.permission.openShort"),
                action: { model.openAccessibilitySettings() }
            )
        }
    }

    private var writingModelStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeader(
                systemImage: "text.badge.star",
                title: L10n.text("welcome.model.title"),
                message: L10n.text("welcome.model.message")
            )
            if model.canUseBuiltIn {
                choiceCard(
                    isSelected: model.writingChoice == .builtIn,
                    title: L10n.format("welcome.model.builtIn.title", model.builtInModel.displayName),
                    detail: L10n.format("welcome.model.builtIn.detail", model.builtInModel.localizedDownloadSize),
                    action: { model.selectWritingChoice(.builtIn) }
                ) {
                    downloadStatus(model.builtInModelState)
                }
            }
            choiceCard(
                isSelected: model.writingChoice == .cloud,
                title: model.isOtherProviderSetUp
                    ? L10n.format("welcome.model.keep.title", model.otherProviderName)
                    : L10n.text("welcome.model.cloud.title"),
                detail: model.isOtherProviderSetUp
                    ? L10n.text("welcome.model.keep.detail")
                    : L10n.text("welcome.model.cloud.detail"),
                action: { model.selectWritingChoice(.cloud) }
            ) {
                if model.writingChoice == .cloud {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("", selection: Binding(
                            get: { model.cloudProviderID },
                            set: { model.selectCloudProvider($0) }
                        )) {
                            ForEach(model.cloudProviderOptions) { preset in
                                Text(preset.localizedPickerName).tag(preset.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 320, alignment: .leading)
                        if model.needsCloudAPIKey {
                            SecureField(settings.selectedProvider.apiKeyPlaceholder, text: $settings.providerAPIKey)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 320)
                        }
                    }
                }
            }
            writingShortcutRow
        }
    }

    /// The shortcut that opens Inklet, set where the writing model is chosen.
    private var writingShortcutRow: some View {
        shortcutRow(
            title: L10n.text("welcome.shortcuts.writing"),
            detail: L10n.text("welcome.shortcuts.writing.detail")
        ) {
            HotkeyRecorderField(hotkey: $settings.config.hotkey)
                .frame(width: 160, height: 30)
        }
    }

    @ViewBuilder
    private func downloadStatus(_ state: BuiltInModelDownloadState) -> some View {
        switch state {
        case .downloading(let fraction):
            HStack(spacing: 10) {
                ProgressView(value: fraction)
                    .frame(maxWidth: 200)
                Text(L10n.format("settings.localModel.downloading", fraction * 100))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(InkletTheme.textSecondary)
            }
        case .verifying:
            Text(L10n.text("settings.localModel.verifying"))
                .font(.system(size: 11))
                .foregroundStyle(InkletTheme.textSecondary)
        case .ready:
            Label(L10n.text("settings.localModel.ready"), systemImage: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(InkletTheme.primary)
        case .failed(let message):
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(InkletTheme.warning)
                .fixedSize(horizontal: false, vertical: true)
        case .notDownloaded:
            EmptyView()
        }
    }

    private var dictationStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepHeader(
                systemImage: "mic",
                title: L10n.text("welcome.dictation.title"),
                message: L10n.format("welcome.dictation.message", settings.config.voiceInput.shortcut.localizedName)
            )
            permissionRow(
                isGranted: model.microphoneStatus == .authorized,
                grantedText: L10n.text("welcome.permission.granted"),
                pendingText: L10n.text("welcome.dictation.pending"),
                actionTitle: L10n.text("welcome.dictation.allow"),
                action: { model.enableDictation() }
            )
            if model.usesBuiltInDictation {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.format(
                        "welcome.dictation.builtIn.detail",
                        model.dictationModel.displayName,
                        model.dictationModel.localizedDownloadSize
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(InkletTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    downloadStatus(model.dictationModelState)
                }
            }
            shortcutRow(
                title: L10n.text("welcome.shortcuts.dictation"),
                detail: L10n.text("welcome.shortcuts.dictation.detail")
            ) {
                Picker("", selection: $settings.config.voiceInput.shortcut) {
                    ForEach(VoiceInputConfig.Shortcut.allCases.filter { $0 != .disabled }) { shortcut in
                        Text(shortcut.localizedName).tag(shortcut)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }
        }
    }

    private func shortcutRow<Control: View>(
        title: String,
        detail: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(InkletTheme.textPrimary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(InkletTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control()
        }
        .padding(14)
        .background(InkletTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: InkletTheme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: InkletTheme.cornerRadius)
                .stroke(InkletTheme.subtleBorder)
        }
    }

    private var actionBar: some View {
        HStack {
            if model.step != .welcome {
                Button(L10n.text("welcome.action.back")) {
                    model.goBack()
                }
                .buttonStyle(.plain)
                .foregroundStyle(InkletTheme.textSecondary)
            }
            Spacer()
            if model.step == .ready {
                // Off until chosen here or in Settings › General; the change applies right away.
                Toggle(L10n.text("welcome.ready.launchAtLogin"), isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .toggleStyle(.checkbox)
                .font(InkletTheme.Typography.control)
                .foregroundStyle(InkletTheme.label)
                .help(L10n.text("settings.help.launchAtLogin"))
                .padding(.trailing, InkletTheme.Spacing.md)
                .onAppear { launchAtLogin.refresh() }
            }
            Button(model.primaryActionTitle) {
                model.performPrimaryAction()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, InkletTheme.Spacing.xl)
        .frame(height: 64)
        .background(InkletTheme.surfaceSunken)
    }

    /// Shown above the action bar while macOS waits for approval in Login Items, or after a change failed,
    /// so a checked box that has not taken effect yet says so without hovering.
    private func launchAtLoginNote(_ warning: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: InkletTheme.Spacing.xs) {
            Label(warning, systemImage: "exclamationmark.triangle")
                .font(InkletTheme.Typography.help)
                .foregroundStyle(InkletTheme.statusWarning)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if launchAtLogin.needsApproval {
                Button {
                    launchAtLogin.openLoginItemsSettings()
                } label: {
                    Label(L10n.text("settings.permission.openShort"), systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(InkletButtonStyle(kind: .secondary, size: .small))
                .fixedSize()
            }
        }
        .padding(.horizontal, InkletTheme.Spacing.xl)
        .padding(.vertical, InkletTheme.Spacing.xs)
    }

    private func stepHeader(systemImage: String? = nil, title: String, message: String) -> some View {
        WelcomeStepHeader(systemImage: systemImage, title: title, message: message)
    }

    private func permissionRow(
        isGranted: Bool,
        grantedText: String,
        pendingText: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 16))
                .foregroundStyle(isGranted ? InkletTheme.success : InkletTheme.textTertiary)
            Text(isGranted ? grantedText : pendingText)
                .font(.system(size: 12))
                .foregroundStyle(InkletTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !isGranted {
                Button(actionTitle, action: action)
                    .controlSize(.regular)
            }
        }
        .padding(14)
        .background(InkletTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: InkletTheme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: InkletTheme.cornerRadius)
                .stroke(InkletTheme.subtleBorder)
        }
    }

    private func choiceCard<Accessory: View>(
        isSelected: Bool,
        title: String,
        detail: String,
        action: @escaping () -> Void,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: action) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? InkletTheme.primary : InkletTheme.textTertiary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(InkletTheme.textPrimary)
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(InkletTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            accessory()
                .padding(.leading, 24)
        }
        .padding(14)
        .background(InkletTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: InkletTheme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: InkletTheme.cornerRadius)
                .stroke(isSelected ? InkletTheme.strokeStrong : InkletTheme.hairline)
        }
    }
}

/// The first step: the three languages Inklet works with. The interface language applies right away,
/// so everything after it reads in that language.
struct WelcomeLanguageStep: View {
    @ObservedObject var model: WelcomeGuideViewModel
    @ObservedObject var settings: SettingsViewModel

    var body: some View {
        VStack(spacing: InkletTheme.Spacing.sm) {
            PenNibShape()
                .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(InkletTheme.primary)
                .padding(11)
                .frame(width: 46, height: 46)
                .background(InkletTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            VStack(spacing: InkletTheme.Spacing.xs) {
                Text(L10n.text("welcome.intro.title"))
                    .font(InkletTheme.Typography.pageTitle)
                    .tracking(-0.2)
                    .foregroundStyle(InkletTheme.label)
                Text(L10n.text("welcome.language.message"))
                    .font(InkletTheme.Typography.body)
                    .foregroundStyle(InkletTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                languageRow(
                    title: L10n.text("welcome.language.interface.title"),
                    detail: L10n.text("welcome.language.interface.detail")
                ) {
                    Picker("", selection: Binding(
                        get: { settings.interfaceLanguage },
                        set: { model.selectLanguage($0) }
                    )) {
                        ForEach(InterfaceLanguage.allCases) { language in
                            Text(language.localizedDisplayName).tag(language)
                        }
                    }
                }
                InkletRowDivider()
                languageRow(
                    title: L10n.text("welcome.language.mine.title"),
                    detail: L10n.text("welcome.language.mine.detail")
                ) {
                    Picker("", selection: $settings.config.selectionActions.translationLanguage) {
                        ForEach(SelectionTranslationLanguage.allCases) { language in
                            Text(language.localizedDisplayName).tag(language)
                        }
                    }
                }
                InkletRowDivider()
                languageRow(
                    title: L10n.text("welcome.language.writing.title"),
                    detail: L10n.text("welcome.language.writing.detail")
                ) {
                    Picker("", selection: $settings.writingLanguage) {
                        ForEach(SelectionTranslationLanguage.writingLanguageCases) { language in
                            Text(language.localizedDisplayName).tag(language)
                        }
                    }
                }
            }
            .inkletCard()
            .padding(.top, InkletTheme.Spacing.xxs)
            HStack(alignment: .firstTextBaseline, spacing: InkletTheme.Spacing.xs) {
                // The Prompt Modes icon in Settings, so the hint points at the same place.
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: InkletTheme.IconSize.small))
                    .foregroundStyle(InkletTheme.secondaryLabel)
                Text(L10n.format("welcome.language.prompts", L10n.text("settings.section.promptModes")))
                    .font(InkletTheme.Typography.help)
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, InkletTheme.Spacing.xxs)
        }
    }

    private func languageRow<Control: View>(
        title: String,
        detail: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: InkletTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(InkletTheme.Typography.control)
                    .foregroundStyle(InkletTheme.label)
                Text(detail)
                    .font(InkletTheme.Typography.help)
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control()
                .labelsHidden()
                .fixedSize()
        }
        .padding(InkletTheme.Spacing.sm)
    }
}

/// The title and message at the top of each step; with an icon it is leading-aligned, without one centered.
struct WelcomeStepHeader: View {
    var systemImage: String?
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: systemImage == nil ? .center : .leading, spacing: 8) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(InkletTheme.primary)
                }
                Text(title)
                    .font(InkletTheme.Typography.pageTitle)
                    .tracking(-0.2)
                    .foregroundStyle(InkletTheme.label)
            }
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(InkletTheme.textSecondary)
                .multilineTextAlignment(systemImage == nil ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: systemImage == nil ? .center : .leading)
    }
}

/// Introduces the bar that appears next to selected text. The preview is the real bar with the
/// person's own buttons, so it matches what they will see.
struct WelcomeSelectionStep: View {
    @ObservedObject var model: WelcomeGuideViewModel
    @ObservedObject var settings: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            WelcomeStepHeader(
                systemImage: SettingsSection.selectionAssistant.icon,
                title: L10n.text("welcome.selection.title"),
                message: L10n.text("welcome.selection.message")
            )
            preview
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: InkletTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.text("welcome.selection.toggle"))
                            .font(InkletTheme.Typography.control)
                            .foregroundStyle(InkletTheme.label)
                        if !model.isAccessibilityTrusted {
                            Text(L10n.text("welcome.selection.needsAccessibility"))
                                .font(InkletTheme.Typography.help)
                                .foregroundStyle(InkletTheme.secondaryLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("", isOn: $settings.config.selectionActions.isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(InkletTheme.Spacing.sm)
            }
            .inkletCard()
            HStack(alignment: .firstTextBaseline, spacing: InkletTheme.Spacing.xs) {
                // The Selection Assistant icon in Settings, so the hint points at the same place.
                Image(systemName: SettingsSection.selectionAssistant.icon)
                    .font(.system(size: InkletTheme.IconSize.small))
                    .foregroundStyle(InkletTheme.secondaryLabel)
                Text(L10n.format("welcome.selection.customize", L10n.text("settings.section.selectionAssistant")))
                    .font(InkletTheme.Typography.help)
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, InkletTheme.Spacing.xxs)
        }
    }

    /// A line of sample text with a selected word, and the bar below it. It only shows; nothing runs.
    private var preview: some View {
        VStack(alignment: .leading, spacing: InkletTheme.Spacing.xs) {
            Text(sampleText)
                .font(InkletTheme.Typography.body)
                .foregroundStyle(InkletTheme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
            SelectionActionView(
                state: .menu(errorMessage: nil, feedback: nil),
                menuItems: SelectionMenuItem.enabledItems(for: settings.config),
                onTranslate: {},
                onPronounce: {},
                onPronounceOriginal: {},
                onPronounceTranslation: {},
                onCopyTranslation: {},
                onRetryTranslation: {}
            )
            .allowsHitTesting(false)
            .opacity(settings.config.selectionActions.isEnabled ? 1 : 0.4)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(InkletTheme.Spacing.md)
        .background(InkletTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: InkletTheme.Radius.card))
        .animation(InkletTheme.Motion.standard, value: settings.config.selectionActions.isEnabled)
    }

    private var sampleText: AttributedString {
        var selected = AttributedString(L10n.text("welcome.selection.sample.selected"))
        selected.swiftUI.foregroundColor = InkletTheme.label
        selected.swiftUI.backgroundColor = InkletTheme.primary.opacity(0.22)
        return AttributedString(L10n.text("welcome.selection.sample.before"))
            + selected
            + AttributedString(L10n.text("welcome.selection.sample.after"))
    }
}

/// The last step: the three ways to use Inklet, each with the shortcut chosen earlier in the guide.
struct WelcomeReadyStep: View {
    @ObservedObject var model: WelcomeGuideViewModel
    @ObservedObject var settings: SettingsViewModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(InkletTheme.primary)
            WelcomeStepHeader(
                title: L10n.text("welcome.ready.title"),
                message: L10n.text("welcome.ready.message")
            )
            VStack(spacing: 0) {
                usageRow(
                    systemImage: "keyboard",
                    title: L10n.text("welcome.ready.writing.title"),
                    detail: L10n.format("welcome.ready.writing.detail", settings.config.hotkey)
                )
                if settings.config.selectionActions.isEnabled {
                    InkletRowDivider()
                    usageRow(
                        systemImage: SettingsSection.selectionAssistant.icon,
                        title: L10n.text("welcome.ready.selection.title"),
                        detail: L10n.text("welcome.ready.selection.detail")
                    )
                }
                if settings.config.voiceInput.isEnabled, model.microphoneStatus == .authorized {
                    InkletRowDivider()
                    usageRow(
                        systemImage: "mic",
                        title: L10n.text("welcome.ready.dictation.title"),
                        detail: L10n.format(
                            "welcome.ready.dictation.detail",
                            settings.config.voiceInput.shortcut.localizedName
                        )
                    )
                }
            }
            .inkletCard()
            if model.writingChoice == .builtIn, case .downloading(let fraction) = model.builtInModelState {
                downloadNote(L10n.format("welcome.ready.downloading", model.builtInModel.displayName, fraction * 100))
            }
            if model.usesBuiltInDictation, case .downloading(let fraction) = model.dictationModelState {
                downloadNote(L10n.format("welcome.ready.downloading", model.dictationModel.displayName, fraction * 100))
            }
        }
    }

    private func usageRow(systemImage: String, title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: InkletTheme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: InkletTheme.IconSize.regular))
                .foregroundStyle(InkletTheme.secondaryLabel)
                .frame(width: InkletTheme.IconSize.regular + 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(InkletTheme.Typography.control)
                    .foregroundStyle(InkletTheme.label)
                Text(detail)
                    .font(InkletTheme.Typography.help)
                    .foregroundStyle(InkletTheme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(InkletTheme.Spacing.sm)
    }

    private func downloadNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(InkletTheme.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
