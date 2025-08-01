import Foundation

class ClipboardDataManager {
    private let userDefaults: UserDefaults?
    
    init() {
        self.userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
    }
    
    func saveItems(_ items: [ClipboardItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults?.set(data, forKey: Constants.clipboardItemsKey)
            
            // Darwin bildirimini gönder
            let darwinManager = DarwinNotificationManager()
            darwinManager.postNotification()
        } catch {
            print("Veri kaydetme hatası: \(error)")
        }
    }
    
    func loadItems() -> [ClipboardItem] {
        guard let data = userDefaults?.data(forKey: Constants.clipboardItemsKey) else {
            return []
        }
        
        do {
            let items = try JSONDecoder().decode([ClipboardItem].self, from: data)
            return items.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("Veri yükleme hatası: \(error)")
            return []
        }
    }
    
    func clearAllData() {
        userDefaults?.removeObject(forKey: Constants.clipboardItemsKey)
        
        // Darwin bildirimini gönder
        let darwinManager = DarwinNotificationManager()
        darwinManager.postNotification()
    }
}