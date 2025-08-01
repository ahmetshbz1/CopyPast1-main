import Foundation

// Bildirim adlarını tanımla
public extension Notification.Name {
    static let clipboardItemAdded = Notification.Name("clipboardItemAdded")
    static let clipboardManagerDataChanged = Notification.Name("ClipboardManagerDataChanged")
}