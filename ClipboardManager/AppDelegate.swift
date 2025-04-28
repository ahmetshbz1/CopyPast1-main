import UIKit
import SwiftUI

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIHostingController(rootView: ContentView())
        window?.makeKeyAndVisible()
        
        // Arka plan yenileme özelliğini aktifleştir
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        
        return true
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Arka planda veri güncelleme
        let clipboardManager = ClipboardManager.shared
        clipboardManager.loadItems()
        
        // Yeni veri var olarak işaretle
        completionHandler(.newData)
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Arka plana geçtiğinde yapılacak işlemler
        scheduleBackgroundFetch()
    }
    
    private func scheduleBackgroundFetch() {
        UIApplication.shared.setMinimumBackgroundFetchInterval(900) // 15 dakika (saniye cinsinden)
    }
} 