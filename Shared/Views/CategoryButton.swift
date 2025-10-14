import SwiftUI

struct CategoryButton: View {
    let category: ItemCategory
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                
                Text(category.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : category.color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                          ? category.color
                          : (colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.8)))
                    .shadow(color: isSelected ? category.color.opacity(0.3) : Color.black.opacity(0.04),
                            radius: isSelected ? 4 : 1,
                            x: 0,
                            y: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}