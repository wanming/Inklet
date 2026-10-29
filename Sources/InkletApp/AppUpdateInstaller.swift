import AppKit
import InkletCore
import Security

enum AppUpdateInstallError: Error {
    case downloadFailed
    case untrustedDiskImage
    case diskImageUnreadable
    case untrustedApp
    case unexpectedApp
}

/// A release that was downloaded, checked and copied next to the installed app, ready to replace it.
struct StagedAppUpdate: Sendable {
    let release: InkletRelease
    let directory: URL

    var appURL: URL {
        directory.appendingPathComponent("Inklet.app", isDirectory: true)
    }
}

/// Downloads a release's `Inklet.dmg` and stages the app inside it once it passes the same checks
/// as a manual install: a notarized disk image, and an app that satisfies the running app's
/// designated requirement, which is also what keeps Accessibility and microphone permissions.
enum AppUpdatePreparer {
    private static let maximumDownloadSize: Int64 = 1_073_741_824

    static func prepare(
        _ release: InkletRelease,
        installedAppURL: URL,
        bundleIdentifier: String
    ) async throws -> StagedAppUpdate {
        // A replacement directory sits on the same volume as the installed app, so the swap is a rename.
        let directory = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: installedAppURL,
            create: true
        )
        let staged = StagedAppUpdate(release: release, directory: directory)
        do {
            let diskImageURL = directory.appendingPathComponent("Inklet.dmg")
            try await download(release.downloadURL, to: diskImageURL)
            try Task.checkCancellation()
            try await stageApp(from: diskImageURL, to: staged.appURL, in: directory)
            try? FileManager.default.removeItem(at: diskImageURL)
            try Task.checkCancellation()
            try verifyStagedApp(
                at: staged.appURL,
                bundleIdentifier: bundleIdentifier,
                buildNumber: release.version.buildNumber
            )
            return staged
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    private static func download(_ url: URL, to destination: URL) async throws {
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        let (downloadedURL, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: downloadedURL) }

        guard let response = response as? HTTPURLResponse,
              response.statusCode == 200,
              response.url?.scheme == "https",
              let size = try downloadedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0,
              Int64(size) <= maximumDownloadSize
        else {
            throw AppUpdateInstallError.downloadFailed
        }
        try FileManager.default.moveItem(at: downloadedURL, to: destination)
    }

    private static func stageApp(from diskImageURL: URL, to appURL: URL, in directory: URL) async throws {
        // Gatekeeper's own check for a downloaded disk image: signed, notarized and not revoked.
        guard try await run("/usr/sbin/spctl", [
            "--assess", "--type", "open", "--context", "context:primary-signature", diskImageURL.path,
        ]) else {
            throw AppUpdateInstallError.untrustedDiskImage
        }

        let mountPoint = directory.appendingPathComponent("Volume", isDirectory: true)
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: false)
        guard try await run("/usr/bin/hdiutil", [
            "attach", diskImageURL.path, "-readonly", "-nobrowse", "-noautoopen", "-mountpoint", mountPoint.path,
        ]) else {
            throw AppUpdateInstallError.diskImageUnreadable
        }

        let copied = (try? await run("/usr/bin/ditto", [
            mountPoint.appendingPathComponent("Inklet.app").path, appURL.path,
        ])) ?? false
        _ = try? await run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"])
        try? FileManager.default.removeItem(at: mountPoint)
        guard copied else {
            throw AppUpdateInstallError.diskImageUnreadable
        }
    }

    private static func verifyStagedApp(at appURL: URL, bundleIdentifier: String, buildNumber: Int) throws {
        guard let requirement = AppCodeSignature.runningAppRequirement(),
              AppCodeSignature.app(at: appURL, satisfies: requirement)
        else {
            throw AppUpdateInstallError.untrustedApp
        }

        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              info["CFBundleIdentifier"] as? String == bundleIdentifier,
              info["CFBundleVersion"] as? String == String(buildNumber)
        else {
            throw AppUpdateInstallError.unexpectedApp
        }
    }

    /// Runs a system tool without blocking a thread and reports whether it succeeded.
    private static func run(_ executablePath: String, _ arguments: [String]) async throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
        return status == 0
    }
}

