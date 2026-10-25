import Combine
import Foundation
import InkletCore

/// Built-in model downloads, shared by the settings window and the writing popover so a download
/// started in one shows its progress in the other.
@MainActor
final class BuiltInModelDownloads: ObservableObject {
    static let shared = BuiltInModelDownloads()

    @Published private(set) var states: [String: BuiltInModelDownloadState]

    let store: BuiltInModelStore
    private var tasks: [String: Task<Void, Never>] = [:]

    init(store: BuiltInModelStore = .current()) {
        self.store = store
        self.states = Dictionary(uniqueKeysWithValues: BuiltInModel.all.map { model in
            (model.id, store.isInstalled(model) ? .ready : .notDownloaded)
        })
    }

    var isDownloading: Bool {
        !tasks.isEmpty
    }

    func isDownloading(_ model: BuiltInModel) -> Bool {
        tasks[model.id] != nil
    }

    func state(of model: BuiltInModel) -> BuiltInModelDownloadState {
        states[model.id] ?? .notDownloaded
    }

    func isInstalled(_ model: BuiltInModel) -> Bool {
        store.isInstalled(model)
    }

    func download(_ model: BuiltInModel) {
        guard tasks[model.id] == nil else { return }
        let store = self.store
        let reportProgress: BuiltInModelDownloader.ProgressHandler = { [weak self] received, total in
            let fraction = total > 0 ? Double(received) / Double(total) : 0
            Task { @MainActor [weak self] in
                self?.updateProgress(model, fraction: fraction)
            }
        }
        tasks[model.id] = Task { [weak self] in
            do {
                try await BuiltInModelDownloader().download(model, into: store, progress: reportProgress)
                self?.finish(model, state: .ready)
            } catch is CancellationError {
                self?.finish(model, state: .notDownloaded)
            } catch let error as LocalModelError {
                self?.finish(model, state: .failed(message: error.userFacingMessage))
            } catch {
                self?.finish(model, state: .failed(message: error.localizedDescription))
            }
        }
        // Set after the task is stored, so observers of `states` already see the download running.
        states[model.id] = .downloading(fraction: 0)
    }

    func cancel(_ model: BuiltInModel) {
        tasks[model.id]?.cancel()
    }

    func cancelAll() {
        tasks.values.forEach { $0.cancel() }
    }

    func waitForAll() async {
        for task in Array(tasks.values) {
            await task.value
        }
    }

    func delete(_ model: BuiltInModel) throws {
        guard tasks[model.id] == nil else { return }
        try store.delete(model)
        states[model.id] = .notDownloaded
    }

    private func updateProgress(_ model: BuiltInModel, fraction: Double) {
        guard tasks[model.id] != nil else { return }
        states[model.id] = fraction >= 1 ? .verifying : .downloading(fraction: fraction)
    }

    private func finish(_ model: BuiltInModel, state: BuiltInModelDownloadState) {
        tasks[model.id] = nil
        // A cancelled download keeps its partial file, so the next download resumes.
        states[model.id] = store.isInstalled(model) ? .ready : state
    }
}
