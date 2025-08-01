import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var clipboardManager = ClipboardManager.shared
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showAboutSheet = false
    @State private var searchText = ""
    @Environment(\.colorScheme) private var colorScheme
    
    var filteredItems: [ClipboardItem] {
        var items = clipboardManager.clipboardItems
        
        // Kategori filtrelemesi
        if clipboardManager.selectedCategory != .all {
            if clipboardManager.selectedCategory == .pinned {
                items = items.filter { $0.isPinned }
            } else {
                items = items.filter { $0.category == clipboardManager.selectedCategory }
            }
        }
        
        // Arama filtrelemesi
        if !searchText.isEmpty {
            items = items.filter { item in
                item.text.localizedCaseInsensitiveContains(searchText)
            }
        } else {
            let pinnedItems = items.filter { $0.isPinned }
            let unpinnedItems = items.filter { !$0.isPinned }
            items = pinnedItems + unpinnedItems
        }
        
        return items
    }
    
    var body: some View {
        Group {
            if !onboardingManager.isOnboardingCompleted {
                OnboardingView(onboardingManager: onboardingManager)
            } else {
                mainContentView
            }
        }
        .onAppear {
            setupNotificationObserver()
        }
        .sheet(isPresented: $showAboutSheet) {
            AboutView(showAboutSheet: $showAboutSheet)
        }
    }
    
    private var mainContentView: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                
                VStack(spacing: 0) {
                    if !clipboardManager.clipboardItems.isEmpty {
                        headerSection
                    }
                    
                    contentSection
                    
                    if showToast {
                        ToastView(message: toastMessage)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .offset(y: 10)
                    }
                }
            }
            .navigationTitle("Pano Geçmişi")
            .toolbar {
                toolbarContent
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
    
    private var headerSection: some View {
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
    
    private var contentSection: some View {
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
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .refreshable {
            clipboardManager.loadItems()
        }
    }
    
}

// MARK: - ContentView Extensions
extension ContentView {
    var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if !clipboardManager.clipboardItems.isEmpty {
                Button(action: {
                    withAnimation(.spring()) {
                        clipboardManager.clearAllItems()
                        searchText = ""
                    }
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            
            Menu {
                Button(action: {
                    UserDefaults.standard.removeObject(forKey: "isOnboardingCompleted")
                    onboardingManager.isOnboardingCompleted = false
                }) {
                    Label("Kurulum Sihirbazı", systemImage: "wand.and.stars")
                }
                
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Klavye Ayarları", systemImage: "keyboard")
                }
                
                Divider()
                
                Button(action: {
                    showAboutSheet = true
                }) {
                    Label("Hakkında", systemImage: "info.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .medium))
            }
        }
    }
    
    func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .clipboardManagerDataChanged,
            object: nil,
            queue: .main
        ) { _ in
            clipboardManager.loadItems()
        }
    }
    
    func showToastMessage(_ message: String) {
        withAnimation {
            self.toastMessage = message
            self.showToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                self.showToast = false
            }
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        clipboardManager.deleteItem(item)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showToastMessage("Öğe silindi")
    }
    
    func togglePin(_ item: ClipboardItem) {
        clipboardManager.togglePinItem(item)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showToastMessage(item.isPinned ? "Sabitleme kaldırıldı" : "Sabitlendi")
    }
}

#Preview {
    ContentView()
}