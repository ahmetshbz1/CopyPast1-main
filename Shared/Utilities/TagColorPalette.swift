import SwiftUI

public struct TagColorPalette {
    
    public static let colors: [Color] = [
        .blue,
        .green,
        .orange,
        .purple,
        .pink,
        .red,
        .teal,
        .indigo
    ]
    
    /// Tag için renk döndürür (hash bazlı, tutarlı)
    public static func colorForTag(_ tag: String) -> Color {
        let hash = abs(tag.hashValue)
        let index = hash % colors.count
        return colors[index]
    }
    
    /// Renk için kontrast text rengi
    public static func contrastColor(for color: Color) -> Color {
        // iOS'ta genelde beyaz text iyi görünür
        return .white
    }
}
