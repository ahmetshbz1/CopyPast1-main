import Foundation
import Vision
import NaturalLanguage

public protocol SearchEngineProtocol {
    func search(_ query: String, in items: [EnhancedClipboardItem]) -> [SearchResult]
    func buildIndex(for items: [EnhancedClipboardItem]) async
    func suggestQueries(for text: String) -> [String]
    func extractKeywords(from text: String) -> [String]
}

public struct SearchResult: Identifiable {
    public let id = UUID()
    public let item: EnhancedClipboardItem
    public let relevanceScore: Double
    public let matchedField: SearchField
    public let highlightedText: String
    
    public init(item: EnhancedClipboardItem, relevanceScore: Double, matchedField: SearchField, highlightedText: String) {
        self.item = item
        self.relevanceScore = relevanceScore
        self.matchedField = matchedField
        self.highlightedText = highlightedText
    }
}

public enum SearchField: String, CaseIterable {
    case content = "content"
    case title = "title"
    case tags = "tags"
    case note = "note"
    case ocrText = "ocrText"
    case keywords = "keywords"
    
    public var displayName: String {
        switch self {
        case .content: return "İçerik"
        case .title: return "Başlık"
        case .tags: return "Etiketler"
        case .note: return "Not"
        case .ocrText: return "OCR Metni"
        case .keywords: return "Anahtar Kelimeler"
        }
    }
}

public struct SearchFilter {
    public let mediaTypes: [MediaType]
    public let categories: [ItemCategory]
    public let dateRange: DateRange?
    public let isPinned: Bool?
    public let isFavorite: Bool?
    public let hasTags: Bool?
    
    public init(
        mediaTypes: [MediaType] = MediaType.allCases,
        categories: [ItemCategory] = ItemCategory.allCases,
        dateRange: DateRange? = nil,
        isPinned: Bool? = nil,
        isFavorite: Bool? = nil,
        hasTags: Bool? = nil
    ) {
        self.mediaTypes = mediaTypes
        self.categories = categories
        self.dateRange = dateRange
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.hasTags = hasTags
    }
}

public struct DateRange {
    public let start: Date
    public let end: Date
    
    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public class SearchEngine: SearchEngineProtocol {
    
    private var searchIndex: [UUID: SearchIndexEntry] = [:]
    private let nlProcessor = NLProcessor()
    
    public init() {}
    
    public func search(_ query: String, in items: [EnhancedClipboardItem]) -> [SearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        let searchTerms = extractSearchTerms(from: trimmedQuery)
        var results: [SearchResult] = []
        
        for item in items {
            if let indexEntry = searchIndex[item.id] {
                let score = calculateRelevanceScore(searchTerms: searchTerms, indexEntry: indexEntry, item: item)
                
                if score > 0 {
                    let (matchedField, highlightedText) = findBestMatch(searchTerms: searchTerms, item: item)
                    
                    let result = SearchResult(
                        item: item,
                        relevanceScore: score,
                        matchedField: matchedField,
                        highlightedText: highlightedText
                    )
                    results.append(result)
                }
            }
        }
        
        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    public func buildIndex(for items: [EnhancedClipboardItem]) async {
        await withTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask { [weak self] in
                    await self?.indexItem(item)
                }
            }
        }
    }
    
    public func suggestQueries(for text: String) -> [String] {
        let keywords = extractKeywords(from: text)
        let suggestions = keywords.prefix(5).map { keyword in
            "içerik:\(keyword)"
        }
        
        return Array(suggestions)
    }
    
    public func extractKeywords(from text: String) -> [String] {
        return nlProcessor.extractKeywords(from: text)
    }
    
    // Private methods
    private func indexItem(_ item: EnhancedClipboardItem) async {
        var searchableContent = ""
        
        // Ana içeriği ekle
        if let content = item.textContent {
            searchableContent += content + " "
        }
        
        // Başlığı ekle
        searchableContent += item.title + " "
        
        // Etiketleri ekle
        searchableContent += item.tags.joined(separator: " ") + " "
        
        // Notu ekle
        if let note = item.note {
            searchableContent += note + " "
        }
        
        // OCR metnini ekle
        if let ocrText = item.ocrText {
            searchableContent += ocrText + " "
        }
        
        // Anahtar kelimeleri ekle
        searchableContent += item.extractedKeywords.joined(separator: " ")
        
        // Keywords ve stemmed words oluştur
        let keywords = nlProcessor.extractKeywords(from: searchableContent)
        let stemmedWords = nlProcessor.stemWords(keywords)
        
        let indexEntry = SearchIndexEntry(
            itemId: item.id,
            keywords: Set(keywords),
            stemmedWords: Set(stemmedWords),
            fullText: searchableContent.lowercased()
        )
        
        searchIndex[item.id] = indexEntry
    }
    
