import SwiftUI

struct KeyboardContentView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    let onItemSelected: (String) -> Void
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
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.6))
                .shadow(color: .blue.opacity(0.1), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 8) {
                Text("Henüz Hiç Öğe Yok")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Bir şeyler kopyaladığınızda burada görünecek")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var filteredEmptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: clipboardManager.selectedCategory.icon)
                .font(.system(size: 50))
                .foregroundColor(clipboardManager.selectedCategory.color.opacity(0.6))
                .shadow(color: clipboardManager.selectedCategory.color.opacity(0.1), radius: 10, x: 0, y: 5)
            
            Text("Bu Kategoride Öğe Yok")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("\(clipboardManager.selectedCategory.rawValue) kategorisinde henüz öğe bulunmuyor")
                .font(.system(size: 14))
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
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            deleteItem(item)
                        }
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
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
        .background(Color.clear)
    }
    
    private func deleteItem(_ item: ClipboardItem) {
        clipboardManager.deleteItem(item)
    }
    
    private func togglePin(_ item: ClipboardItem) {
        clipboardManager.togglePinItem(item)
    }
}
