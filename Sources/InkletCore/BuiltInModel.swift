import Foundation

/// A GGUF model the built-in engine can download and run. Files are pinned to a repository
/// revision and checked against their SHA-256 after download.
public struct BuiltInModel: Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var repository: String
    public var revision: String
    public var fileName: String
    public var sizeBytes: Int64
    public var sha256: String
    public var recommendedMemoryGB: Int

    public init(
        id: String,
        displayName: String,
        repository: String,
        revision: String,
        fileName: String,
        sizeBytes: Int64,
        sha256: String,
        recommendedMemoryGB: Int
    ) {
        self.id = id
        self.displayName = displayName
        self.repository = repository
        self.revision = revision
        self.fileName = fileName
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.recommendedMemoryGB = recommendedMemoryGB
    }

    public var downloadURL: URL {
        URL(string: "https://huggingface.co/\(repository)/resolve/\(revision)/\(fileName)")!
    }

    public static let qwen35_4B = BuiltInModel(
        id: "qwen3.5-4b",
        displayName: "Qwen3.5 4B",
        repository: "unsloth/Qwen3.5-4B-GGUF",
        revision: "e87f176479d0855a907a41277aca2f8ee7a09523",
        fileName: "Qwen3.5-4B-Q4_K_M.gguf",
        sizeBytes: 2_740_937_888,
        sha256: "00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4",
        recommendedMemoryGB: 8
    )

    public static let gemma4E4B = BuiltInModel(
        id: "gemma-4-e4b",
        displayName: "Gemma 4 E4B",
        repository: "ggml-org/gemma-4-E4B-it-GGUF",
        revision: "a69f018d7678a2b9f5e705f8903d6fb29b9b25dc",
        fileName: "gemma-4-E4B-it-Q4_0.gguf",
        sizeBytes: 4_590_807_392,
        sha256: "a555b900214b477d8880e7832e0b8925e139b0159640036b09fe472b6f2097f2",
        recommendedMemoryGB: 16
    )

    public static let all: [BuiltInModel] = [.qwen35_4B, .gemma4E4B]

    public static let recommended = qwen35_4B

    public static func model(id: String) -> BuiltInModel? {
        all.first { $0.id == id }
    }

    /// Gemma 4 E4B for Macs with 16 GB or more, Qwen3.5 4B otherwise.
    public static func recommended(forPhysicalMemoryBytes memoryBytes: UInt64) -> BuiltInModel {
        let gigabyte: UInt64 = 1_073_741_824
        return memoryBytes >= UInt64(gemma4E4B.recommendedMemoryGB) * gigabyte ? gemma4E4B : qwen35_4B
    }

    /// The model to select when someone picks the built-in provider: a downloaded model works right
    /// away, so it wins over a recommended one that still needs a download.
    public static func preferred(
        recommended: BuiltInModel,
        isInstalled: (BuiltInModel) -> Bool
    ) -> BuiltInModel {
        if isInstalled(recommended) {
            return recommended
        }
        return all.first(where: isInstalled) ?? recommended
    }
}

/// Where downloaded built-in models live, and which of them are ready to run.
public struct BuiltInModelStore: Sendable {
    public let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public static func current() -> BuiltInModelStore {
        BuiltInModelStore(
            directoryURL: InkletStoragePaths.currentOrLocalDevelopment().applicationSupportRootURL
                .appendingPathComponent("Models", isDirectory: true)
        )
    }

    public func fileURL(for model: BuiltInModel) -> URL {
        directoryURL.appendingPathComponent(model.fileName)
    }

    public func partialFileURL(for model: BuiltInModel) -> URL {
        directoryURL.appendingPathComponent(model.fileName + ".partial")
    }

    /// A file only lands at its final path after its checksum matched, so the size check is enough here.
    public func isInstalled(_ model: BuiltInModel, fileManager: FileManager = .default) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL(for: model).path),
              let size = attributes[.size] as? NSNumber
        else {
            return false
        }
        return size.int64Value == model.sizeBytes
    }

    public func delete(_ model: BuiltInModel, fileManager: FileManager = .default) throws {
        for url in [fileURL(for: model), partialFileURL(for: model)] where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
