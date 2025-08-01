import SwiftUI

struct ItemContentView: View {
    let item: ClipboardItem
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: item.category.icon)
                    .font(.system(size: 16))
                    .foregroundColor(item.category.color.opacity(0.8))
                
                Text(item.category.rawValue)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(timeAgoDisplay(date: item.date))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Text(item.text)
                .lineLimit(2)
                .font(.system(size: 16))
                .foregroundColor(.primary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color.black.opacity(0.15) : Color.white.opacity(0.5))
                .background(.ultraThinMaterial)
        )
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            item.isPinned ?
                RoundedRectangle(cornerRadius: 14)
                .stroke(ItemCategory.pinned.color.opacity(0.5), lineWidth: 1.5)
                : nil
        )
    }
}