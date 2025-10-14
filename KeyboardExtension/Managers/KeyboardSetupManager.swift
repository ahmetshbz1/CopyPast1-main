import UIKit
import SwiftUI

class KeyboardSetupManager {
    weak var viewController: KeyboardViewController?
    
    init(viewController: KeyboardViewController) {
        self.viewController = viewController
    }
    
    func setupKeyboardView() {
        guard let viewController = viewController else { return }
        
        let hostingController = UIHostingController(
            rootView: ClipboardView(
                clipboardManager: ClipboardManager.shared,
                onItemSelected: { [weak viewController] text in
                    viewController?.handleItemSelection(text)
                },
                onDismiss: { [weak viewController] in
                    viewController?.advanceToNextInputMode()
                }
            )
        )
        viewController.clipboardView = hostingController
        
        viewController.addChild(hostingController)
        viewController.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: viewController)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])
        
        // Ekranın %50'si kadar yükseklik
        let screenHeight = UIScreen.main.bounds.height
        let keyboardHeight = screenHeight * 0.5
        viewController.view.heightAnchor.constraint(equalToConstant: keyboardHeight).isActive = true
        hostingController.view.transform = CGAffineTransform.identity
    }
    
    func setupTapGesture() {
        guard let viewController = viewController else { return }
        
        let tapGesture = UITapGestureRecognizer(target: viewController, action: #selector(KeyboardViewController.handleTapOutside))
        tapGesture.cancelsTouchesInView = false
        viewController.view.addGestureRecognizer(tapGesture)
    }
    
    func setupDarwinNotifications() {
        guard let viewController = viewController else { return }
        
        viewController.darwinNotificationManager.startObserving(observer: viewController) { [weak viewController] in
            viewController?.clipboardManager.loadItems()
            viewController?.updateKeyboardView()
        }
    }
}