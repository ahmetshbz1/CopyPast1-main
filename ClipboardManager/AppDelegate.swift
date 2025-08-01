import UIKit
import SwiftUI
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    // Modern iOS 18+ BGTaskScheduler identifier
    private let backgroundRefreshTaskIdentifier = "com.clipboardmanager.refresh"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIHostingController(rootView: ContentView())
        window?.makeKeyAndVisible()
        
        // Modern BGTaskScheduler ile arka plan görevlerini kaydet
        registerBackgroundTasks()
        
        return true
    }
    
    // MARK: - Modern Background Task Management (iOS 13+)
    
    private func registerBackgroundTasks() {
        // App refresh task'ı kaydet
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundRefreshTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Arka plan görevini zamanla
        scheduleBackgroundRefresh()
        
        // Clipboard verilerini güncelle
        let clipboardManager = ClipboardManager.shared
        
        Task {
            // Asenkron olarak verileri yükle
            await MainActor.run {
                clipboardManager.loadItems()
            }
            
            // Görev tamamlandı
            task.setTaskCompleted(success: true)
        }
        
        // Timeout handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Arka plana geçtiğinde modern background task zamanla
        scheduleBackgroundRefresh()
    }
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundRefreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 dakika sonra
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Background task scheduling failed: \(error)")
        }
    }
} 