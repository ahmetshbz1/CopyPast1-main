import SwiftUI

@MainActor
class ContentViewState: ObservableObject {
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var showAboutSheet = false
    @Published var searchText = ""
    
    let clipboardManager = ClipboardManager.shared
    let onboardingManager = OnboardingManager()
    
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
    
    func clearAllItems() {
        withAnimation(.spring()) {
            clipboardManager.clearAllItems()
            searchText = ""
        }
    }
    
    func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .clipboardManagerDataChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clipboardManager.loadItems()
        }
    }
}