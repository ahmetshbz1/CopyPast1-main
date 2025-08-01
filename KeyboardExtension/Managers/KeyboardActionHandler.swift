import UIKit
import SwiftUI

class KeyboardActionHandler {
    weak var viewController: KeyboardViewController?
    
    init(viewController: KeyboardViewController) {
        self.viewController = viewController
    }
    
    func handleItemSelection(_ text: String) {
        guard let viewController = viewController else { return }
        
        if text == "__DELETE__" {
            viewController.textDocumentProxy.deleteBackward()
        } else {
            viewController.textDocumentProxy.insertText(text)
        }
    }
    
    func handleTapOutside(_ gesture: UITapGestureRecognizer) {
        guard let viewController = viewController else { return }
        
        let location = gesture.location(in: viewController.view)
        
        // Eğer tıklama klavye view'ının dışındaysa klavyeyi kapat
        if let clipboardView = viewController.clipboardView?.view {
            let convertedLocation = viewController.view.convert(location, to: clipboardView)
            if !clipboardView.bounds.contains(convertedLocation) {
                viewController.advanceToNextInputMode()
            }
        }
    }
    
    func reloadAndSync() {
        guard let viewController = viewController else { return }
        
        DispatchQueue.main.async { [weak viewController] in
            viewController?.clipboardManager.loadItems()
            viewController?.checkPasteboardChanges()
            viewController?.updateKeyboardView()
            
            // Darwin bildirimini zorla gönder
            viewController?.darwinNotificationManager.postNotification()
        }
    }
    
    func checkPasteboardChanges() {
        guard let viewController = viewController else { return }
        
        let currentChangeCount = UIPasteboard.general.changeCount
        
        if currentChangeCount != viewController.lastPasteboardChangeCount {
            viewController.lastPasteboardChangeCount = currentChangeCount
            
            if let text = UIPasteboard.general.string, !text.isEmpty {
                if UIPasteboard.general.hasStrings {
                    DispatchQueue.main.async { [weak viewController] in
                        viewController?.clipboardManager.addItem(text)
                        viewController?.clipboardManager.saveItems()
                        viewController?.updateKeyboardView()
                        KeyboardToastManager(viewController: viewController).showToast(message: "Metin kaydedildi ✓")
                    }
                }
            }
        }
    }
    
    func handleClipboardManagerChanges(_ notification: Notification? = nil) {
        guard let viewController = viewController else { return }
        
        DispatchQueue.main.async { [weak viewController] in
            // Özel silme işlemi kontrolü
            if let userInfo = notification?.userInfo,
               let action = userInfo["action"] as? String,
               action == "delete",
               let itemIdString = userInfo["itemId"] as? String,
               let itemId = UUID(uuidString: itemIdString) {
                // Silinen öğeyi klavye eklentisinden de kaldır
                if let index = viewController?.clipboardManager.clipboardItems.firstIndex(where: { $0.id == itemId }) {
                    viewController?.clipboardManager.clipboardItems.remove(at: index)
                }
            }
            
            viewController?.clipboardManager.loadItems()
            viewController?.updateKeyboardView()
        }
    }
    
    func updateKeyboardView() {
        guard let viewController = viewController else { return }
        
        if let clipboardView = viewController.clipboardView {
            // Mevcut seçilen kategoriyi hatırla
            let selectedCategory = viewController.clipboardManager.selectedCategory
            
            clipboardView.rootView = ClipboardView(
                clipboardManager: viewController.clipboardManager,
                onItemSelected: { [weak viewController] text in
                    viewController?.handleItemSelection(text)
                },
                onDismiss: { [weak viewController] in
                    viewController?.advanceToNextInputMode()
                }
            )
            
            // Kategori seçimini koru
            viewController.clipboardManager.selectedCategory = selectedCategory
        }
    }
}