import Foundation

public struct CategoryDeterminer {
    public static func determineCategory(for text: String) -> ItemCategory {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // JSON kontrolü
        if isJSON(trimmed) { return .code }
        
        // Kod parçacığı kontrolü (Swift/JS/Genel)
        if isLikelyCodeSnippet(trimmed) { return .code }
        
        // E-posta
        if isLikelyEmail(trimmed) { return .email }
        
        // Link
        if isLikelyURL(trimmed) { return .link }
        
        // IP
        if isIPAddress(trimmed) { return .text }
        
        // IBAN
        if isValidIBAN(trimmed) { return .text }
        
        // Kredi kartı
        if isLikelyCreditCardNumber(trimmed) { return .text }
        
        // Telefon
        if digitsCount(in: trimmed) >= 9 && digitsCount(in: trimmed) <= 16 { return .phone }
        
        // Kısa metin
        if trimmed.count < 20 { return .short }
        
        return .text
    }
    
    private static func isLikelyEmail(_ s: String) -> Bool {
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return s.range(of: pattern, options: .regularExpression) != nil
    }
    
    private static func isLikelyURL(_ s: String) -> Bool {
        if s.contains("://") || s.lowercased().hasPrefix("www.") { return true }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(location: 0, length: s.utf16.count)
        return detector?.firstMatch(in: s, options: [], range: range) != nil
    }
    
    private static func isJSON(_ s: String) -> Bool {
        guard (s.hasPrefix("{") && s.hasSuffix("}")) || (s.hasPrefix("[") && s.hasSuffix("]")) else { return false }
        let data = s.data(using: .utf8) ?? Data()
        return (try? JSONSerialization.jsonObject(with: data, options: [])) != nil
    }
    
    private static func isLikelyCodeSnippet(_ s: String) -> Bool {
        let keywords = ["func ", "class ", "struct ", "import ", "let ", "var ", "public ", "private ", "=>", ";"]
        let score = keywords.reduce(0) { $0 + (s.contains($1) ? 1 : 0) }
        return score >= 2 || (s.contains("{") && s.contains("}"))
    }
    
    private static func isValidIBAN(_ s: String) -> Bool {
        // Basit IBAN format kontrolü (ülke kodu + 2 sayı + 11-30 alfanumerik)
        let pattern = "^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$"
        return s.replacingOccurrences(of: " ", with: "").range(of: pattern, options: .regularExpression) != nil
    }
    
    private static func isLikelyCreditCardNumber(_ s: String) -> Bool {
        let digits = s.filter({ $0.isNumber })
        guard (13...19).contains(digits.count) else { return false }
        return luhnCheck(digits)
    }
    
    private static func luhnCheck(_ digits: String) -> Bool {
        var sum = 0
        let reversed = digits.reversed().map { Int(String($0)) ?? 0 }
        for (idx, num) in reversed.enumerated() {
            if idx % 2 == 1 {
                var doubled = num * 2
                if doubled > 9 { doubled -= 9 }
                sum += doubled
            } else {
                sum += num
            }
        }
        return sum % 10 == 0
    }
    
    private static func isIPAddress(_ s: String) -> Bool {
        let pattern = "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\\.)){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        return s.range(of: pattern, options: .regularExpression) != nil
    }
    
    private static func digitsCount(in s: String) -> Int {
        s.filter({ $0.isNumber }).count
    }
}
