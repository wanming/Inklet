import CryptoKit
import Foundation

/// Downloads a built-in model into a `.partial` file, resumes an interrupted download with an
/// HTTP range request, and only moves the file into place once its size and SHA-256 match.
public final class BuiltInModelDownloader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    public typealias ProgressHandler = @Sendable (_ receivedBytes: Int64, _ totalBytes: Int64) -> Void

    private let lock = NSLock()
    private var fileHandle: FileHandle?
    private var receivedBytes: Int64 = 0
    private var expectedBytes: Int64 = 0
    private var lastReportedBytes: Int64 = 0
    private var progressHandler: ProgressHandler?
    private var continuation: CheckedContinuation<Void, Error>?

    public override init() {
        super.init()
    }

    public func download(
        _ model: BuiltInModel,
        into store: BuiltInModelStore,
        fileManager: FileManager = .default,
        progress: @escaping ProgressHandler
    ) async throws {
        try fileManager.createDirectory(at: store.directoryURL, withIntermediateDirectories: true)
        let partialURL = store.partialFileURL(for: model)
        var resumeOffset = (try? fileManager.attributesOfItem(atPath: partialURL.path)[.size] as? NSNumber)?
            .int64Value ?? 0
        if resumeOffset > model.sizeBytes {
            try fileManager.removeItem(at: partialURL)
            resumeOffset = 0
        }
        if resumeOffset < model.sizeBytes {
            try await fetch(model, to: partialURL, resumeOffset: resumeOffset, fileManager: fileManager, progress: progress)
        } else {
            progress(model.sizeBytes, model.sizeBytes)
        }
        try Task.checkCancellation()
        try Self.verify(fileAt: partialURL, matches: model)

        let finalURL = store.fileURL(for: model)
        if fileManager.fileExists(atPath: finalURL.path) {
            try fileManager.removeItem(at: finalURL)
        }
        try fileManager.moveItem(at: partialURL, to: finalURL)
    }

    static func verify(fileAt url: URL, matches model: BuiltInModel) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var size: Int64 = 0
        while true {
            try Task.checkCancellation()
            let chunk = try handle.read(upToCount: 8 * 1_048_576) ?? Data()
            if chunk.isEmpty {
                break
            }
            size += Int64(chunk.count)
            hasher.update(data: chunk)
        }
        guard size == model.sizeBytes else {
            throw LocalModelError.downloadIncomplete
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == model.sha256 else {
            try? FileManager.default.removeItem(at: url)
            throw LocalModelError.checksumMismatch
        }
    }

    private func fetch(
        _ model: BuiltInModel,
        to partialURL: URL,
        resumeOffset: Int64,
        fileManager: FileManager,
        progress: @escaping ProgressHandler
    ) async throws {
        if !fileManager.fileExists(atPath: partialURL.path) {
            fileManager.createFile(atPath: partialURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: partialURL)
        try handle.seek(toOffset: UInt64(resumeOffset))

        var request = URLRequest(url: model.downloadURL)
        if resumeOffset > 0 {
            request.setValue("bytes=\(resumeOffset)-", forHTTPHeaderField: "Range")
        }

        lock.withLock {
            fileHandle = handle
            receivedBytes = resumeOffset
            lastReportedBytes = resumeOffset
            expectedBytes = model.sizeBytes
            progressHandler = progress
        }
        progress(resumeOffset, model.sizeBytes)

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let task = session.dataTask(with: request)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.withLock { self.continuation = continuation }
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }

    private func finish(with error: Error?) {
        let (continuation, handle) = lock.withLock { () -> (CheckedContinuation<Void, Error>?, FileHandle?) in
            let pending = (self.continuation, fileHandle)
            self.continuation = nil
            fileHandle = nil
            progressHandler = nil
            return pending
        }
        try? handle?.close()
        if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
    }

    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch statusCode {
        case 206:
            completionHandler(.allow)
        case 200:
            // The server ignored the range request, so start the file over.
            lock.withLock {
                try? fileHandle?.truncate(atOffset: 0)
                receivedBytes = 0
                lastReportedBytes = 0
            }
            completionHandler(.allow)
        default:
            completionHandler(.cancel)
            finish(with: LocalModelError.downloadFailed(statusCode: statusCode))
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let update = lock.withLock { () -> (ProgressHandler?, Int64, Int64, Error?) in
            do {
                try fileHandle?.write(contentsOf: data)
            } catch {
                return (nil, 0, 0, error)
            }
            receivedBytes += Int64(data.count)
            // Report about every 0.2% so a multi-gigabyte download does not flood the main actor.
            guard receivedBytes - lastReportedBytes >= max(expectedBytes / 500, 1) || receivedBytes >= expectedBytes else {
                return (nil, receivedBytes, expectedBytes, nil)
            }
            lastReportedBytes = receivedBytes
            return (progressHandler, receivedBytes, expectedBytes, nil)
        }
        if let error = update.3 {
            dataTask.cancel()
            finish(with: error)
            return
        }
        update.0?(update.1, update.2)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let urlError = error as? URLError, urlError.code == .cancelled {
            finish(with: CancellationError())
        } else {
            finish(with: error)
        }
    }
}
