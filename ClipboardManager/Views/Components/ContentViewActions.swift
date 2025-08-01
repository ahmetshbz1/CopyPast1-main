import SwiftUI
import UIKit

struct ContentViewActions {
    let state: ContentViewState
    
    func deleteItem(_ item: ClipboardItem) {
        state.clipboardManager.deleteItem(item)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        state.showToastMessage("Öğe silindi")
    }
    
    func togglePin(_ item: ClipboardItem) {
        state.clipboardManager.togglePinItem(item)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        state.showToastMessage(item.isPinned ? "Sabitlendi" : "Sabitleme kaldırıldı")
    }
    
    func selectCategory(_ category: ItemCategory) {
        withAnimation {
            state.clipboardManager.selectedCategory = category
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func openBackgroundRefreshSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString + "/ClipboardManager") {
            UIApplication.shared.open(url)
        }
    }
    
    func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "isOnboardingCompleted")
        state.onboardingManager.isOnboardingCompleted = false
    }
}