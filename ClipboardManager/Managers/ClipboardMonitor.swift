import Foundation
import UIKit

class ClipboardMonitor {
    private var lastPasteboardChangeCount: Int = UIPasteboard.general.changeCount
    private var updateTimer: Timer?
    private let darwinNotificationManager = DarwinNotificationManager()
    
    weak var delegate: ClipboardMonitorDelegate?
    
    func startMonitoring() {
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
            self?.delegate?.clipboardDataChanged()
        }

        // Periyodik kontrol başlat
        updateTimer = Timer.scheduledTimer(withTimeInterval: Constants.pasteboardCheckInterval, repeats: true) { [weak self] _ in
            self?.checkPasteboardChanges()
        }

        // İlk açılışta mevcut panoyu kontrol et
        checkClipboard()
    }
    
    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self)
        updateTimer?.invalidate()
        darwinNotificationManager.stopObserving()
    }
    
    @objc private func checkClipboard() {
        checkPasteboardChanges()
    }
    
    private func checkPasteboardChanges() {
        let currentChangeCount = UIPasteboard.general.changeCount
        
        if currentChangeCount != lastPasteboardChangeCount {
            lastPasteboardChangeCount = currentChangeCount
            
            if let newText = UIPasteboard.general.string, !newText.isEmpty {
                delegate?.newClipboardContent(newText)
            }
        }
    }
}

protocol ClipboardMonitorDelegate: AnyObject {
    func newClipboardContent(_ text: String)
    func clipboardDataChanged()
}