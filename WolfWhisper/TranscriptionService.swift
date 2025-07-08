import Foundation

@MainActor
class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()
    
    // Callback for transcription completion
    var onTranscriptionComplete: ((Result<String, Error>) -> Void)?
    
    private init() {}
    
    func transcribe(audioData: Data, apiKey: String, model: String) async throws {
        print("Starting transcription with \(audioData.count) bytes of audio data")
        
        guard !apiKey.isEmpty else {
            let error = TranscriptionError.invalidAPIKey
            print("Transcription failed: Invalid API key")
            onTranscriptionComplete?(.failure(error))
            throw error
        }
        
        do {
            let transcribedText = try await performTranscription(audioData: audioData, apiKey: apiKey, model: model)
            print("Transcription successful: \(transcribedText)")
            onTranscriptionComplete?(.success(transcribedText))
        } catch {
            print("Transcription failed with error: \(error)")
            onTranscriptionComplete?(.failure(error))
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
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add prompt parameter for better transcription quality
        let transcriptionPrompt = "Please provide a clean, well-formatted transcription with proper grammar, punctuation, and capitalization. Remove filler words like 'um', 'uh', 'ah', and stutters. Format as clear, professional text."
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(transcriptionPrompt)\r\n".data(using: .utf8)!)
        
        // Add response format parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("text\r\n".data(using: .utf8)!)
        
        // Add temperature parameter for more consistent results
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".data(using: .utf8)!)
        body.append("0.2\r\n".data(using: .utf8)!)
        
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
            
            // Parse the response text
            guard let transcriptionText = String(data: data, encoding: .utf8) else {
                throw TranscriptionError.invalidResponse
            }
            
            // Clean up the transcription text
            let cleanedText = transcriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !cleanedText.isEmpty else {
                throw TranscriptionError.emptyTranscription
            }
            
            return cleanedText
            
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.networkError(error)
        }
    }
}

// MARK: - Error Types
enum TranscriptionError: LocalizedError {
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