    private func extractSearchTerms(from query: String) -> [String] {
        return query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
    
    private func calculateRelevanceScore(searchTerms: [String], indexEntry: SearchIndexEntry, item: EnhancedClipboardItem) -> Double {
        var score: Double = 0
        
        for term in searchTerms {
            // Exact match bonus
            if indexEntry.keywords.contains(term) {
                score += 10
            }
            
            // Stemmed match
            let stemmed = nlProcessor.stemWord(term)
            if indexEntry.stemmedWords.contains(stemmed) {
                score += 5
            }
            
            // Partial match
            if indexEntry.fullText.contains(term) {
                score += 2
            }
            
            // Title match bonus
            if item.title.lowercased().contains(term) {
                score += 15
            }
            
            // Tag match bonus
            if item.tags.contains(where: { $0.lowercased().contains(term) }) {
                score += 8
            }
        }
        
        // Recency bonus
        let daysSinceCreation = Date().timeIntervalSince(item.createdDate) / 86400
        score += max(0, 5 - daysSinceCreation * 0.1)
        
        // Usage frequency bonus
        score += Double(item.usageCount) * 0.5
        
        // Pinned/favorite bonus
        if item.isPinned { score += 3 }
        if item.isFavorite { score += 2 }
        
        return score
    }
    
    private func findBestMatch(searchTerms: [String], item: EnhancedClipboardItem) -> (SearchField, String) {
        let fields: [(SearchField, String?)] = [
            (.title, item.title),
            (.content, item.textContent),
            (.note, item.note),
            (.ocrText, item.ocrText),
            (.tags, item.tags.isEmpty ? nil : item.tags.joined(separator: ", ")),
            (.keywords, item.extractedKeywords.isEmpty ? nil : item.extractedKeywords.joined(separator: ", "))
        ]
        
        for (field, content) in fields {
            if let content = content, !content.isEmpty {
                for term in searchTerms {
                    if content.lowercased().contains(term.lowercased()) {
                        let highlightedText = highlightSearchTerm(term, in: content)
                        return (field, highlightedText)
                    }
                }
            }
        }
        
        return (.content, item.textContent ?? item.title)
    }
    
    private func highlightSearchTerm(_ term: String, in text: String) -> String {
        return text.replacingOccurrences(
            of: term,
            with: "**\(term)**",
            options: [.caseInsensitive, .diacriticInsensitive]
        )
    }
}

// Search index entry
private struct SearchIndexEntry {
    let itemId: UUID
    let keywords: Set<String>
    let stemmedWords: Set<String>
    let fullText: String
}

// Natural language processor
public class NLProcessor {
    
    private let tagger = NLTagger(tagSchemes: [.tokenType, .lexicalClass, .nameType])
    
    public func extractKeywords(from text: String) -> [String] {
        tagger.string = text
        
        var keywords: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            
            let token = String(text[tokenRange]).lowercased()
            
            // Sadece önemli kelime türlerini al
            if let tag = tag, shouldIncludeTag(tag), token.count > 2 {
                keywords.append(token)
            }
            
            return true
        }
        
        // Sıklığa göre sırala ve en önemlilerini döndür
        let frequency = Dictionary(grouping: keywords, by: { $0 }).mapValues { $0.count }
        
        return frequency
            .sorted { $0.value > $1.value }
            .prefix(20)
            .map { $0.key }
    }
    
    public func stemWords(_ words: [String]) -> [String] {
        return words.map { stemWord($0) }
    }
    
    public func stemWord(_ word: String) -> String {
        // Basit Türkçe stemming - production'da daha gelişmiş bir kütüphane kullanılabilir
        let suffixes = ["ler", "lar", "den", "dan", "nın", "nin", "nun", "nün", "sı", "si", "su", "sü"]
        
        var stemmed = word.lowercased()
        for suffix in suffixes {
            if stemmed.hasSuffix(suffix) && stemmed.count > suffix.count + 2 {
                stemmed = String(stemmed.dropLast(suffix.count))
                break
            }
        }
        
        return stemmed
    }
    
    private func shouldIncludeTag(_ tag: NLTag) -> Bool {
        return [
            .noun,
            .verb,
            .adjective,
            .adverb
        ].contains(tag)
    }
}
