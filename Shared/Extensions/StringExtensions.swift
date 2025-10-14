import Foundation

// MARK: - String Transformation & Statistics Extensions
public extension String {
    
    // MARK: - İstatistikler
    
    /// Kelime sayısını döndürür
    var wordCount: Int {
        let words = self.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    /// Satır sayısını döndürür
    var lineCount: Int {
        let lines = self.components(separatedBy: .newlines)
        return lines.filter { !$0.isEmpty }.count
    }
    
    // MARK: - Temizleme İşlemleri
    
    /// Baştaki ve sondaki boşlukları temizler
    func trimmed() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Tüm boşlukları kaldırır
    func withoutSpaces() -> String {
        self.replacingOccurrences(of: " ", with: "")
    }
    
    /// Çift boşlukları teke indirir
    func normalizedSpaces() -> String {
        self.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
    }
    
    // MARK: - Büyük/Küçük Harf Dönüşümleri
    
    /// Türkçe karakterlere uygun büyük harf dönüşümü
    func uppercasedTr() -> String {
        self.uppercased(with: Locale(identifier: "tr_TR"))
    }
    
    /// Türkçe karakterlere uygun küçük harf dönüşümü
    func lowercasedTr() -> String {
        self.lowercased(with: Locale(identifier: "tr_TR"))
    }
    
    /// Türkçe karakterlere uygun başlıklandırma (her kelimenin ilk harfi büyük)
    func capitalizedTr() -> String {
        self.capitalized(with: Locale(identifier: "tr_TR"))
    }
    
    // MARK: - Satır İşlemleri
    
    /// Tüm satır sonlarını kaldırarak tek satır haline getirir
    func singleLined() -> String {
        self.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .normalizedSpaces()
            .trimmed()
    }
    
    /// Tekrar eden satırları kaldırır
    func removingDuplicateLines() -> String {
        var seen = Set<String>()
        let lines = self.components(separatedBy: .newlines)
        let uniqueLines = lines.filter { line in
            let trimmedLine = line.trimmed()
            guard !trimmedLine.isEmpty else { return false }
            if seen.contains(trimmedLine) {
                return false
            } else {
                seen.insert(trimmedLine)
                return true
            }
        }
        return uniqueLines.joined(separator: "\n")
    }
    
    /// Boş satırları kaldırır
    func removingEmptyLines() -> String {
        let lines = self.components(separatedBy: .newlines)
        let nonEmptyLines = lines.filter { !$0.trimmed().isEmpty }
        return nonEmptyLines.joined(separator: "\n")
    }
    
    // MARK: - Özel Dönüşümler
    
    /// İlk satırı döndürür
    var firstLine: String {
        self.components(separatedBy: .newlines).first ?? ""
    }
    
    /// Son satırı döndürür
    var lastLine: String {
        self.components(separatedBy: .newlines).last ?? ""
    }
    
    /// İlk N kelimeyi döndürür
    func firstWords(_ count: Int) -> String {
        let words = self.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.prefix(count).joined(separator: " ")
    }
    
    /// Son N kelimeyi döndürür
    func lastWords(_ count: Int) -> String {
        let words = self.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.suffix(count).joined(separator: " ")
    }
    
    // MARK: - Özel Karakterler
    
    /// Özel karakterleri kaldırır (sadece harf ve sayılar kalır)
    func withoutSpecialCharacters() -> String {
        self.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
    
    /// Sayıları kaldırır
    func withoutNumbers() -> String {
        self.components(separatedBy: CharacterSet.decimalDigits)
            .joined()
    }
}
