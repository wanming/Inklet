import AVFoundation
import AppKit
import Combine
import SwiftUI
import InkletCore

/// The first-launch guide: it asks for the permissions Inklet needs one at a time and downloads the
/// built-in model when the person keeps it. It edits the Settings window's own model, so neither saves
/// over the other.
@MainActor
final class WelcomeGuideWindowController: NSWindowController {
    private let model: WelcomeGuideViewModel
    private var languageChangeCancellable: AnyCancellable?

    init(
        settings: SettingsViewModel,
        onAccessibilityTrusted: @escaping () -> Void,
        onFinish: @escaping () -> Void
    ) {
        let model = WelcomeGuideViewModel(settings: settings)
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
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

    func show() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
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
            settings.selectProvider(otherProviderID)
        }
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
        case .welcome, .accessibility, .dictation:
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

    /// Asks for the microphone so the dictation shortcut works the first time it is held.
    func enableDictation() {
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

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.top, 34)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 44)
                .padding(.top, 26)
            Divider().opacity(0.45)
            actionBar
        }
        .frame(width: 560, height: 460)
        .background(InkletTheme.panelBackground)
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
            welcomeStep
        case .accessibility:
            accessibilityStep
        case .writingModel:
            writingModelStep
        case .dictation:
            dictationStep
        case .ready:
            readyStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            PenNibShape()
                .stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                .foregroundStyle(InkletTheme.primary)
                .padding(18)
                .frame(width: 76, height: 76)
                .background(InkletTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
            stepHeader(
                title: L10n.text("welcome.intro.title"),
                message: L10n.format("welcome.intro.message", settings.config.hotkey)
            )
        }
        .padding(.top, 10)
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
                    builtInDownloadStatus
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
                if model.writingChoice == .cloud, !model.isOtherProviderSetUp {
                    SecureField(LLMProviderPreset.openAI.apiKeyPlaceholder, text: $settings.providerAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                }
            }
        }
    }

    @ViewBuilder
    private var builtInDownloadStatus: some View {
        switch model.builtInModelState {
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
        }
    }

    private var readyStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(InkletTheme.primary)
            stepHeader(
                title: L10n.text("welcome.ready.title"),
                message: L10n.format("welcome.ready.message", settings.config.hotkey)
            )
            if model.writingChoice == .builtIn, case .downloading(let fraction) = model.builtInModelState {
                Text(L10n.format("welcome.ready.downloading", model.builtInModel.displayName, fraction * 100))
                    .font(.system(size: 12))
                    .foregroundStyle(InkletTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 10)
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
            Button(model.primaryActionTitle) {
                model.performPrimaryAction()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .frame(height: 64)
    }

    private func stepHeader(systemImage: String? = nil, title: String, message: String) -> some View {
        VStack(alignment: systemImage == nil ? .center : .leading, spacing: 8) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(InkletTheme.primary)
                }
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(InkletTheme.textPrimary)
            }
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(InkletTheme.textSecondary)
                .multilineTextAlignment(systemImage == nil ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: systemImage == nil ? .center : .leading)
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
                .stroke(isSelected ? InkletTheme.primary.opacity(0.6) : InkletTheme.subtleBorder)
        }
    }
}
