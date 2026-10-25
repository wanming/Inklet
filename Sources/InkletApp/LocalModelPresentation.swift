import Foundation
import InkletCore

extension LLMProviderPreset {
    var localizedName: String {
        switch id {
        case LLMProviderPreset.customOpenAICompatible.id:
            L10n.text("settings.provider.customOpenAICompatible")
        case LLMProviderPreset.builtIn.id:
            L10n.text("settings.provider.builtInShort")
        default:
            name
        }
    }

    /// The provider picker has room to say where the built-in model runs; the popover header does not.
    var localizedPickerName: String {
        isBuiltIn ? L10n.text("settings.provider.builtIn") : localizedName
    }

    /// The model name people recognize, for the built-in models that are stored under a short ID.
    func displayModelName(_ modelID: String) -> String {
        guard isBuiltIn, let model = BuiltInModel.model(id: modelID) else {
            return modelID
        }
        return model.displayName
    }
}

extension LocalModelError {
    var userFacingMessage: String {
        switch self {
        case .serverUnreachable(let providerName):
            L10n.format("error.localModel.serverUnreachable", providerName)
        case .engineMissing:
            L10n.text("error.localModel.engineMissing")
        case .unknownModel:
            L10n.text("error.localModel.unknownModel")
        case .modelNotInstalled(let modelName):
            L10n.format("error.localModel.notInstalled", modelName)
        case .engineFailedToStart:
            L10n.text("error.localModel.engineFailed")
        case .downloadFailed(let statusCode):
            L10n.format("error.localModel.downloadFailed", statusCode)
        case .downloadIncomplete:
            L10n.text("error.localModel.downloadIncomplete")
        case .checksumMismatch:
            L10n.text("error.localModel.checksumMismatch")
        }
    }
}

enum BuiltInModelDownloadState: Equatable {
    case notDownloaded
    case downloading(fraction: Double)
    case verifying
    case ready
    case failed(message: String)
}

enum LocalServerStatus: Equatable {
    case checking
    case connected(modelCount: Int)
    case unreachable
}

extension BuiltInModel {
    var localizedDownloadSize: String {
        L10n.format("settings.localModel.size", Double(sizeBytes) / 1_000_000_000)
    }
}
