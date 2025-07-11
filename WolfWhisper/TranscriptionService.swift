import Foundation

@MainActor
class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()
    
    // Callback for transcription completion
    var onTranscriptionComplete: ((Result<String, Error>) -> Void)?
    
    private init() {}
    
    func transcribe(audioData: Data, apiKey: String, model: String) async throws {
        guard !apiKey.isEmpty else {
            let error = TranscriptionError.invalidAPIKey
            onTranscriptionComplete?(.failure(error))
            throw error
        }
        
        do {
            let transcribedText = try await performTranscription(audioData: audioData, apiKey: apiKey, model: model)
            onTranscriptionComplete?(.success(transcribedText))
        } catch {
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
        
        // Add prompt parameter for enhanced transcription quality with cleanup
        let transcriptionPrompt = """
        Please provide a clean, professional transcription with the following enhancements:
        
        1. GRAMMAR: Fix grammatical errors and ensure proper sentence structure while preserving the speaker's intended meaning.
        2. FILLER WORDS: Remove all filler words and sounds including 'um', 'uh', 'ah', 'er', 'like', 'you know', 'so', and similar verbal hesitations.
        3. STUTTERS: Remove stutters and repeated words (e.g., "I I I think" becomes "I think").
        4. PUNCTUATION: Add proper punctuation including periods, commas, question marks, and exclamation points based on context and intonation.
        5. CAPITALIZATION: Use proper capitalization for sentences, proper nouns, and acronyms.
        6. FORMATTING: Present as clear, readable text that flows naturally.
        
        Maintain the speaker's original intent and meaning while making the text professional and polished.
        """
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