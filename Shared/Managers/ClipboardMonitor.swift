import Foundation
import UIKit

/// Handles pasteboard monitoring and change detection
internal class ClipboardMonitor {
    private var lastCopiedText: String?
    private var lastPasteboardChangeCount: Int = UIPasteboard.general.changeCount
    private var updateTimer: Timer?
    private let darwinNotificationManager = DarwinNotificationManager()
    
    weak var delegate: ClipboardMonitorDelegate?
    
    func startMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkClipboard),
            name: UIPasteboard.changedNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkClipboard),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        darwinNotificationManager.startObserving(observer: self) { [weak self] in
            self?.delegate?.clipboardMonitorDidReceiveDarwinNotification()
        }
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: Constants.pasteboardCheckInterval, repeats: true) { [weak self] _ in
            self?.checkPasteboardChanges()
        }
        
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
            if UIPasteboard.general.hasStrings {
                lastCopiedText = text
                delegate?.clipboardMonitor(self, didDetectNewText: text)
            }
        }
    }
    
    func postDarwinNotification() {
        darwinNotificationManager.postNotification()
    }
    
    deinit {
        updateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        darwinNotificationManager.stopObserving()
    }
}

protocol ClipboardMonitorDelegate: AnyObject {
    func clipboardMonitor(_ monitor: ClipboardMonitor, didDetectNewText text: String)
    func clipboardMonitorDidReceiveDarwinNotification()
}