import Foundation

public class DarwinNotificationManager {
    private weak var observer: AnyObject?
    private let notificationName: String
    private static var callbacks: [UnsafeRawPointer: () -> Void] = [:]
    
    public init(notificationName: String = Constants.darwinNotificationName) {
        self.notificationName = notificationName
    }
    
    public func startObserving(observer: AnyObject, callback: @escaping () -> Void) {
        self.observer = observer
        
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observerPtr = UnsafeRawPointer(Unmanaged.passUnretained(observer).toOpaque())
        let name = notificationName as CFString
        
        // Callback'i static dictionary'de sakla
        Self.callbacks[observerPtr] = callback
        
        CFNotificationCenterAddObserver(
            center,
            observerPtr,
            DarwinNotificationManager.darwinNotificationCallback,
            name,
            nil,
            .deliverImmediately
        )
    }
    
    public func postNotification() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = notificationName as CFString
        CFNotificationCenterPostNotification(center, CFNotificationName(name), nil, nil, true)
    }
    
    public func stopObserving() {
        guard let observer = observer else { return }
        
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observerPtr = UnsafeRawPointer(Unmanaged.passUnretained(observer).toOpaque())
        CFNotificationCenterRemoveObserver(center, observerPtr, nil, nil)
        
        // Callback'i temizle
        Self.callbacks.removeValue(forKey: observerPtr)
    }
    
    // C callback function
    private static let darwinNotificationCallback: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void = { _, observer, _, _, _ in
        guard let observer = observer else { return }
        
        if let callback = callbacks[UnsafeRawPointer(observer)] {
            DispatchQueue.main.async {
                callback()
            }
        }
    }
    
    deinit {
        stopObserving()
    }
}