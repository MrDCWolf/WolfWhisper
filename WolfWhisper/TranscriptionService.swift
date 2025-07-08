import Foundation
import OSLog

final class TranscriptionService: Sendable {
    static let shared = TranscriptionService()
    private let logger = Logger(subsystem: "com.wolfwhisper.app", category: "TranscriptionService")
    
    private init() {}
    
    func transcribe(audioData: Data, apiKey: String, model: String) async throws -> String {
        logger.info("Starting OpenAI transcription with \(audioData.count) bytes of audio data")
        
        guard !apiKey.isEmpty else {
            logger.error("API key is missing.")
            let error = TranscriptionError.invalidAPIKey
            logger.error("Transcription failed: Invalid API key")
            throw error
        }
        
        do {
            let transcribedText = try await performTranscription(audioData: audioData, apiKey: apiKey, model: model)
            logger.info("OpenAI Transcription successful")
            return transcribedText
        } catch {
            logger.error("OpenAI Transcription failed with error: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func performTranscription(audioData: Data, apiKey: String, model: String) async throws -> String {
        // Create the OpenAI API request
        guard let url = URL(string: "https://api.openai.com/v1/audio/transcriptions") else {
            throw TranscriptionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        
        // Add file parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add response format parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("text\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Perform the request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscriptionError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                // Try to parse error message from response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw TranscriptionError.apiError(message)
                } else {
                    throw TranscriptionError.httpError(httpResponse.statusCode)
                }
            }
            
            let transcriptionResponse = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data)
            return transcriptionResponse.text
            
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.networkError(error)
        }
    }
}

struct OpenAITranscriptionResponse: Decodable {
    let text: String
}

// MARK: - Error Types
enum TranscriptionError: Error, LocalizedError {
    case invalidAPIKey
    case invalidURL
    case invalidResponse
    case emptyTranscription
    case networkError(Error)
    case apiError(String)
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid or missing API key"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .emptyTranscription:
            return "No transcription text received"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
} 