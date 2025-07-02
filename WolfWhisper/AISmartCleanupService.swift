import Foundation

// MARK: - URLSession Extension
extension URLSession {
    func sendRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AISmartCleanupError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // Try to parse error message from response
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AISmartCleanupError.apiError(message)
            } else {
                throw AISmartCleanupError.httpError(httpResponse.statusCode)
            }
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("⚠️ JSON decoding failed: \(error)")
            throw AISmartCleanupError.invalidResponse
        }
    }
}

@MainActor
class AISmartCleanupService: ObservableObject {
    static let shared = AISmartCleanupService()
    
    private init() {}
    
    // MARK: - Analysis Response Structure
    enum BlockType: String, Codable {
        case paragraph
        case bulletedList = "bulleted_list"
        case numberedList = "numbered_list"
    }
    
    struct ContentBlock: Codable {
        let type: BlockType
        let text: String?
        let items: [String]?
    }
    
    struct AnalysisResponse: Codable {
        let blocks: [ContentBlock]
    }
    
    // MARK: - Main Smart Cleanup Function
    func performSmartCleanup(rawText: String, apiKey: String) async throws -> String {
        print("🧠 Starting AI Smart cleanup for text: \(rawText.prefix(100))...")
        
        // Single-pass analysis to break text into structured blocks
        let analysis = try await analyzeText(rawText, apiKey: apiKey)
        print("🔍 Analysis found \(analysis.blocks.count) blocks")
        
        // Client-side rendering of structured blocks
        let cleanedText = renderMarkdown(from: analysis.blocks)
        print("✨ Smart cleanup complete: \(cleanedText.prefix(100))...")
        
        return cleanedText
    }
    
    // MARK: - System Prompt Template
    private static let analysisSystemPrompt = """
    You are a text formatter. Analyze the given text and return a JSON response with structured blocks.
    
    RULES:
    • Preserve ALL original words exactly - do not add, remove, or modify anything
    • Group related sentences into single paragraph blocks when possible
    • Only create separate blocks for clear structural elements (actual lists)
    • When in doubt, use one paragraph block for the entire text
    • Be extremely conservative about list detection
    
    For lists, only extract if:
    • Clear enumeration: "apples, bananas, grapes" (not narrative flow)
    • Explicit numbering: "One, task. Two, task. Three, task."
    
    Return JSON only:
    {
      "blocks": [
        { "type": "paragraph", "text": "full text here" },
        { "type": "bulleted_list", "items": ["item1", "item2"] },
        { "type": "numbered_list", "items": ["item1", "item2"] }
      ]
    }
    
    Text to analyze:
    \"\"\"<YOUR_TEXT_HERE>\"\"\"
    """
    
    // MARK: - Analysis Function
    private func analyzeText(_ text: String, apiKey: String) async throws -> AnalysisResponse {
        let prompt = Self.analysisSystemPrompt.replacingOccurrences(
            of: "<YOUR_TEXT_HERE>",
            with: text
        )
        
        let request = buildAnalysisRequest(with: prompt, apiKey: apiKey)
        let openAIResponse: OpenAIResponse = try await URLSession.shared.sendRequest(request)
        
        // Extract the content and parse it as our AnalysisResponse
        let content = openAIResponse.choices.first?.message.content ?? ""
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract JSON from the response (in case there's extra text)
        let jsonContent: String
        if let jsonStart = trimmedContent.range(of: "{"),
           let jsonEnd = trimmedContent.range(of: "}", options: .backwards) {
            jsonContent = String(trimmedContent[jsonStart.lowerBound...jsonEnd.upperBound])
        } else {
            jsonContent = trimmedContent
        }
        
        // Remove surrounding quotes if present
        let cleanContent: String
        if jsonContent.hasPrefix("\"") && jsonContent.hasSuffix("\"") && jsonContent.count > 1 {
            cleanContent = String(jsonContent.dropFirst().dropLast())
        } else {
            cleanContent = jsonContent
        }
        
        // Parse the JSON response into our AnalysisResponse
        guard let data = cleanContent.data(using: .utf8),
              let analysis = try? JSONDecoder().decode(AnalysisResponse.self, from: data) else {
            // Fallback to single paragraph if JSON parsing fails
            print("⚠️ Failed to parse analysis JSON, defaulting to single paragraph")
            print("⚠️ Raw content: \(content)")
            print("⚠️ Clean content: \(cleanContent)")
            return AnalysisResponse(blocks: [ContentBlock(type: .paragraph, text: text, items: nil)])
        }
        
        return analysis
    }
    
    // MARK: - Client-side Markdown Rendering
    private func renderMarkdown(from blocks: [ContentBlock]) -> String {
        return blocks.map { block in
            switch block.type {
            case .paragraph:
                return (block.text ?? "") + "\n\n"
                
            case .bulletedList:
                return (block.items ?? [])
                    .map { "- \($0)" }
                    .joined(separator: "\n") + "\n\n"
                
            case .numberedList:
                return (block.items ?? [])
                    .enumerated()
                    .map { "\($0.offset + 1). \($0.element)" }
                    .joined(separator: "\n") + "\n\n"
            }
        }
        .joined()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Request Builder
    private func buildAnalysisRequest(with prompt: String, apiKey: String) -> URLRequest {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": prompt
                ]
            ],
            "max_tokens": 512,
            "temperature": 0.0,
            "response_format": ["type": "json_object"]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("⚠️ Failed to serialize request body: \(error)")
        }
        
        return request
    }
    
    // MARK: - OpenAI Response Structure
    private struct OpenAIResponse: Codable {
        let choices: [Choice]
        
        struct Choice: Codable {
            let message: Message
            
            struct Message: Codable {
                let content: String
            }
        }
    }
}

// MARK: - Error Types
enum AISmartCleanupError: LocalizedError {
    case invalidResponse
    case apiError(String)
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let message):
            return "API error: \(message)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
} 