import SwiftUI

struct ClipboardView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    var onItemSelected: (String) -> Void
    var onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            AnimatedBackground()
            
            VStack(spacing: 0) {
                KeyboardHeaderView(
                    onDismiss: onDismiss,
                    onReturn: { onItemSelected("\n") },
                    onDelete: { onItemSelected("__DELETE__") },
                    onDeleteLongPress: { }
                )
                
                categoryFilterBar
                
                contentSection
            }
        }
        .onAppear {
            setupNotificationObserver()
        }
    }
    
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: clipboardManager.selectedCategory == category,
                        onTap: {
                            withAnimation {
                                clipboardManager.selectedCategory = category
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(colorScheme == .dark ? Color.black.opacity(0.1) : Color.white.opacity(0.7))
    }
    
    private var contentSection: some View {
        Group {
            if clipboardManager.clipboardItems.isEmpty {
                emptyStateView
            } else if clipboardManager.filteredItems.isEmpty {
                filteredEmptyView
            } else {
                itemsList
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 50))
                .foregroundColor(.blue.opacity(0.6))
                .shadow(color: .blue.opacity(0.1), radius: 10, x: 0, y: 5)
            
            Text("Henüz Kopyalanan Metin Yok")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Kopyaladığınız metinler burada görünecek")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
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
                        Label(item.isPinned ? "Sabitlemeyi Kaldır" : "Sabitle",
                              systemImage: item.isPinned ? "pin.slash" : "pin")
                    }
                    .tint(.blue)
                }
            }
            
            // Alt boşluk için görünmez öğe
            Color.clear
                .frame(height: 80)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .refreshable {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            clipboardManager.loadItems()
        }
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .clipboardManagerDataChanged,
            object: nil,
            queue: .main
        ) { _ in
            clipboardManager.loadItems()
        }
    }
    
    private func deleteItem(_ item: ClipboardItem) {
        clipboardManager.deleteItem(item)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func togglePin(_ item: ClipboardItem) {
        clipboardManager.togglePinItem(item)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}