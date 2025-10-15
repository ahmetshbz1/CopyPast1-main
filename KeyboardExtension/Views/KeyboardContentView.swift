import SwiftUI

struct KeyboardContentView: View {
    @ObservedObject var clipboardManager = ClipboardManager.shared
    let onItemSelected: (String) -> Void
    @State private var itemToDelete: ClipboardItem?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        if clipboardManager.filteredItems.isEmpty {
            if clipboardManager.clipboardItems.isEmpty {
                emptyStateView
            } else {
                filteredEmptyView
            }
        } else {
            itemsList
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
            
            VStack(spacing: 6) {
                Text("Henüz Hiç Öğe Yok")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Bir şeyler kopyaladığınızda burada görünecek")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var filteredEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: clipboardManager.selectedCategory.icon)
                .font(.system(size: 40))
                .foregroundColor(clipboardManager.selectedCategory.color.opacity(0.5))
            
            Text("Bu Kategoride Öğe Yok")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("\(clipboardManager.selectedCategory.rawValue) kategorisinde henüz öğe bulunmuyor")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var itemsList: some View {
        List {
            ForEach(clipboardManager.filteredItems) { item in
                KeyboardClipboardItemView(item: item) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onItemSelected(item.text)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        itemToDelete = item
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        withAnimation {
                            toggleFavorite(item)
                        }
                    } label: {
                        Label(item.isFavorite ? "Favoriden Çıkar" : "Favorile", 
                              systemImage: item.isFavorite ? "star.fill" : "star")
                    }
                    .tint(.yellow)
                    
                    Button {
                        withAnimation {
                            togglePin(item)
                        }
                    } label: {
                        Label(item.isPinned ? "Çöz" : "Sabitle", 
                              systemImage: item.isPinned ? "pin.slash" : "pin")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .confirmationDialog(
            "Bu öğeyi silmek istediğinizden emin misiniz?",
            isPresented: Binding(
                get: { itemToDelete != nil },
                set: { if !$0 { itemToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                if let item = itemToDelete {
                    withAnimation {
                        deleteItem(item)
                    }
                    itemToDelete = nil
                }
            }
            Button("İptal", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            Text("Bu işlem geri alınamaz.")
        }
    }
    
    private func deleteItem(_ item: ClipboardItem) {
        clipboardManager.deleteItem(item)
    }
    
    private func togglePin(_ item: ClipboardItem) {
        clipboardManager.togglePinItem(item)
    }
    
    private func toggleFavorite(_ item: ClipboardItem) {
        clipboardManager.toggleFavoriteItem(item)
    }
}
