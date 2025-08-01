import UIKit
import SwiftUI

// MARK: - Manager sınıfları için import'lar
// Manager'lar aynı target içinde olması nedeniyle otomatik olarak erişilebilir olmalıdır

class KeyboardViewController: UIInputViewController {
    var clipboardManager = ClipboardManager.shared
    var clipboardView: UIHostingController<ClipboardView>?
    var updateTimer: Timer?
    var lastPasteboardChangeCount: Int = 0
    var toastView: UIHostingController<ToastView>?
    let darwinNotificationManager = DarwinNotificationManager()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        lastPasteboardChangeCount = UIPasteboard.general.changeCount
        clipboardManager.loadItems()
        
        setupClipboardObservers()
        setupDarwinNotifications()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupKeyboardView()
        setupTapGesture()
        reloadAndSync()
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
        updateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        darwinNotificationManager.stopObserving()
    }
    
    // MARK: - Action Methods (Direct implementation)
    func handleItemSelection(_ text: String) {
        if text == "__DELETE__" {
            textDocumentProxy.deleteBackward()
        } else {
            textDocumentProxy.insertText(text)
        }
    }
    
    @objc func handleTapOutside(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        
        if let clipboardView = clipboardView?.view {
            let convertedLocation = view.convert(location, to: clipboardView)
            if !clipboardView.bounds.contains(convertedLocation) {
                advanceToNextInputMode()
            }
        }
    }
    
    @objc func checkPasteboardChanges() {
        let currentChangeCount = UIPasteboard.general.changeCount
        
        if currentChangeCount != lastPasteboardChangeCount {
            lastPasteboardChangeCount = currentChangeCount
            
            if let text = UIPasteboard.general.string, !text.isEmpty {
                if UIPasteboard.general.hasStrings {
                    DispatchQueue.main.async { [weak self] in
                        self?.clipboardManager.addItem(text)
                        self?.clipboardManager.saveItems()
                        self?.updateKeyboardView()
                    }
                }
            }
        }
    }
    
    @objc func handleClipboardManagerChanges(_ notification: Notification? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.clipboardManager.loadItems()
            self?.updateKeyboardView()
        }
    }
    
    func updateKeyboardView() {
        if let clipboardView = clipboardView {
            let selectedCategory = self.clipboardManager.selectedCategory
            
            clipboardView.rootView = ClipboardView(
                clipboardManager: clipboardManager,
                onItemSelected: { [weak self] text in
                    self?.handleItemSelection(text)
                },
                onDismiss: { [weak self] in
                    self?.advanceToNextInputMode()
                }
            )
            
            self.clipboardManager.selectedCategory = selectedCategory
        }
    }
    
    // MARK: - Setup Methods
    private func setupKeyboardView() {
        let hostingController = UIHostingController(
            rootView: ClipboardView(
                clipboardManager: ClipboardManager.shared,
                onItemSelected: { [weak self] text in
                    self?.handleItemSelection(text)
                },
                onDismiss: { [weak self] in
                    self?.advanceToNextInputMode()
                }
            )
        )
        self.clipboardView = hostingController
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        view.heightAnchor.constraint(equalToConstant: 274).isActive = true
    }
    
    private func setupClipboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkPasteboardChanges),
            name: UIPasteboard.changedNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClipboardManagerChanges),
            name: .clipboardManagerDataChanged,
            object: nil
        )
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkPasteboardChanges()
        }
    }
    
    private func setupDarwinNotifications() {
        darwinNotificationManager.startObserving(observer: self) { [weak self] in
            self?.clipboardManager.loadItems()
            self?.updateKeyboardView()
        }
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapOutside))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    private func reloadAndSync() {
        DispatchQueue.main.async { [weak self] in
            self?.clipboardManager.loadItems()
            self?.checkPasteboardChanges()
            self?.updateKeyboardView()
            self?.darwinNotificationManager.postNotification()
        }
    }
}