import SwiftUI

struct StatisticsView: View {
    @Binding var showStatistics: Bool
    @StateObject private var clipboardManager = ClipboardManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            List {
                // Genel istatistikler
                Section {
                    StatRow(title: "Toplam Öğe", value: "\(clipboardManager.clipboardItems.count)", icon: "doc.text.fill", color: .blue)
                    StatRow(title: "Sabitlenen", value: "\(pinnedCount)", icon: "pin.fill", color: .orange)
                    StatRow(title: "Favoriler", value: "\(favoriteCount)", icon: "star.fill", color: .yellow)
                    StatRow(title: "Etiketli", value: "\(taggedCount)", icon: "tag.fill", color: .green)
                } header: {
                    Text("Genel")
                }
                
                // Kategori dağılımı
                Section {
                    ForEach(categoryStats, id: \.category) { stat in
                        HStack {
                            Image(systemName: stat.category.icon)
                                .foregroundColor(stat.category.color)
                                .frame(width: 24)
                            
                            Text(stat.category.rawValue)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("\(stat.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("\(stat.percentage)%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 45, alignment: .trailing)
                        }
                    }
                } header: {
                    Text("Kategori Dağılımı")
                }
                
                // En çok kullanılanlar
                if !mostUsedItems.isEmpty {
                    Section {
                        ForEach(mostUsedItems.prefix(5)) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.text)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                        Text("\(item.usageCount)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Text(timeAgoDisplay(date: item.lastUsedDate ?? item.date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("En Çok Kullanılanlar")
                    }
                }
                
                // Son eklenenler
                Section {
                    ForEach(recentItems.prefix(5)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.text)
                                .font(.subheadline)
                                .lineLimit(1)
                            
                            HStack {
                                Image(systemName: item.category.icon)
                                    .font(.caption2)
                                    .foregroundColor(item.category.color)
                                Text(timeAgoDisplay(date: item.date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Son Eklenenler")
                }
            }
            .navigationTitle("İstatistikler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        showStatistics = false
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var pinnedCount: Int {
        clipboardManager.clipboardItems.filter { $0.isPinned }.count
    }
    
    private var favoriteCount: Int {
        clipboardManager.clipboardItems.filter { $0.isFavorite }.count
    }
    
    private var taggedCount: Int {
        clipboardManager.clipboardItems.filter { !$0.tags.isEmpty }.count
    }
    
    private var categoryStats: [CategoryStat] {
        let total = clipboardManager.clipboardItems.count
        guard total > 0 else { return [] }
        
        var stats: [CategoryStat] = []
        
        for category in ItemCategory.allCases where category != .all && category != .pinned && category != .favorite {
            let count = clipboardManager.clipboardItems.filter { $0.category == category }.count
            if count > 0 {
                let percentage = Int((Double(count) / Double(total)) * 100)
                stats.append(CategoryStat(category: category, count: count, percentage: percentage))
            }
        }
        
        return stats.sorted { $0.count > $1.count }
    }
    
    private var mostUsedItems: [ClipboardItem] {
        clipboardManager.clipboardItems
            .filter { $0.usageCount > 0 }
            .sorted { $0.usageCount > $1.usageCount }
    }
    
    private var recentItems: [ClipboardItem] {
        clipboardManager.clipboardItems
            .sorted { $0.date > $1.date }
    }
}

// MARK: - Supporting Views

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
    }
}

struct CategoryStat {
    let category: ItemCategory
    let count: Int
    let percentage: Int
}
