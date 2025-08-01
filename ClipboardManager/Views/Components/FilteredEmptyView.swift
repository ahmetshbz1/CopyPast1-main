import SwiftUI

struct FilteredEmptyView: View {
    let searchText: String
    let selectedCategory: ItemCategory
    
    var body: some View {
        VStack(spacing: 24) {
            if !searchText.isEmpty {
                // Arama sonucu boş durumu
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                
                Text("Sonuç Bulunamadı")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("\"\(searchText)\" ile eşleşen bir sonuç yok")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                // Kategori filtrelemesi boş durumu
                Image(systemName: selectedCategory.icon)
                    .font(.system(size: 50))
                    .foregroundColor(selectedCategory.color.opacity(0.6))
                    .shadow(color: selectedCategory.color.opacity(0.1), radius: 10, x: 0, y: 5)
                
                Text("Bu Kategoride Öğe Yok")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("\(selectedCategory.rawValue) kategorisinde henüz öğe bulunmuyor")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}