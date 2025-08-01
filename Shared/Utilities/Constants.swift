import Foundation

public struct Constants {
    // MARK: - App Configuration
    public static let maxClipboardItems = 50
    public static let appGroupIdentifier = "group.com.ahmtcanx.clipboardmanager"
    public static let clipboardItemsKey = "clipboardItems"
    
    // MARK: - iOS 18+ Optimized Settings
    /// Pasteboard check interval optimized for iOS 18+ privacy
    public static let pasteboardCheckInterval: TimeInterval = 1.0 // Increased for privacy compliance
    
    /// Maximum access rate per minute for iOS 18+ privacy
    public static let maxPasteboardAccessPerMinute = 30
    
    // MARK: - Notifications
    public static let darwinNotificationName = "com.ahmtcanx.clipboardmanager.dataChanged"
    
    // MARK: - Background Task Identifiers
    public static let backgroundRefreshTaskIdentifier = "com.clipboardmanager.refresh"
    
    // MARK: - Performance Settings
    public static let maxTextLength = 10000 // Prevent memory issues with very long texts
    public static let debounceInterval: TimeInterval = 0.3 // UI update debouncing
}