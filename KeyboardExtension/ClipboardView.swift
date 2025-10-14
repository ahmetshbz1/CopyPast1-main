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
                
                KeyboardContentView(
                    clipboardManager: clipboardManager,
                    onItemSelected: onItemSelected
                )
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
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .clipboardManagerDataChanged,
            object: nil,
            queue: .main
        ) { _ in
            clipboardManager.loadItems()
        }
    }
}

// MARK: - Computed Properties Extension
extension ClipboardManager {
    var filteredItems: [ClipboardItem] {
        switch selectedCategory {
        case .all:
            return clipboardItems
        case .pinned:
            return clipboardItems.filter { $0.isPinned }
        case .favorite:
            return clipboardItems.filter { $0.isFavorite }
        default:
            return clipboardItems.filter { $0.category == selectedCategory }
        }
    }
}

#Preview {
    ClipboardView(
        clipboardManager: ClipboardManager.shared,
        onItemSelected: { _ in },
        onDismiss: { }
    )
}