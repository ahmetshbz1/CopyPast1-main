import SwiftUI

struct ItemContentView: View {
    let item: ClipboardItem
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Üst bar: kategori, favori, zaman
            HStack(spacing: 8) {
                Image(systemName: item.category.icon)
                    .font(.system(size: 16))
                    .foregroundColor(item.category.color.opacity(0.8))
                
                Text(item.category.rawValue)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                }
                
                Spacer()
                
                // Kullanım sayısı (varsa)
                if item.usageCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 11))
                        Text("\(item.usageCount)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.green.opacity(0.7))
                }
                
                Text(timeAgoDisplay(date: item.date))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            // Metin içeriği
            Text(item.text)
                .lineLimit(2)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            
            // Etiketler ve not göstergesi
            if !item.tags.isEmpty || item.note != nil {
                HStack(spacing: 8) {
                    if !item.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(item.tags, id: \.self) { tag in
                                    let tagColor = TagColorPalette.colorForTag(tag)
                                    Text("#\(tag)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(tagColor.gradient)
                                        )
                                }
                            }
                        }
                    }
                    
                    if item.note != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "note.text")
                                .font(.system(size: 11))
                            Text("Not")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.orange.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.1))
                        )
                    }
                }
            }
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
