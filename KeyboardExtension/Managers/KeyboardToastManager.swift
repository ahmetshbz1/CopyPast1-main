import UIKit
import SwiftUI

class KeyboardToastManager {
    weak var viewController: KeyboardViewController?
    
    init(viewController: KeyboardViewController?) {
        self.viewController = viewController
    }
    
    func showToast(message: String) {
        guard let viewController = viewController else { return }
        
        // Varolan toast'u kaldır
        viewController.toastView?.view.removeFromSuperview()
        viewController.toastView?.removeFromParent()
        
        // Yeni toast oluştur
        let hostingController = UIHostingController(rootView: ToastView(message: message))
        viewController.toastView = hostingController
        
        viewController.addChild(hostingController)
        viewController.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: viewController)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            hostingController.view.topAnchor.constraint(equalTo: viewController.view.topAnchor, constant: 10)
        ])
        
        // Animasyon ile göster
        hostingController.view.alpha = 0
        UIView.animate(withDuration: 0.3) {
            hostingController.view.alpha = 1
        }
        
        // 2 saniye sonra kaldır
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak viewController] in
            UIView.animate(withDuration: 0.3, animations: {
                viewController?.toastView?.view.alpha = 0
            }) { _ in
                viewController?.toastView?.view.removeFromSuperview()
                viewController?.toastView?.removeFromParent()
            }
        }
    }
}