import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {
    var clipboardManager = ClipboardManager.shared
    var clipboardView: UIHostingController<ClipboardView>?
    var updateTimer: Timer?
    var lastPasteboardChangeCount: Int = 0
    var toastView: UIHostingController<ToastView>?
    let darwinNotificationManager = DarwinNotificationManager()
    
    private lazy var setupManager = KeyboardSetupManager(viewController: self)
    private lazy var notificationHandler = KeyboardNotificationHandler(viewController: self)
    private lazy var actionHandler = KeyboardActionHandler(viewController: self)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        lastPasteboardChangeCount = UIPasteboard.general.changeCount
        clipboardManager.loadItems()
        
        notificationHandler.setupClipboardObservers()
        setupManager.setupDarwinNotifications()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupManager.setupKeyboardView()
        setupManager.setupTapGesture()
        actionHandler.reloadAndSync()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if let inputView = view as? UIInputView {
            inputView.frame.size.height = 291
        }
    }
    
    override func dismissKeyboard() {
        advanceToNextInputMode()
    }
    
    deinit {
        notificationHandler.removeObservers()
    }
    
    // MARK: - Action Methods (Exposed for managers)
    func handleItemSelection(_ text: String) {
        actionHandler.handleItemSelection(text)
    }
    
    @objc func handleTapOutside(_ gesture: UITapGestureRecognizer) {
        actionHandler.handleTapOutside(gesture)
    }
    
    @objc func checkPasteboardChanges() {
        actionHandler.checkPasteboardChanges()
    }
    
    @objc func handleClipboardManagerChanges(_ notification: Notification? = nil) {
        actionHandler.handleClipboardManagerChanges(notification)
    }
    
    func updateKeyboardView() {
        actionHandler.updateKeyboardView()
    }
}