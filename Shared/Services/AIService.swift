import Foundation

// AI işlemleri için temel protocol
public protocol AIServiceProtocol {
    func summarizeText(_ text: String) async throws -> String
    func translateText(_ text: String, to language: String) async throws -> String
    func improveText(_ text: String, style: TextStyle) async throws -> String
    func extractKeywords(_ text: String) async throws -> [String]
}

// Text iyileştirme stilleri
public enum TextStyle: String, CaseIterable {
    case formal = "formal"
    case casual = "casual"  
    case business = "business"
    case academic = "academic"
    case creative = "creative"
    
    public var displayName: String {
        switch self {
        case .formal: return "Resmi"
        case .casual: return "Günlük"
        case .business: return "İş"
        case .academic: return "Akademik"
        case .creative: return "Yaratıcı"
        }
    }
}

// AI servis hataları
public enum AIServiceError: LocalizedError {
    case invalidAPIKey
    case rateLimitExceeded
    case textTooLong
    case networkError(Error)
    case invalidResponse
    case serviceUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "API anahtarı geçersiz"
        case .rateLimitExceeded:
            return "Kullanım limiti aşıldı"
        case .textTooLong:
            return "Metin çok uzun"
        case .networkError(let error):
            return "Ağ hatası: \(error.localizedDescription)"
        case .invalidResponse:
            return "Geçersiz yanıt"
        case .serviceUnavailable:
            return "Servis kullanılamıyor"
        }
    }
}

// Rate limiting için helper
public class RateLimiter {
    private let maxRequests: Int
    private let timeWindow: TimeInterval
    private var requestTimes: [Date] = []
    
    public init(maxRequests: Int, timeWindow: TimeInterval) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
    }
    
    public func canMakeRequest() -> Bool {
        let now = Date()
        requestTimes = requestTimes.filter { now.timeIntervalSince($0) < timeWindow }
        return requestTimes.count < maxRequests
    }
    
    public func recordRequest() {
        requestTimes.append(Date())
    }
}