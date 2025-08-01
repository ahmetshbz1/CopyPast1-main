import UIKit
import Foundation

class KeyboardNotificationHandler {
    weak var viewController: KeyboardViewController?
    
    init(viewController: KeyboardViewController) {
        self.viewController = viewController
    }
    
    func setupClipboardObservers() {
        guard let viewController = viewController else { return }
        
        // Pano değişikliklerini dinle
        NotificationCenter.default.addObserver(
            viewController,
            selector: #selector(KeyboardViewController.checkPasteboardChanges),
            name: UIPasteboard.changedNotification,
            object: nil
        )
        
        // ClipboardManager değişikliklerini dinle
        NotificationCenter.default.addObserver(
            viewController,
            selector: #selector(KeyboardViewController.handleClipboardManagerChanges),
            name: .clipboardManagerDataChanged,
            object: nil
        )
        
        // Klavye görünür olduğunda yenile
        NotificationCenter.default.addObserver(
            viewController,
            selector: #selector(KeyboardViewController.handleClipboardManagerChanges),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        // Başka bir bildirim daha ekleyelim
        NotificationCenter.default.addObserver(
            viewController,
            selector: #selector(KeyboardViewController.handleClipboardManagerChanges),
            name: .clipboardItemAdded,
            object: nil
        )
        
        // Daha kısa aralıklarla kontrol et
        viewController.updateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak viewController] _ in
            viewController?.checkPasteboardChanges()
        }
    }
    
    func removeObservers() {
        NotificationCenter.default.removeObserver(viewController as Any)
        viewController?.updateTimer?.invalidate()
        viewController?.darwinNotificationManager.stopObserving()
    }
}