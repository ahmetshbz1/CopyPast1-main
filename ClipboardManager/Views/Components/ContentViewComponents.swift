import SwiftUI

struct ContentViewComponents {
    let state: ContentViewState
    let actions: ContentViewActions
    
    var filteredItems: [ClipboardItem] {
        ContentViewFiltering.filteredItems(
            from: state.clipboardManager.clipboardItems,
            searchText: state.searchText,
            selectedCategory: state.clipboardManager.selectedCategory
        )
    }
    
    func headerSection() -> some View {
        VStack(spacing: 8) {
            SearchBar(text: Binding(
                get: { state.searchText },
                set: { state.searchText = $0 }
            ))
                .padding(.horizontal)
                .padding(.top, 10)
            
            categoryFilterBar()
        }
    }
    
    func categoryFilterBar() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: state.clipboardManager.selectedCategory == category,
                        onTap: {
                            actions.selectCategory(category)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
    
    func contentSection() -> some View {
        Group {
            if state.clipboardManager.clipboardItems.isEmpty {
                EmptyStateView()
            } else if filteredItems.isEmpty {
                FilteredEmptyView(
                    searchText: state.searchText,
                    selectedCategory: state.clipboardManager.selectedCategory
                )
            } else {
                itemsList()
            }
        }
    }
    
    func itemsList() -> some View {
        List {
            ForEach(filteredItems) { item in
                ClipboardItemView(
                    item: item,
                    showToastMessage: state.showToastMessage
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            actions.deleteItem(item)
                        }
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        withAnimation {
                            actions.togglePin(item)
                        }
                    } label: {
                        Label(item.isPinned ? "Sabitlemeyi Kaldır" : "Sabitle",
                              systemImage: item.isPinned ? "pin.slash" : "pin")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .refreshable {
            state.clipboardManager.loadItems()
        }
    }
}