enum AppCodeSignature {
    /// The running app's designated requirement, or nil when it isn't signed with a team identity,
    /// as in ad hoc development builds.
    static func runningAppRequirement() -> SecRequirement? {
        var code: SecCode?
        guard SecCodeCopySelf(SecCSFlags(), &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, SecCSFlags(), &staticCode) == errSecSuccess,
              let staticCode
        else {
            return nil
        }

        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        ) == errSecSuccess,
              let information = information as? [String: Any],
              information[kSecCodeInfoTeamIdentifier as String] is String
        else {
            return nil
        }

        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(staticCode, SecCSFlags(), &requirement) == errSecSuccess else {
            return nil
        }
        return requirement
    }

    static func app(at url: URL, satisfies requirement: SecRequirement) -> Bool {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
              let staticCode
        else {
            return false
        }
        let flags = SecCSFlags(
            rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate
        )
        return SecStaticCodeCheckValidity(staticCode, flags, requirement) == errSecSuccess
    }
}

/// Downloads, stages and installs updates. Automatic installs wait until the coordinator finds
/// Inklet idle; an install the person asks for from the update notice happens as soon as it's ready.
@MainActor
final class AppUpdateInstaller {
    private enum State {
        case idle
        case preparing(id: UUID, release: InkletRelease, installsWhenReady: Bool, task: Task<Void, Never>)
        case ready(StagedAppUpdate)
        case installing
    }

    private var state = State.idle
    var onStateChange: (@MainActor () -> Void)?
    /// An update is staged and waits for Inklet to be idle.
    var onReadyToInstall: (@MainActor () -> Void)?
    /// An automatic download or check failed, so the update should be announced as usual.
    var onAutomaticPreparationFailure: (@MainActor (InkletRelease) -> Void)?
    /// An install the person asked for failed.
    var onRequestedInstallFailure: (@MainActor (InkletRelease) -> Void)?

    private let isProductionBuild: Bool
    private let bundleURL: URL
    private let bundleIdentifier: String?
    private let currentBuild: Int?
    private let userDefaults: UserDefaults
    private let attempts: AppUpdateInstallAttempts

