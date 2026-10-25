import Darwin
import Foundation

/// Runs the bundled llama.cpp `llama-server` on a private loopback port. The server is started on
/// the first request, restarted when the model changes, and unloads the model from memory after
/// five idle minutes. A random key per launch keeps other local processes from using it.
public actor BuiltInModelServer {
    public struct Connection: Equatable, Sendable {
        public var chatCompletionsURL: URL
        public var apiKey: String
    }

    public static let shared = BuiltInModelServer()
    public static let executableName = "llama-server"
    static let idleUnloadSeconds = 300
    static let contextTokens = 8192

    private struct Running {
        var process: Process
        var modelID: String
        var connection: Connection
    }

    private let store: BuiltInModelStore
    private let executableURL: @Sendable () -> URL?
    private let session: URLSession
    private var running: Running?
    private var starting: Task<Connection, Error>?
    private let processIdentifier = ProcessIdentifierBox()

    public init(
        store: BuiltInModelStore = .current(),
        executableURL: @escaping @Sendable () -> URL? = BuiltInModelServer.bundledExecutableURL,
        session: URLSession = .shared
    ) {
        self.store = store
        self.executableURL = executableURL
        self.session = session
    }

    /// `INKLET_LLAMA_SERVER_PATH` lets `swift run` builds point at a locally built server.
    public static func bundledExecutableURL() -> URL? {
        let fileManager = FileManager.default
        if let overridePath = ProcessInfo.processInfo.environment["INKLET_LLAMA_SERVER_PATH"],
           fileManager.isExecutableFile(atPath: overridePath) {
            return URL(fileURLWithPath: overridePath)
        }
        guard let url = Bundle.main.url(forAuxiliaryExecutable: executableName),
              fileManager.isExecutableFile(atPath: url.path)
        else {
            return nil
        }
        return url
    }

    /// The bundled server is built for Apple silicon only.
    public nonisolated static var isEngineAvailable: Bool {
        #if arch(arm64)
        bundledExecutableURL() != nil
        #else
        false
        #endif
    }

    public func connection(for model: BuiltInModel, startupTimeoutSeconds: TimeInterval) async throws -> Connection {
        if let running, running.modelID == model.id, running.process.isRunning {
            return running.connection
        }
        if let starting {
            let connection = try await starting.value
            if running?.modelID == model.id {
                return connection
            }
        }

        stop()
        let task = Task { try await start(model, startupTimeoutSeconds: startupTimeoutSeconds) }
        starting = task
        defer {
            if starting == task {
                starting = nil
            }
        }
        return try await task.value
    }

    public func stop() {
        running?.process.terminate()
        running = nil
        processIdentifier.set(nil)
    }

    /// Safe to call while the app terminates, when there is no time to hop onto the actor.
    public nonisolated func terminateImmediately() {
        if let pid = processIdentifier.get() {
            kill(pid, SIGTERM)
        }
    }

    private func start(_ model: BuiltInModel, startupTimeoutSeconds: TimeInterval) async throws -> Connection {
        guard let executableURL = executableURL() else {
            throw LocalModelError.engineMissing
        }
        guard store.isInstalled(model) else {
            throw LocalModelError.modelNotInstalled(modelName: model.displayName)
        }

        let port = try Self.availableLoopbackPort()
        let apiKey = UUID().uuidString
        let process = Process()
        process.executableURL = executableURL
        process.arguments = Self.arguments(
            modelPath: store.fileURL(for: model).path,
            modelID: model.id,
            port: port,
            apiKey: apiKey
        )
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw LocalModelError.engineFailedToStart
        }

        let baseURL = URL(string: "http://127.0.0.1:\(port)")!
        let connection = Connection(
            chatCompletionsURL: baseURL.appendingPathComponent("v1/chat/completions"),
            apiKey: apiKey
        )
        running = Running(process: process, modelID: model.id, connection: connection)
        processIdentifier.set(process.processIdentifier)

        do {
            try await waitUntilHealthy(baseURL: baseURL, process: process, timeoutSeconds: startupTimeoutSeconds)
        } catch {
            stop()
            throw error
        }
        return connection
    }

    static func arguments(modelPath: String, modelID: String, port: Int, apiKey: String) -> [String] {
        [
            "--model", modelPath,
            "--alias", modelID,
            "--host", "127.0.0.1",
            "--port", String(port),
            "--api-key", apiKey,
            "--ctx-size", String(contextTokens),
            "--parallel", "1",
            "--reasoning", "off",
            "--sleep-idle-seconds", String(idleUnloadSeconds),
            "--no-webui"
        ]
    }

    private func waitUntilHealthy(baseURL: URL, process: Process, timeoutSeconds: TimeInterval) async throws {
        let healthURL = baseURL.appendingPathComponent("health")
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            try Task.checkCancellation()
            guard process.isRunning else {
                throw LocalModelError.engineFailedToStart
            }
            if let result = try? await session.data(for: URLRequest(url: healthURL, timeoutInterval: 2)),
               (result.1 as? HTTPURLResponse)?.statusCode == 200 {
                return
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw TransformationError.timeout
    }

    static func availableLoopbackPort() throws -> Int {
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            throw LocalModelError.engineFailedToStart
        }
        defer { close(socketDescriptor) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                bind(socketDescriptor, socketAddress, length) == 0
                    && getsockname(socketDescriptor, socketAddress, &length) == 0
            }
        }
        guard bound else {
            throw LocalModelError.engineFailedToStart
        }
        return Int(UInt16(bigEndian: address.sin_port))
    }
}

private final class ProcessIdentifierBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: pid_t?

    func get() -> pid_t? {
        lock.withLock { value }
    }

    func set(_ newValue: pid_t?) {
        lock.withLock { value = newValue }
    }
}

/// Sends writing and translation requests to the built-in engine, starting it when needed.
public struct BuiltInModelProvider: LLMProvider {
    private let server: BuiltInModelServer

    public init(server: BuiltInModelServer = .shared) {
        self.server = server
    }

    public func transform(_ request: TransformationRequest) async throws -> TransformationResult {
        try await chatProvider(for: request).transform(request)
    }

    public func streamTransform(
        _ request: TransformationRequest,
        onPartialOutput: @escaping @Sendable (String) -> Void
    ) async throws -> TransformationResult {
        try await chatProvider(for: request).streamTransform(request, onPartialOutput: onPartialOutput)
    }

    private func chatProvider(for request: TransformationRequest) async throws -> ChatCompletionProvider {
        guard let model = BuiltInModel.model(id: request.model) else {
            throw LocalModelError.unknownModel(request.model)
        }
        let connection = try await server.connection(for: model, startupTimeoutSeconds: request.timeoutSeconds)
        let apiKey = connection.apiKey
        return ChatCompletionProvider(
            name: LLMProviderPreset.builtIn.name,
            apiKeyProvider: { apiKey },
            endpoint: connection.chatCompletionsURL,
            runsLocally: true
        )
    }
}
