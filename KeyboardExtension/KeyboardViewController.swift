import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {
    // MARK: - Properties
    var clipboardManager = ClipboardManager.shared
    var clipboardView: UIHostingController<ClipboardView>?
    var updateTimer: Timer?
    var lastPasteboardChangeCount: Int = 0
    var toastView: UIHostingController<ToastView>?
    let darwinNotificationManager = DarwinNotificationManager()
    
    // MARK: - Managers
    private lazy var setupManager = KeyboardSetupManager(viewController: self)
    private lazy var notificationHandler = KeyboardNotificationHandler(viewController: self)
    private lazy var actionHandler = KeyboardActionHandler(viewController: self)
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeKeyboard()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboardInterface()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        configureKeyboardHeight()
    }
    
    override func dismissKeyboard() {
        advanceToNextInputMode()
    }
    
    deinit {
        notificationHandler.removeObservers()
    }
    
    // MARK: - Public Methods (Exposed for managers)
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
    
    // MARK: - Private Methods
    private func initializeKeyboard() {
        lastPasteboardChangeCount = UIPasteboard.general.changeCount
        clipboardManager.loadItems()
        notificationHandler.setupClipboardObservers()
        setupManager.setupDarwinNotifications()
    }
    
    private func setupKeyboardInterface() {
        setupManager.setupKeyboardView()
        setupManager.setupTapGesture()
        actionHandler.reloadAndSync()
    }
    
    private func configureKeyboardHeight() {
        if let inputView = view as? UIInputView {
            inputView.frame.size.height = 291
        }
    }
}