import Foundation

/// Wraps 16-bit little-endian mono PCM in a WAV header, the format llama-server reads from memory.
public enum PCM16WAV {
    public static func wav(fromPCM16 pcm: Data, sampleRate: Int) -> Data {
        var wav = Data()
        wav.reserveCapacity(44 + pcm.count)
        wav.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + pcm.count), to: &wav)
        wav.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16), to: &wav)
        append(UInt16(1), to: &wav) // PCM
        append(UInt16(1), to: &wav) // mono
        append(UInt32(sampleRate), to: &wav)
        append(UInt32(sampleRate * 2), to: &wav)
        append(UInt16(2), to: &wav)
        append(UInt16(16), to: &wav)
        wav.append(contentsOf: Array("data".utf8))
        append(UInt32(pcm.count), to: &wav)
        wav.append(pcm)
        return wav
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}

/// Sends one audio clip to a speech model on the built-in engine and returns what was said.
/// llama-server takes the clip as an `input_audio` part of a chat completion.
public struct BuiltInSpeechRecognizer: Sendable {
    private let connection: BuiltInModelServer.Connection
    private let modelID: String
    private let session: URLSession
    private let writesTraditionalChinese: Bool

    /// Qwen3-ASR writes Mandarin in Simplified characters, including Taiwanese Mandarin, so
    /// `writesTraditionalChinese` converts its Chinese to Traditional characters.
    public init(
        connection: BuiltInModelServer.Connection,
        modelID: String,
        session: URLSession = .shared,
        writesTraditionalChinese: Bool = false
    ) {
        self.connection = connection
        self.modelID = modelID
        self.session = session
        self.writesTraditionalChinese = writesTraditionalChinese
    }

    public func transcribe(wav: Data, timeoutSeconds: TimeInterval) async throws -> String {
        var request = URLRequest(url: connection.chatCompletionsURL, timeoutInterval: timeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(connection.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try Self.requestBody(wav: wav, modelID: modelID)

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(statusCode) else {
            throw RealtimeTranscriptionError.server(
                code: String(statusCode),
                message: String(data: data, encoding: .utf8) ?? ""
            )
        }
        let transcript = try Self.transcript(fromResponse: data)
        return writesTraditionalChinese ? Self.traditionalChinese(transcript) : transcript
    }

    /// Converts Simplified Chinese characters to Traditional and leaves other text as it is.
    public static func traditionalChinese(_ text: String) -> String {
        text.applyingTransform(StringTransform("Hans-Hant"), reverse: false) ?? text
    }

    static func requestBody(wav: Data, modelID: String) throws -> Data {
        let body: [String: Any] = [
            "model": modelID,
            "messages": [[
                "role": "user",
                "content": [[
                    "type": "input_audio",
                    "input_audio": ["data": wav.base64EncodedString(), "format": "wav"]
                ]]
            ]],
            "temperature": 0,
            "max_tokens": 1024,
            "stream": false
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    static func transcript(fromResponse data: Data) throws -> String {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any]
        else {
            throw RealtimeTranscriptionError.invalidMessage
        }
        return transcript(fromModelOutput: message["content"] as? String ?? "")
    }

    /// Qwen3-ASR answers `language Chinese<asr_text>…`, or `language None<asr_text>` for silence.
    static func transcript(fromModelOutput output: String) -> String {
        var text = output
        if let marker = text.range(of: "<asr_text>") {
            text = String(text[marker.upperBound...])
        } else if text.hasPrefix("language ") {
            text = ""
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