    init(isProductionBuild: Bool, bundle: Bundle = .main, userDefaults: UserDefaults = .standard) {
        self.isProductionBuild = isProductionBuild
        self.bundleURL = bundle.bundleURL
        self.bundleIdentifier = bundle.bundleIdentifier
        self.currentBuild = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String).flatMap { Int($0) }
        self.userDefaults = userDefaults
        self.attempts = AppUpdateInstallAttempts(userDefaults: userDefaults)
    }

    /// The Settings switch, on unless the person turned it off.
    var isAutomaticInstallEnabled: Bool {
        userDefaults.object(forKey: InkletPreferenceKeys.automaticallyInstallsUpdates) as? Bool ?? true
    }

    var hasReadyUpdate: Bool {
        if case .ready = state { return true }
        return false
    }

    /// True while an install the person asked for is downloading, or while Inklet is about to restart.
    var isInstallingOnRequest: Bool {
        switch state {
        case let .preparing(_, _, installsWhenReady, _): installsWhenReady
        case .installing: true
        case .idle, .ready: false
        }
    }

    func start() {
        if let currentBuild {
            attempts.settle(currentBuild: currentBuild)
        }
    }

    func stop() {
        if case let .preparing(_, _, _, task) = state {
            task.cancel()
            state = .idle
        }
    }

    func canInstall(_ release: InkletRelease) -> Bool {
        guard isProductionBuild,
              bundleIdentifier != nil,
              let currentBuild,
              release.version.buildNumber > currentBuild
        else {
            return false
        }
        return AppUpdateInstallLocation.canReplace(bundleURL: bundleURL)
    }

    /// Starts a background download for an update the daily check found.
    /// Returns false when the person should see the usual update notice instead.
    func prepareAutomatically(_ release: InkletRelease) -> Bool {
        guard isAutomaticInstallEnabled,
              canInstall(release),
              !attempts.didFail(build: release.version.buildNumber)
        else {
            return false
        }

        switch state {
        case .installing:
            return true
        case let .ready(staged) where staged.release.version.buildNumber >= release.version.buildNumber:
            onReadyToInstall?()
            return true
        case let .preparing(_, preparing, _, _) where preparing.version.buildNumber >= release.version.buildNumber:
            return true
        case .idle, .ready, .preparing:
            startPreparing(release, installsWhenReady: false)
            return true
        }
    }

    /// Install and Relaunch from the update notice: installs now when the release is staged,
    /// otherwise downloads it first.
    func installOnRequest(_ release: InkletRelease) {
        switch state {
        case .installing:
            return
        case let .ready(staged) where staged.release.version.buildNumber == release.version.buildNumber:
            install(staged, relaunches: true, isRequested: true)
        case let .preparing(id, preparing, _, task) where preparing.version.buildNumber == release.version.buildNumber:
            state = .preparing(id: id, release: preparing, installsWhenReady: true, task: task)
            onStateChange?()
        case .idle, .ready, .preparing:
            startPreparing(release, installsWhenReady: true)
        }
    }

    /// Installs a staged update and relaunches Inklet. Returns false when nothing is staged.
    @discardableResult
    func installReadyUpdate() -> Bool {
        guard isAutomaticInstallEnabled, case let .ready(staged) = state else { return false }
        return install(staged, relaunches: true, isRequested: false)
    }

    /// When the person quits with an update staged, it's put in place without opening Inklet again.
    func installReadyUpdateOnQuit() {
        guard isAutomaticInstallEnabled, case let .ready(staged) = state else { return }
        install(staged, relaunches: false, isRequested: false)
    }

    private func startPreparing(_ release: InkletRelease, installsWhenReady: Bool) {
        discardPreparedUpdate()
        guard let bundleIdentifier else { return }

        let id = UUID()
        let installedAppURL = bundleURL
        let task = Task { @MainActor [weak self] in
            let result: Result<StagedAppUpdate, Error>
            do {
                result = .success(try await AppUpdatePreparer.prepare(
                    release,
                    installedAppURL: installedAppURL,
                    bundleIdentifier: bundleIdentifier
                ))
            } catch {
                result = .failure(error)
            }
            guard let self else {
                if case let .success(staged) = result {
                    try? FileManager.default.removeItem(at: staged.directory)
                }
                return
            }
            self.finishPreparing(id: id, result: result)
        }
        state = .preparing(id: id, release: release, installsWhenReady: installsWhenReady, task: task)
        onStateChange?()
    }

    private func finishPreparing(id: UUID, result: Result<StagedAppUpdate, Error>) {
        guard case let .preparing(currentID, release, installsWhenReady, _) = state, currentID == id else {
            if case let .success(staged) = result {
                try? FileManager.default.removeItem(at: staged.directory)
            }
            return
        }

        switch result {
        case let .success(staged):
            if installsWhenReady {
                install(staged, relaunches: true, isRequested: true)
            } else {
                state = .ready(staged)
                onStateChange?()
                onReadyToInstall?()
            }
        case .failure:
            state = .idle
            onStateChange?()
            if installsWhenReady {
                onRequestedInstallFailure?(release)
            } else {
                onAutomaticPreparationFailure?(release)
            }
        }
    }

    @discardableResult
    private func install(_ staged: StagedAppUpdate, relaunches: Bool, isRequested: Bool) -> Bool {
        let scriptURL = staged.directory.appendingPathComponent("install.sh")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = AppUpdateSwapScript.arguments(
            scriptPath: scriptURL.path,
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            installedAppURL: bundleURL,
            replacementURL: staged.appURL,
            relaunches: relaunches
        )
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            guard FileManager.default.fileExists(atPath: staged.appURL.path) else {
                throw AppUpdateInstallError.unexpectedApp
            }
            try AppUpdateSwapScript.source.write(to: scriptURL, atomically: true, encoding: .utf8)
            attempts.record(build: staged.release.version.buildNumber)
            try process.run()
        } catch {
            attempts.clear()
            try? FileManager.default.removeItem(at: staged.directory)
            state = .idle
            onStateChange?()
            if isRequested {
                onRequestedInstallFailure?(staged.release)
            }
            return false
        }

        state = .installing
        onStateChange?()
        if relaunches {
            NSApp.terminate(nil)
        }
        return true
    }

    private func discardPreparedUpdate() {
        switch state {
        case let .preparing(_, _, _, task):
            task.cancel()
        case let .ready(staged):
            try? FileManager.default.removeItem(at: staged.directory)
        case .idle, .installing:
            break
        }
        state = .idle
    }
}
