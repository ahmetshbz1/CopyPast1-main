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
                        HeaderSectionView(
                            clipboardManager: clipboardManager,
                            searchText: $searchText
                        )
                    }
                    
                    ContentSectionView(
                        clipboardManager: clipboardManager,
                        filteredItems: filteredItems,
                        searchText: searchText,
                        showToastMessage: showToastMessage,
                        onDeleteItem: deleteItem,
                        onTogglePin: togglePin
                    )
                    
                    if showToast {
                        ToastView(message: toastMessage)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .offset(y: 10)
                    }
                }
            }
            .navigationTitle("Pano Geçmişi")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !clipboardManager.clipboardItems.isEmpty {
                        Button(action: {
                            withAnimation(.spring()) {
                                clearAllItems()
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
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}

// MARK: - ContentView Helper Functions
extension ContentView {
    
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
    
    func clearAllItems() {
        clipboardManager.clearAllItems()
    }
}

#Preview {
    ContentView()
}