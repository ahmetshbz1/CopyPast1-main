import Foundation
import UIKit
import Combine

public final class KeyboardObserver: ObservableObject {
    @Published public private(set) var keyboardHeight: CGFloat = 0
    private var cancellables: Set<AnyCancellable> = []
    
    public init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification))
            .sink { [weak self] notification in
                self?.handle(notification: notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                self?.keyboardHeight = 0
            }
            .store(in: &cancellables)
    }
    
    private func handle(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        let height = max(0, UIScreen.main.bounds.height - endFrame.origin.y)
        keyboardHeight = height
    }
}
