import Foundation
import UIKit
import UserNotifications
import CoreSpotlight
import UniformTypeIdentifiers

// Not: Siri Intent handler'lar kaldırıldı. Production'da .intentdefinition eklenip oluşturulan tipler hazır olduğunda eklenebilir.

// Automation Engine
public class AutomationEngine: ObservableObject {
    
    @Published public var automationRules: [AutomationRule] = []
    
    public init() {
        loadAutomationRules()
    }
    
    public func addAutomationRule(_ rule: AutomationRule) {
        automationRules.append(rule)
        saveAutomationRules()
    }
    
    public func removeAutomationRule(_ rule: AutomationRule) {
        automationRules.removeAll { $0.id == rule.id }
        saveAutomationRules()
    }
    
    public func processClipboardItem(_ item: ClipboardItem) {
        for rule in automationRules where rule.isEnabled {
            if rule.condition.matches(item) {
                executeAction(rule.action, for: item)
            }
        }
    }
    
    private func executeAction(_ action: AutomationAction, for item: ClipboardItem) {
        switch action {
        case .addTag(let tag):
            ClipboardManager.shared.addTag(tag, to: item)
        case .pin:
            ClipboardManager.shared.togglePinItem(item)
        case .favorite:
            ClipboardManager.shared.toggleFavoriteItem(item)
        case .delete:
            ClipboardManager.shared.deleteItem(item)
        case .copyToPasteboard:
            UIPasteboard.general.string = item.text
        case .sendNotification(let message):
            sendLocalNotification(message: message, for: item)
        case .runShortcut(let shortcutName):
            runShortcut(named: shortcutName, with: item)
        }
    }
    
    private func sendLocalNotification(message: String, for item: ClipboardItem) {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Clipboard Automation"
        content.body = message
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: "automation-\(item.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        center.add(request)
    }
    
    private func runShortcut(named shortcutName: String, with item: ClipboardItem) {
        // iOS Shortcuts app ile entegrasyon (URL Scheme)
        let urlString = "shortcuts://run-shortcut?name=\(shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func loadAutomationRules() {
        if let data = UserDefaults.standard.data(forKey: "automationRules"),
           let rules = try? JSONDecoder().decode([AutomationRule].self, from: data) {
            automationRules = rules
        }
    }
    
    private func saveAutomationRules() {
        if let data = try? JSONEncoder().encode(automationRules) {
            UserDefaults.standard.set(data, forKey: "automationRules")
        }
    }
}

// Automation Models
public struct AutomationRule: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var condition: AutomationCondition
    public var action: AutomationAction
    public var isEnabled: Bool
    
    public init(name: String, condition: AutomationCondition, action: AutomationAction) {
        self.id = UUID()
        self.name = name
        self.condition = condition
        self.action = action
        self.isEnabled = true
    }
}

public enum AutomationCondition: Codable {
    case containsText(String)
    case hasCategory(ItemCategory)
    case hasMediaType(MediaType)
    case isFromApp(String)
    case textLength(ComparisonOperator, Int)
    case hasKeywords([String])
    
    public func matches(_ item: ClipboardItem) -> Bool {
        switch self {
        case .containsText(let text):
            return item.text.localizedCaseInsensitiveContains(text)
        case .hasCategory(let category):
            return item.category == category
        case .hasMediaType:
            // ClipboardItem modelinde mediaType bilgisi yok.
            return false
        case .isFromApp:
            // Kaynak uygulama bilgisi tutulmuyor.
            return false
        case .textLength(let op, let length):
            switch op {
            case .greaterThan: return item.text.count > length
            case .lessThan: return item.text.count < length
            case .equalTo: return item.text.count == length
            }
        case .hasKeywords(let keywords):
            return keywords.allSatisfy { keyword in
                item.text.localizedCaseInsensitiveContains(keyword)
            }
        }
    }
}

public enum AutomationAction: Codable {
    case addTag(String)
    case pin
    case favorite
    case delete
    case copyToPasteboard
    case sendNotification(String)
    case runShortcut(String)
    
    public var displayName: String {
        switch self {
        case .addTag(let tag): return "Etiket ekle: \(tag)"
        case .pin: return "Sabitle"
        case .favorite: return "Favorile"
        case .delete: return "Sil"
        case .copyToPasteboard: return "Panoya kopyala"
        case .sendNotification(let message): return "Bildirim gönder: \(message)"
        case .runShortcut(let name): return "Shortcut çalıştır: \(name)"
        }
    }
}

public enum ComparisonOperator: String, Codable, CaseIterable {
    case greaterThan = ">"
    case lessThan = "<"
    case equalTo = "="
    
    public var displayName: String {
        switch self {
        case .greaterThan: return "Büyük"
        case .lessThan: return "Küçük"
        case .equalTo: return "Eşit"
        }
    }
}

// Shortcuts Provider - Siri önerileri için (Core Spotlight etkin)
public class ShortcutsProvider {
    
    public static func donateGetRecentItemsActivity() {
        let activity = NSUserActivity(activityType: "com.ahmtcanx.clipboardmanager.getRecentItems")
        activity.title = "Son Kopyalanan Öğeleri Al"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = "getRecentItems"
        
        let attributes = CSSearchableItemAttributeSet(itemContentType: UTType.plainText.identifier)
        attributes.title = "Son Kopyalanan Öğeleri Al"
        attributes.contentDescription = "Panoda son kopyalanan öğeleri gösterir"
        
        activity.contentAttributeSet = attributes
        activity.becomeCurrent()
    }
    
    public static func donateSearchActivity(query: String) {
        let activity = NSUserActivity(activityType: "com.ahmtcanx.clipboardmanager.search")
        activity.title = "Panoda Ara: \(query)"
        activity.userInfo = ["query": query]
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        
        let attributes = CSSearchableItemAttributeSet(itemContentType: UTType.plainText.identifier)
        attributes.title = "Panoda Ara"
        attributes.contentDescription = "Pano geçmişinde \(query) ara"
        
        activity.contentAttributeSet = attributes
        activity.becomeCurrent()
    }
    
    public static func donateSaveTextActivity(text: String) {
        let activity = NSUserActivity(activityType: "com.ahmtcanx.clipboardmanager.saveText")
        activity.title = "Metni Kaydet"
        activity.userInfo = ["text": text]
        activity.isEligibleForPrediction = true
        
        let attributes = CSSearchableItemAttributeSet(itemContentType: UTType.plainText.identifier)
        attributes.title = "Metni Kaydet"
        attributes.contentDescription = "Metni pano geçmişine kaydet"
        
        activity.contentAttributeSet = attributes
        activity.becomeCurrent()
    }
}

// Clipboard Item Model (Siri için gelecekte kullanılabilir)
public class ClipboardItemModel: NSObject, NSCoding, NSSecureCoding {
    public static var supportsSecureCoding: Bool = true
    
    @objc public var identifier: String?
    @objc public var displayString: String?
    @objc public var title: String?
    
    override public init() {
        super.init()
    }
    
    public required init?(coder: NSCoder) {
        identifier = coder.decodeObject(forKey: "identifier") as? String
        displayString = coder.decodeObject(forKey: "displayString") as? String
        title = coder.decodeObject(forKey: "title") as? String
        super.init()
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(identifier, forKey: "identifier")
        coder.encode(displayString, forKey: "displayString")
        coder.encode(title, forKey: "title")
    }
}
