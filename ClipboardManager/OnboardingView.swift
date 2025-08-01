import SwiftUI
import UIKit

struct OnboardingView: View {
    @State private var currentIndex = 0
    @State private var keyboardPermissionGranted = false
    @State private var backgroundRefreshGranted = false
    @StateObject private var permissionManager = OnboardingPermissionManager()
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Arka plan
                AnimatedBackground()
                
                VStack(spacing: 0) {
                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.3), value: currentIndex)
                        }
                    }
                    .padding(.top, 50)
                    
                    // Page content
                    TabView(selection: $currentIndex) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            PageView(
                                page: page,
                                colorScheme: colorScheme
                            ) {
                                if index < pages.count - 1 {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        currentIndex = index + 1
                                    }
                                }
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.5), value: currentIndex)
                }
            }
        }
        .onAppear {
            setupPermissionChecks()
        }
    }
    
    private var pages: [OnboardingPage] {
        [
            OnboardingPage(
                image: "AppLogo",
                title: "CopyPast'a Hoş Geldiniz!",
                description: "Kopyaladığınız her şeyi otomatik olarak saklayan ve istediğiniz zaman erişebileceğiniz akıllı pano yöneticisi.",
                buttonTitle: nil,
                buttonAction: nil,
                secondaryDescription: nil
            ),
            OnboardingPage(
                image: "doc.on.clipboard",
                title: "Otomatik Kaydetme",
                description: "Kopyaladığınız metinler, linkler otomatik olarak kaydediliyor. Artık hiçbir şeyi kaybetmeyeceksiniz!",
                buttonTitle: nil,
                buttonAction: nil,
                secondaryDescription: nil
            ),
            OnboardingPage(
                image: "keyboard",
                title: "Klavye Uzantısı",
                description: "Herhangi bir uygulamada klavye üzerinden kopyaladığınız içeriklere hızlıca erişin.",
                buttonTitle: keyboardPermissionGranted ? nil : "Klavye İzni Ver",
                buttonAction: keyboardPermissionGranted ? nil : permissionManager.openSettings,
                secondaryDescription: keyboardPermissionGranted ? "✅ Klavye erişimi aktif!" : "⚠️ Klavye erişimi gerekli"
            ),
            OnboardingPage(
                image: "arrow.clockwise",
                title: "Arka Plan Yenileme",
                description: "Uygulamanın arka planda çalışarak panodaki değişiklikleri takip etmesi için gerekli.",
                buttonTitle: backgroundRefreshGranted ? nil : "Arka Plan İzni Ver",
                buttonAction: backgroundRefreshGranted ? nil : permissionManager.openBackgroundSettings,
                secondaryDescription: backgroundRefreshGranted ? "✅ Arka plan yenileme aktif!" : "⚠️ Arka plan yenileme önerilir"
            ),
            OnboardingPage(
                image: "checkmark.circle.fill",
                title: "Hazırsınız!",
                description: "Artık CopyPast'ı kullanmaya başlayabilirsiniz. Kopyaladığınız her şey güvenle saklanacak.",
                buttonTitle: "Başlayalım",
                buttonAction: {
                    OnboardingManager.shared.markOnboardingCompleted()
                },
                secondaryDescription: nil
            )
        ]
    }
    
    private func setupPermissionChecks() {
        // İzinleri kontrol et
        permissionManager.checkKeyboardPermissions()
        permissionManager.checkBackgroundRefreshPermissions()
        
        // Binding'leri güncelle
        keyboardPermissionGranted = permissionManager.keyboardPermissionGranted
        backgroundRefreshGranted = permissionManager.backgroundRefreshGranted
        
        // Periyodik kontrol
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            permissionManager.checkKeyboardPermissions()
            permissionManager.checkBackgroundRefreshPermissions()
            
            keyboardPermissionGranted = permissionManager.keyboardPermissionGranted
            backgroundRefreshGranted = permissionManager.backgroundRefreshGranted
        }
    }
}

#Preview {
    OnboardingView()
}