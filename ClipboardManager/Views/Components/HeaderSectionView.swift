import SwiftUI

struct HeaderSectionView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var searchText: String
    
    var body: some View {
        VStack(spacing: 8) {
            SearchBar(text: $searchText)
                .padding(.horizontal)
                .padding(.top, 10)
            
            categoryFilterBar
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
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
}