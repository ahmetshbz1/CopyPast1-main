import SwiftUI

struct ContentSectionView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    let filteredItems: [ClipboardItem]
    let searchText: String
    let showToastMessage: (String) -> Void
    let onDeleteItem: (ClipboardItem) -> Void
    let onTogglePin: (ClipboardItem) -> Void
    
    var body: some View {
        Group {
            if clipboardManager.clipboardItems.isEmpty {
                EmptyStateView()
            } else if filteredItems.isEmpty {
                FilteredEmptyView(searchText: searchText, selectedCategory: clipboardManager.selectedCategory)
            } else {
                itemsList
            }
        }
    }
    
    private var itemsList: some View {
        List {
            ForEach(filteredItems) { item in
                ClipboardItemView(
                    item: item,
                    showToastMessage: showToastMessage
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            onDeleteItem(item)
                        }
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        withAnimation {
                            onTogglePin(item)
                        }
                    } label: {
                        Label(item.isPinned ? "Sabitlemeyi Kaldır" : "Sabitle",
                              systemImage: item.isPinned ? "pin.slash" : "pin")
                    }
                    .tint(.blue)
                    
                    Button {
                        withAnimation {
                            toggleFavorite(item)
                        }
                    } label: {
                        Label(item.isFavorite ? "Çıkar" : "Favori",
                              systemImage: item.isFavorite ? "star.slash" : "star")
                    }
                    .tint(.yellow)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .refreshable {
            clipboardManager.loadItems()
        }
    }
    
    private func toggleFavorite(_ item: ClipboardItem) {
        clipboardManager.toggleFavoriteItem(item)
    }
}
