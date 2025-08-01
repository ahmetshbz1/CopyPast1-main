import Foundation
import SwiftUI
import UIKit

public class ClipboardManager: ObservableObject {
    public static let shared = ClipboardManager()

    @Published public var clipboardItems: [ClipboardItem] = []
    @Published public var selectedCategory: ItemCategory = .all
    public let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

    private var lastCopiedText: String?
    private var lastPasteboardChangeCount: Int = UIPasteboard.general.changeCount
    private var updateTimer: Timer?
    private let darwinNotificationManager = DarwinNotificationManager()

    private init() {
        loadItems()
        startMonitoring()
    }

    private func startMonitoring() {
        // Pano değişikliklerini dinle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkClipboard),
            name: UIPasteboard.changedNotification,
            object: nil
        )

        // Uygulama arka plandan öne geldiğinde kontrol et
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkClipboard),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // Darwin bildirimlerini dinle
        darwinNotificationManager.startObserving(observer: self) { [weak self] in
            self?.loadItems()
        }

        // Periyodik kontrol başlat
        updateTimer = Timer.scheduledTimer(withTimeInterval: Constants.pasteboardCheckInterval, repeats: true) { [weak self] _ in
            self?.checkPasteboardChanges()
        }

        // İlk açılışta mevcut panoyu kontrol et
        checkClipboard()
    }

    @objc private func checkPasteboardChanges() {
        let currentChangeCount = UIPasteboard.general.changeCount

        if currentChangeCount != lastPasteboardChangeCount {
            lastPasteboardChangeCount = currentChangeCount
            checkClipboard()
        }
    }

    @objc private func checkClipboard() {
        if let text = UIPasteboard.general.string,
           !text.isEmpty && text != lastCopiedText {
            // Sadece kullanıcının kopyaladığı metinleri kaydet
            if UIPasteboard.general.hasStrings {
                lastCopiedText = text
                DispatchQueue.main.async {
                    self.addItem(text)

                    // Değişiklikleri hemen kaydet - klavye eklentisiyle senkronizasyon için önemli
                    self.saveItems()

                    // Darwin bildirimini zorla gönder
                    self.darwinNotificationManager.postNotification()
                }
            }
        }
    }

    public var filteredItems: [ClipboardItem] {
        switch selectedCategory {
        case .all:
            return clipboardItems
        case .pinned:
            return clipboardItems.filter { $0.isPinned }
        case .text, .link, .email, .phone, .short:
            return clipboardItems.filter { $0.category == selectedCategory }
        }
    }

    public func addItem(_ text: String) {
        let item = ClipboardItem(text: text)

        // Aynı metin zaten varsa, eski olanı sil
        if let existingIndex = clipboardItems.firstIndex(where: { $0.text == text }) {
            clipboardItems.remove(at: existingIndex)
        }

        clipboardItems.insert(item, at: 0)

        if clipboardItems.count > Constants.maxClipboardItems {
            clipboardItems.removeLast()
        }

        // Bildirim yayınla
        NotificationCenter.default.post(name: .clipboardItemAdded, object: nil)
    }

    public func loadItems() {
        if let data = userDefaults?.data(forKey: Constants.clipboardItemsKey),
           let items = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            clipboardItems = items
            lastCopiedText = items.first?.text
        }
    }

    public func saveItems() {
        if let data = try? JSONEncoder().encode(clipboardItems) {
            userDefaults?.set(data, forKey: Constants.clipboardItemsKey)
            userDefaults?.synchronize()

            // Veri değişikliğini hemen bildir
            DispatchQueue.main.async {
                self.notifyClipboardChanged()

                // Darwin bildirimini de gönder
                self.darwinNotificationManager.postNotification()
            }
        }
    }

    public func updateItem(_ item: ClipboardItem, newText: String) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems[index].text = newText
            saveItems()
        }
    }

    public func shareItem(_ item: ClipboardItem) {
        // Paylaşım işlemi view tarafında yapılacak
    }

    public func deleteItem(_ item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems.remove(at: index)
            saveItems()

            // Ana uygulamaya ve klavye eklentisine özel bildirim gönder
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

            // Değişiklikleri hemen yükle
            self.loadItems()

            // Diğer hedeflere de bildir
            NotificationCenter.default.post(name: .clipboardItemAdded, object: nil)
        }
    }

    deinit {
        updateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        darwinNotificationManager.stopObserving()
    }
}
