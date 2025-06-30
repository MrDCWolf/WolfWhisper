import Foundation

enum TranscriptionError: Error {
    case apiKeyMissing
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
}

struct TranscriptionResponse: Decodable {
    let text: String
}

@MainActor
class TranscriptionService {
    private let keychainService: KeychainService

    init(keychainService: KeychainService) {
        self.keychainService = keychainService
    }

    func transcribe(audioURL: URL) async throws -> String {
        let apiKey = await MainActor.run {
            keychainService.loadApiKey()
        }
        
        guard let apiKey = apiKey else {
            throw TranscriptionError.apiKeyMissing
        }

        guard let url = URL(string: "https://api.openai.com/v1/audio/transcriptions") else {
            throw TranscriptionError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = createRequestBody(audioURL: audioURL, boundary: boundary)
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let httpResponse = response as? HTTPURLResponse {
                    print("🛑 Transcription API request failed with status code: \(httpResponse.statusCode)")
                    let responseBody = String(data: data, encoding: .utf8) ?? "Could not decode error body"
                    print("   Response body: \(responseBody)")
                }
                throw TranscriptionError.invalidResponse
            }

            do {
                let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
                return transcriptionResponse.text
            } catch {
                throw TranscriptionError.decodingFailed(error)
            }
        } catch {
            throw TranscriptionError.requestFailed(error)
        }
    }

    private func createRequestBody(audioURL: URL, boundary: String) -> Data {
        var body = Data()
        let filename = audioURL.lastPathComponent
        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioURL)
        } catch {
            return Data() // Return empty data if file read fails
        }

        // Model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // File parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
} 