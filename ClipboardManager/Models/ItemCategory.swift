import SwiftUI

public enum ItemCategory: String, Codable, CaseIterable {
    case all = "Tümü"
    case pinned = "Sabitler"
    case text = "Metin"
    case link = "Linkler"
    case email = "E-posta"
    case phone = "Telefon"
    case short = "Kısa"
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .pinned: return "pin.fill"
        case .text: return "doc.text.fill"
        case .link: return "link"
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .short: return "character"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .blue
        case .pinned: return .orange
        case .text: return .primary
        case .link: return .green
        case .email: return .blue
        case .phone: return .purple
        case .short: return .gray
        }
    }
}