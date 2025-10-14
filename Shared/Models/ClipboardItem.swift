import Foundation

public struct ClipboardItem: Identifiable, Codable {
    public let id: UUID
    public var text: String
    public let date: Date
    public var isPinned: Bool
    public var category: ItemCategory
    
    // Yeni alanlar
    public var tags: [String]
    public var note: String?
    public var isFavorite: Bool
    public var usageCount: Int
    public var lastUsedDate: Date?
    
    public init(text: String) {
        self.id = UUID()
        self.text = text
        self.date = Date()
        self.isPinned = false
        self.category = CategoryDeterminer.determineCategory(for: text)
        self.tags = []
        self.note = nil
        self.isFavorite = false
        self.usageCount = 0
        self.lastUsedDate = nil
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case date
        case isPinned
        case category
        case tags
        case note
        case isFavorite
        case usageCount
        case lastUsedDate
    }
    
    // Eski kayıtlarla uyumlu özel decode
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.category = try container.decodeIfPresent(ItemCategory.self, forKey: .category) ?? CategoryDeterminer.determineCategory(for: text)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
        self.isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
        self.lastUsedDate = try container.decodeIfPresent(Date.self, forKey: .lastUsedDate)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(date, forKey: .date)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(category, forKey: .category)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(usageCount, forKey: .usageCount)
        try container.encodeIfPresent(lastUsedDate, forKey: .lastUsedDate)
    }
}
