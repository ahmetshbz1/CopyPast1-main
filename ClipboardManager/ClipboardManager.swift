import Foundation
import SwiftUI
import UIKit

public class ClipboardManager: ObservableObject {
    public static let shared = ClipboardManager()

    @Published public var clipboardItems: [ClipboardItem] = []
    @Published public var selectedCategory: ItemCategory = .all
    
    private var lastCopiedText: String?
    private let dataManager = ClipboardDataManager()
    private let monitor = ClipboardMonitor()

    private init() {
        loadItems()
        setupMonitoring()
    }
    
    private func setupMonitoring() {
        monitor.delegate = self
        monitor.startMonitoring()
    }

    public func loadItems() {
        clipboardItems = dataManager.loadItems()
        
        // UI güncellemesi için bildirim gönder
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clipboardManagerDataChanged, object: nil)
        }
    }

    public func addItem(text: String) {
        // Boş veya aynı text kontrolü
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, trimmedText != lastCopiedText else { return }
        
        lastCopiedText = trimmedText
        
        // Mevcut öğeyi kaldır (varsa)
        clipboardItems.removeAll { $0.text == trimmedText }
        
        // Kategoriyi belirle
        let category = CategoryDeterminer.determineCategory(for: trimmedText)
        
        // Yeni öğe oluştur
        let newItem = ClipboardItem(
            text: trimmedText,
            category: category,
            createdAt: Date()
        )
        
        // Listenin başına ekle
        clipboardItems.insert(newItem, at: 0)
        
        // Maksimum sayıyı kontrol et
        if clipboardItems.count > Constants.maxClipboardItems {
            clipboardItems = Array(clipboardItems.prefix(Constants.maxClipboardItems))
        }
        
        // Kaydet
        dataManager.saveItems(clipboardItems)
        
        // Bildirim gönder
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clipboardItemAdded, object: newItem)
        }
    }
    
    public func deleteItem(_ item: ClipboardItem) {
        clipboardItems.removeAll { $0.id == item.id }
        dataManager.saveItems(clipboardItems)
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clipboardManagerDataChanged, object: nil)
        }
    }
    
    public func updateItem(_ item: ClipboardItem, newText: String) {
        guard let index = clipboardItems.firstIndex(where: { $0.id == item.id }) else { return }
        
        let trimmedText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        let category = CategoryDeterminer.determineCategory(for: trimmedText)
        
        clipboardItems[index] = ClipboardItem(
            id: item.id,
            text: trimmedText,
            category: category,
            createdAt: item.createdAt,
            updatedAt: Date()
        )
        
        dataManager.saveItems(clipboardItems)
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clipboardManagerDataChanged, object: nil)
        }
    }
    
    public func clearAllItems() {
        clipboardItems.removeAll()
        dataManager.clearAllData()
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clipboardManagerDataChanged, object: nil)
        }
    }
    
    public func getItemsByCategory(_ category: ItemCategory, searchText: String = "") -> [ClipboardItem] {
        var filteredItems = clipboardItems
        
        // Kategori filtresi
        if category != .all {
            filteredItems = filteredItems.filter { $0.category == category }
        }
        
        // Arama filtresi
        if !searchText.isEmpty {
            filteredItems = filteredItems.filter { 
                $0.text.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filteredItems
    }
    
    deinit {
        monitor.stopMonitoring()
    }
}

// MARK: - ClipboardMonitorDelegate
extension ClipboardManager: ClipboardMonitorDelegate {
    func newClipboardContent(_ text: String) {
        addItem(text: text)
    }
    
    func clipboardDataChanged() {
        loadItems()
    }
}