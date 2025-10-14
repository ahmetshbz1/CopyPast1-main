import UIKit

public struct HapticManager {
    
    public enum HapticType {
        case success
        case warning
        case error
        case light
        case medium
        case heavy
        case soft
        case rigid
        case selection
    }
    
    /// Haptic feedback çalıştırır
    public static func trigger(_ type: HapticType) {
        switch type {
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            
        case .soft:
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
            
        case .rigid:
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred()
            
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
    
    /// Birden fazla feedback art arda (combo)
    public static func triggerCombo(_ types: [HapticType], delay: TimeInterval = 0.05) {
        for (index, type) in types.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + (delay * Double(index))) {
                trigger(type)
            }
        }
    }
}
