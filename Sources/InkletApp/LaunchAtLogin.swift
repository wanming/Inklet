import AppKit
import ServiceManagement

/// The login item that opens Inklet's own bundle when the person logs in.
protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// Backs the "Open at login" switches. macOS owns the state, so the switch reads it back each time it
/// appears or Inklet becomes active, and follows a change made in System Settings › Login Items.
/// It is off until the person turns it on.
@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?

    private let service: LoginItemService

    init(service: LoginItemService = SMAppService.mainApp) {
        self.service = service
        status = service.status
    }

    /// On while registered, including while macOS waits for approval in Login Items.
    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    var needsApproval: Bool {
        status == .requiresApproval
    }

    /// The note under the switch: a failed change, or the approval macOS still waits for.
    var warning: String? {
        if let errorMessage {
            return L10n.format("settings.launchAtLogin.failed", errorMessage)
        }
        return needsApproval ? L10n.text("settings.launchAtLogin.needsApproval") : nil
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        status = service.status
    }

    /// Reads the state again; a note about an earlier failed change is cleared.
    func refresh() {
        errorMessage = nil
        status = service.status
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
