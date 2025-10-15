import Foundation

public class OpenAIService: AIServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    private let rateLimiter = RateLimiter(maxRequests: 10, timeWindow: 60)
    private let session = URLSession.shared
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func summarizeText(_ text: String) async throws -> String {
        try validateRequest()
        
        let prompt = """
        Aşağıdaki metni özetle. Önemli noktaları koruyarak kısa ve anlaşılır bir özet yap:
        
        \(text)
        """
        
        return try await sendRequest(prompt: prompt, maxTokens: 150)
    }
    
    public func translateText(_ text: String, to language: String) async throws -> String {
        try validateRequest()
        
        let prompt = """
        Aşağıdaki metni \(language) diline çevir:
        
        \(text)
        """
        
        return try await sendRequest(prompt: prompt, maxTokens: 500)
    }
    
    public func improveText(_ text: String, style: TextStyle) async throws -> String {
        try validateRequest()
        
        let styleDescription = getStyleDescription(style)
        let prompt = """
        Aşağıdaki metni \(styleDescription) bir tarzda yeniden yaz:
        
        \(text)
        """
        
        return try await sendRequest(prompt: prompt, maxTokens: 400)
    }
    
    public func extractKeywords(_ text: String) async throws -> [String] {
        try validateRequest()
        
        let prompt = """
        Aşağıdaki metinden 5-10 anahtar kelime çıkar. Sadece kelimeleri virgülle ayırarak listele:
        
        \(text)
        """
        
        let response = try await sendRequest(prompt: prompt, maxTokens: 100)
        return response.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    // Private helper methods
    private func validateRequest() throws {
        guard !apiKey.isEmpty else {
            throw AIServiceError.invalidAPIKey
        }
        
        guard rateLimiter.canMakeRequest() else {
            throw AIServiceError.rateLimitExceeded
        }
        
        rateLimiter.recordRequest()
    }
    
    private func sendRequest(prompt: String, maxTokens: Int) async throws -> String {
        guard prompt.count < 4000 else {
            throw AIServiceError.textTooLong
        }
        
        let requestBody = OpenAIRequest(
            model: "gpt-4o-mini",
            messages: [
                OpenAIMessage(role: "user", content: prompt)
            ],
            maxTokens: maxTokens,
            temperature: 0.7
        )
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw AIServiceError.serviceUnavailable
            }
            
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            
            guard let content = openAIResponse.choices.first?.message.content else {
                throw AIServiceError.invalidResponse
            }
            
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
            
        } catch {
            if error is AIServiceError {
                throw error
            } else {
                throw AIServiceError.networkError(error)
            }
        }
    }
    
    private func getStyleDescription(_ style: TextStyle) -> String {
        switch style {
        case .formal: return "resmi ve saygılı"
        case .casual: return "günlük ve samimi"
        case .business: return "profesyonel ve iş odaklı"
        case .academic: return "akademik ve bilimsel"
        case .creative: return "yaratıcı ve etkileyici"
        }
    }
}

// OpenAI API Models
private struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int
    let temperature: Double
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

private struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}