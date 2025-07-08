import Foundation
import OSLog

// MARK: - Error Handling
enum GoogleAIError: Error, LocalizedError {
    case invalidURL
    case noAPIKey
    case invalidResponse
    case noContent
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The URL for the Google AI API is invalid."
        case .noAPIKey: return "Your Google AI API key is missing. Please add it in the settings."
        case .invalidResponse: return "The server returned an invalid or unexpected response."
        case .noContent: return "The API response did not contain any transcribable text."
        }
    }
}

// MARK: - Codable Structs for API Interaction
private struct InlineData: Codable {
    let mime_type: String
    let data: String
}

private struct Part: Codable {
    let text: String?
    let inlineData: InlineData?

    init(text: String) {
        self.text = text
        self.inlineData = nil
    }

    init(inlineData: InlineData) {
        self.text = nil
        self.inlineData = inlineData
    }
}

private struct Content: Codable {
    let parts: [Part]
}

// This represents the JSON object inside the AI's text response
private struct TranscriptionResult: Decodable {
    let text: String
}

private struct GenerationConfig: Codable {
    let responseMimeType: String

    enum CodingKeys: String, CodingKey {
        case responseMimeType = "response_mime_type"
    }
}

private struct RequestBody: Codable {
    let contents: [Content]
    let generationConfig: GenerationConfig
}

private struct ResponseBody: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}


// MARK: - Google AI Service
final class GoogleAIService: Sendable {
    static let shared = GoogleAIService()
    private static let logger = Logger(subsystem: "com.wolfwhisper.app", category: "GoogleAIService")
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    private init() {} // Private initializer for singleton

    func performTranscription(audioData: Data, apiKey: String, modelName: String) async throws -> String {
        guard !apiKey.isEmpty else {
            Self.logger.error("Google AI API key is missing.")
            throw GoogleAIError.noAPIKey
        }
        
        let modelEndpoint = "\\(baseURL)/\\(modelName):generateContent"
        guard var components = URLComponents(string: modelEndpoint) else {
            throw GoogleAIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let url = components.url else { throw GoogleAIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonPrompt = "Transcribe the following audio and return the transcription as a JSON object with a single key 'text'."
        
        let promptPart = Part(text: jsonPrompt)
        let audioPart = Part(inlineData: InlineData(mime_type: "audio/m4a", data: audioData.base64EncodedString()))
        let config = GenerationConfig(responseMimeType: "application/json")
        let requestBody = RequestBody(contents: [Content(parts: [promptPart, audioPart])], generationConfig: config)
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let _ = (response as? HTTPURLResponse)?.statusCode ?? -1
            Self.logger.error("Invalid response from Google AI API. Status code: \\((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw GoogleAIError.invalidResponse
        }
        
        let responseBody = try JSONDecoder().decode(ResponseBody.self, from: data)
        
        guard let jsonString = responseBody.candidates.first?.content.parts.first?.text else {
            throw GoogleAIError.noContent
        }
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            Self.logger.error("Failed to convert JSON string to data. String was: \\(jsonString)")
            throw GoogleAIError.invalidResponse
        }
        
        do {
            let finalResult = try JSONDecoder().decode(TranscriptionResult.self, from: jsonData)
            Self.logger.info("Successfully received and parsed response from Google AI API.")
            return finalResult.text
        } catch {
            Self.logger.error("Failed to decode final JSON object: \\(error.localizedDescription). JSON string was: \\(jsonString)")
            throw GoogleAIError.invalidResponse
        }
    }
} 