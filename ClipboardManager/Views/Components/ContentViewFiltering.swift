import SwiftUI

struct ContentViewFiltering {
    
    static func filteredItems(
        from items: [ClipboardItem],
        searchText: String,
        selectedCategory: ItemCategory
    ) -> [ClipboardItem] {
        var filteredItems = items
        
        // Önce kategori filtrelemesi yap
        if selectedCategory != .all {
            if selectedCategory == .pinned {
                filteredItems = filteredItems.filter { $0.isPinned }
            } else {
                filteredItems = filteredItems.filter { $0.category == selectedCategory }
            }
        }
        
        // Sonra arama filtrelemesi yap
        if !searchText.isEmpty {
            filteredItems = filteredItems.filter { item in
                item.text.localizedCaseInsensitiveContains(searchText)
            }
        } else {
            // Arama yoksa, sabitleri en üste getir
            let pinnedItems = filteredItems.filter { $0.isPinned }
            let unpinnedItems = filteredItems.filter { !$0.isPinned }
            filteredItems = pinnedItems + unpinnedItems
        }
        
        return filteredItems
    }
}