import Foundation

public struct ClipboardItem: Identifiable, Codable {
    public let id: UUID
    public var text: String
    public let date: Date
    public var isPinned: Bool
    public var category: ItemCategory
    
    public init(text: String) {
        self.id = UUID()
        self.text = text
        self.date = Date()
        self.isPinned = false
        self.category = CategoryDeterminer.determineCategory(for: text)
    }
}