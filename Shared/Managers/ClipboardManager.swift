import Foundation
import SwiftUI
import UIKit

public class ClipboardManager: ObservableObject {
    public static let shared = ClipboardManager()
    
    @Published public var clipboardItems: [ClipboardItem] = []
    @Published public var selectedCategory: ItemCategory = .all
    public let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
    
    private let monitor = ClipboardMonitor()
    
    private init() {
        loadItems()
        setupMonitoring()
    }
    
    private func setupMonitoring() {
        monitor.delegate = self
        monitor.startMonitoring()
    }
    
    public func addItem(_ text: String) {
        let item = ClipboardItem(text: text)
        
        if let existingIndex = clipboardItems.firstIndex(where: { $0.text == text }) {
            clipboardItems.remove(at: existingIndex)
        }
        
        clipboardItems.insert(item, at: 0)
        
        if clipboardItems.count > Constants.maxClipboardItems {
            clipboardItems.removeLast()
        }
        
        NotificationCenter.default.post(name: .clipboardItemAdded, object: nil)
    }
    
    public func loadItems() {
        if let data = userDefaults?.data(forKey: Constants.clipboardItemsKey),
           let items = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            clipboardItems = items
        }
    }
    
    public func saveItems() {
        if let data = try? JSONEncoder().encode(clipboardItems) {
            userDefaults?.set(data, forKey: Constants.clipboardItemsKey)
            userDefaults?.synchronize()
            
            DispatchQueue.main.async {
                self.notifyClipboardChanged()
                self.monitor.postDarwinNotification()
            }
        }
    }
    
    public func updateItem(_ item: ClipboardItem, newText: String) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems[index].text = newText
            saveItems()
        }
    }
    
    public func deleteItem(_ item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems.remove(at: index)
            saveItems()
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .clipboardManagerDataChanged, object: nil, userInfo: ["action": "delete", "itemId": item.id.uuidString])
            }
        }
    }
    
    public func togglePinItem(_ item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems[index].isPinned.toggle()
            saveItems()
            notifyClipboardChanged()
        }
    }
    
    public func clearAllItems() {
        clipboardItems.removeAll()
        userDefaults?.removeObject(forKey: Constants.clipboardItemsKey)
        notifyClipboardChanged()
    }
    
    private func notifyClipboardChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clipboardManagerDataChanged, object: nil)
            self.loadItems()
            NotificationCenter.default.post(name: .clipboardItemAdded, object: nil)
        }
    }
    
}

// MARK: - ClipboardMonitorDelegate
extension ClipboardManager: ClipboardMonitorDelegate {
    func clipboardMonitor(_ monitor: ClipboardMonitor, didDetectNewText text: String) {
        DispatchQueue.main.async {
            self.addItem(text)
            self.saveItems()
            self.monitor.postDarwinNotification()
        }
    }
    
    func clipboardMonitorDidReceiveDarwinNotification() {
        loadItems()
    }
}