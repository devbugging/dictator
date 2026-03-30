import Foundation

struct TranscriptionResponse: Codable {
    let text: String
}

struct APIErrorResponse: Codable {
    let error: APIError
    struct APIError: Codable {
        let message: String
    }
}

enum TranscriptionError: LocalizedError {
    case noAPIKey
    case apiError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not configured. Open Settings to add it."
        case .apiError(let message):
            return message
        case .invalidResponse:
            return "Invalid response from API."
        }
    }
}

final class TranscriptionService {

    func transcribe(audioURL: URL, apiKey: String, language: String?) async throws -> String {
        guard !apiKey.isEmpty else { throw TranscriptionError.noAPIKey }

        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        body.appendField(named: "model", value: "gpt-4o-transcribe", boundary: boundary)
        body.appendField(named: "response_format", value: "json", boundary: boundary)

        if let language = language, !language.isEmpty {
            body.appendField(named: "language", value: language, boundary: boundary)
        }

        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw TranscriptionError.apiError(errorResponse.error.message)
            }
            throw TranscriptionError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return result.text
    }
}

private extension Data {
    mutating func appendField(named name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}
