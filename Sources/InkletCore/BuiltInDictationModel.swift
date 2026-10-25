import Foundation

/// A speech model the built-in engine runs for Live Dictation. llama.cpp needs two files: the
/// language model and its audio encoder (`--mmproj`). Each is a pinned, checksummed
/// `BuiltInModel` record, so the store and downloader handle them like the writing models.
public struct BuiltInDictationModel: Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var weights: BuiltInModel
    public var projector: BuiltInModel

    public init(id: String, displayName: String, weights: BuiltInModel, projector: BuiltInModel) {
        self.id = id
        self.displayName = displayName
        self.weights = weights
        self.projector = projector
    }

    public var files: [BuiltInModel] {
        [weights, projector]
    }

    public var sizeBytes: Int64 {
        files.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Macs with at least this much memory keep the dictation model loaded while dictation is on.
    public static let keepsModelLoadedMemoryGB: UInt64 = 16

    /// Qwen3-ASR 0.6B: Apache 2.0, 30 languages and 22 Chinese dialects, and the most accurate of
    /// the engines we compared on mixed Chinese and English speech.
    public static let qwen3ASR06B = BuiltInDictationModel(
        id: "qwen3-asr-0.6b",
        displayName: "Qwen3-ASR 0.6B",
        weights: BuiltInModel(
            id: "qwen3-asr-0.6b-weights",
            displayName: "Qwen3-ASR 0.6B",
            repository: "ggml-org/Qwen3-ASR-0.6B-GGUF",
            revision: "928ab958557df9aa2ef1c93e0e83c7ad0933fae2",
            fileName: "Qwen3-ASR-0.6B-Q8_0.gguf",
            sizeBytes: 804_749_248,
            sha256: "bca259818b50ca7c4c05e9bdb35a5dc04fa039653a6d6f3f0f331f96f6aa1971",
            recommendedMemoryGB: 8
        ),
        projector: BuiltInModel(
            id: "qwen3-asr-0.6b-projector",
            displayName: "Qwen3-ASR 0.6B audio encoder",
            repository: "ggml-org/Qwen3-ASR-0.6B-GGUF",
            revision: "928ab958557df9aa2ef1c93e0e83c7ad0933fae2",
            fileName: "mmproj-Qwen3-ASR-0.6B-Q8_0.gguf",
            sizeBytes: 214_392_480,
            sha256: "41a342b5e4c514e968cb756de6cd1b7be39eff43c44c57a2ef5fc6522e36603d",
            recommendedMemoryGB: 8
        )
    )

    public static let all: [BuiltInDictationModel] = [.qwen3ASR06B]

    public static let recommended = qwen3ASR06B

    public static func model(id: String) -> BuiltInDictationModel? {
        all.first { $0.id == id }
    }
}

extension BuiltInModelStore {
    public func isInstalled(_ model: BuiltInDictationModel, fileManager: FileManager = .default) -> Bool {
        model.files.allSatisfy { isInstalled($0, fileManager: fileManager) }
    }
}
