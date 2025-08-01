import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {
    private var clipboardManager = ClipboardManager.shared
    private var clipboardView: UIHostingController<ClipboardView>?
    private var updateTimer: Timer?
    private var lastPasteboardChangeCount: Int = 0
    private var toastView: UIHostingController<ToastView>?
    private let darwinNotificationManager = DarwinNotificationManager()
    
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
        reloadAndSync()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
}

// MARK: - Setup Methods
extension KeyboardViewController {
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
        hostingController.view.transform = .identity
    }
    
    private func setupClipboardObservers() {
        // Pano değişikliklerini dinle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkPasteboardChanges),
            name: UIPasteboard.changedNotification,
            object: nil
        )
        
        // ClipboardManager değişikliklerini dinle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClipboardManagerChanges),
            name: .clipboardManagerDataChanged,
            object: nil
        )
        
        // Klavye görünür olduğunda yenile
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClipboardManagerChanges),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        // Başka bir bildirim daha ekleyelim
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClipboardManagerChanges),
            name: .clipboardItemAdded,
            object: nil
        )
        
        // Daha kısa aralıklarla kontrol et
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
}

// MARK: - Action Methods
extension KeyboardViewController {
    private func handleItemSelection(_ text: String) {
        if text == "__DELETE__" {
            textDocumentProxy.deleteBackward()
        } else {
            textDocumentProxy.insertText(text)
        }
    }
    
    private func reloadAndSync() {
        DispatchQueue.main.async { [weak self] in
            self?.clipboardManager.loadItems()
            self?.checkPasteboardChanges()
            self?.updateKeyboardView()
            
            // Darwin bildirimini zorla gönder
            self?.darwinNotificationManager.postNotification()
        }
    }
    
    @objc private func checkPasteboardChanges() {
        let currentChangeCount = UIPasteboard.general.changeCount
        
        if currentChangeCount != lastPasteboardChangeCount {
            lastPasteboardChangeCount = currentChangeCount
            
            if let text = UIPasteboard.general.string, !text.isEmpty {
                if UIPasteboard.general.hasStrings {
                    DispatchQueue.main.async { [weak self] in
                        self?.clipboardManager.addItem(text)
                        self?.clipboardManager.saveItems()
                        self?.updateKeyboardView()
                        self?.showToast(message: "Metin kaydedildi ✓")
                    }
                }
            }
        }
    }
    
    @objc private func handleClipboardManagerChanges(_ notification: Notification? = nil) {
        DispatchQueue.main.async { [weak self] in
            // Özel silme işlemi kontrolü
            if let userInfo = notification?.userInfo,
               let action = userInfo["action"] as? String,
               action == "delete",
               let itemIdString = userInfo["itemId"] as? String,
               let itemId = UUID(uuidString: itemIdString) {
                // Silinen öğeyi klavye eklentisinden de kaldır
                if let index = self?.clipboardManager.clipboardItems.firstIndex(where: { $0.id == itemId }) {
                    self?.clipboardManager.clipboardItems.remove(at: index)
                }
            }
            
            self?.clipboardManager.loadItems()
            self?.updateKeyboardView()
        }
    }
    
    private func updateKeyboardView() {
        if let clipboardView = clipboardView {
            // Mevcut seçilen kategoriyi hatırla
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
            
            // Kategori seçimini koru
            self.clipboardManager.selectedCategory = selectedCategory
        }
    }
}

// MARK: - Toast Methods
extension KeyboardViewController {
    private func showToast(message: String) {
        // Varolan toast'u kaldır
        toastView?.view.removeFromSuperview()
        toastView?.removeFromParent()
        
        // Yeni toast oluştur
        let hostingController = UIHostingController(rootView: ToastView(message: message))
        self.toastView = hostingController
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 10)
        ])
        
        // Animasyon ile göster
        hostingController.view.alpha = 0
        UIView.animate(withDuration: 0.3) {
            hostingController.view.alpha = 1
        }
        
        // 2 saniye sonra kaldır
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            UIView.animate(withDuration: 0.3, animations: {
                self?.toastView?.view.alpha = 0
            }) { _ in
                self?.toastView?.view.removeFromSuperview()
                self?.toastView?.removeFromParent()
            }
        }
    }
}