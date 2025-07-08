import Foundation

class GoogleAIService {
    // Shared instance for easy access
    @MainActor static let shared = GoogleAIService()
    
    // The base endpoint for Gemini API
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    // Define the structure for the request body
    private struct RequestBody: Codable {
        let contents: [Content]
    }
    
    private struct Content: Codable {
        let parts: [Part]
    }
    
    private struct Part: Codable {
        // Can be either text or inline_data, so make them optional
        let text: String?
        let inline_data: InlineData?
        
        init(text: String) {
            self.text = text
            self.inline_data = nil
        }
        
        init(inlineData: InlineData) {
            self.text = nil
            self.inline_data = inlineData
        }
    }
    
    private struct InlineData: Codable {
        let mime_type: String
        let data: String // Base64 encoded audio
    }

    // Define the structure for a successful response
    private struct ResponseBody: Decodable {
        let candidates: [Candidate]
    }
    
    private struct Candidate: Decodable {
        let content: ContentResponse
    }
    
    private struct ContentResponse: Decodable {
        let parts: [PartResponse]
    }
    
    private struct PartResponse: Decodable {
        let text: String
    }

    // Define custom errors
    enum GoogleAIError: LocalizedError {
        case invalidURL
        case noAPIKey
        case invalidResponse
        case noContent
        case apiError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .noAPIKey:
                return "No Google AI API key provided"
            case .invalidResponse:
                return "Invalid response from Google AI API"
            case .noContent:
                return "No content received from Google AI API"
            case .apiError(let message):
                return "Google AI API error: \(message)"
            }
        }
    }

    func processAudio(audioData: Data, apiKey: String, model: GeminiModel, masterPrompt: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GoogleAIError.noAPIKey
        }
        
        // 1. Convert audio data to Base64
        let audioBase64 = audioData.base64EncodedString()
        
        // 2. Construct the API URL with the model and key
        let apiURL = "\(baseURL)/\(model.rawValue):generateContent"
        guard var components = URLComponents(string: apiURL) else {
            throw GoogleAIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let finalURL = components.url else {
            throw GoogleAIError.invalidURL
        }
        
        // 3. Create the request body
        let promptPart = Part(text: masterPrompt)
        let audioPart = Part(inlineData: InlineData(mime_type: "audio/m4a", data: audioBase64))
        let requestBody = RequestBody(contents: [Content(parts: [promptPart, audioPart])])
        
        // 4. Build the URLRequest
        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // 5. Execute the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 6. Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleAIError.invalidResponse
        }
        
        // Handle different status codes
        if httpResponse.statusCode != 200 {
            // Try to decode error response
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw GoogleAIError.apiError(message)
            } else {
                throw GoogleAIError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        // 7. Decode the response and extract the text
        do {
            let decodedResponse = try JSONDecoder().decode(ResponseBody.self, from: data)
            
            guard let text = decodedResponse.candidates.first?.content.parts.first?.text else {
                throw GoogleAIError.noContent
            }
            
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            // If JSON decoding fails, throw a more specific error
            throw GoogleAIError.invalidResponse
        }
    }
    
    // Master prompt for Gemini that combines transcription and cleanup
    static let masterPrompt = """
    You are an expert transcription and text editor. Your task is to:

    1. TRANSCRIBE the audio file accurately, capturing every word spoken
    2. CLEAN UP the transcription by applying smart formatting and corrections

    TRANSCRIPTION GUIDELINES:
    - Transcribe exactly what is spoken, including filler words initially
    - Maintain speaker intent and meaning
    - Handle multiple speakers if present
    - Preserve technical terms and proper nouns

    CLEANUP GUIDELINES:
    - Remove excessive filler words (um, uh, like, you know) but keep some for naturalness
    - Fix obvious grammatical errors and run-on sentences
    - Add proper punctuation and capitalization
    - Preserve the original sentence order and narrative flow
    - NEVER rearrange or reorder sentences
    - If you detect numbered sequences (One, Two, Three... or 1, 2, 3...), format as numbered lists
    - Only create bullet lists when items are clearly presented as separate, distinct items
    - Do NOT force list formatting on flowing sentences

    CRITICAL RULES:
    - Preserve the exact original order of sentences
    - Never move concluding sentences to the beginning
    - Maintain natural narrative flow
    - Be conservative with list detection - only when obvious
    - Return ONLY the cleaned transcription text
    - Do not add any meta-commentary or explanations

    Please transcribe and clean up the audio:
    """
} 