import SwiftUI
import UIKit

// Klavye izinlerini kontrol etmek için extension
extension UIInputViewController {
    static var hasKeyboardAccess: Bool {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let keyboardId = "\(bundleId).keyboard"
        
        if let keyboards = UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String] {
            return keyboards.contains(keyboardId)
        }
        return false
    }
}

class OnboardingPermissionManager: ObservableObject {
    @Published var keyboardPermissionGranted = false
    @Published var backgroundRefreshGranted = false
    
    func checkKeyboardPermissions() {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let keyboardId = "\(bundleId).keyboard"
        
        // Aktif klavyeleri kontrol et
        if let keyboards = UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String] {
            let isKeyboardEnabled = keyboards.contains(keyboardId)
            print("🔍 Aktif Klavyeler:", keyboards)
            print("📱 Bizim Klavye ID:", keyboardId)
            print("✅ Klavye Aktif mi?:", isKeyboardEnabled)
            
            // Tam erişim iznini kontrol et
            let hasFullAccess = UIPasteboard.general.hasStrings || UIPasteboard.general.hasURLs || UIPasteboard.general.hasImages
            print("🔑 Tam Erişim Var mı?:", hasFullAccess)
            
            keyboardPermissionGranted = isKeyboardEnabled && hasFullAccess
            print("🎯 Final Durum (keyboardPermissionGranted):", keyboardPermissionGranted)
        } else {
            print("❌ Klavye listesi alınamadı!")
            keyboardPermissionGranted = false
        }
    }
    
    func checkBackgroundRefreshPermissions() {
        let status = UIApplication.shared.backgroundRefreshStatus
        backgroundRefreshGranted = status == .available
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func openBackgroundSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString + "/ClipboardManager") {
            UIApplication.shared.open(url)
        }
    }
}