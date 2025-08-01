import Foundation

public struct CategoryDeterminer {
    public static func determineCategory(for text: String) -> ItemCategory {
        if text.contains("@") && text.contains(".") {
            return .email
        } else if text.contains("http") || text.contains("www") || text.contains("://") {
            return .link
        } else if text.filter({ $0.isNumber }).count > 8 {
            return .phone
        } else if text.count < 20 {
            return .short
        } else {
            return .text
        }
    }
}