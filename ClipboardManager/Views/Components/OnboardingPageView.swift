import SwiftUI
import UIKit

struct OnboardingPage: Identifiable {
    let id = UUID()
    let image: String
    let title: String
    let description: String
    let buttonTitle: String?
    let buttonAction: (() -> Void)?
    let secondaryDescription: String?
}

struct PageView: View {
    let page: OnboardingPage
    let colorScheme: ColorScheme
    let onContinue: () -> Void
    @State private var isAnimating = false
    @State private var showContent = false
    
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            // İkon
            Group {
                if page.image == "AppLogo" {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                        .rotationEffect(.degrees(isAnimating ? 8 : -8))
                } else {
                    Image(systemName: page.image)
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 30)
            
            VStack(spacing: 15) {
                // Başlık
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                
                // Açıklama
                Text(page.description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 20)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                
                // İkinci açıklama (varsa)
                if let secondaryDescription = page.secondaryDescription {
                    Text(secondaryDescription)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .padding(.horizontal, 20)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
            }
            
            Spacer()
            
            // Buton
            if let buttonTitle = page.buttonTitle {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    page.buttonAction?()
                }) {
                    HStack {
                        Text(buttonTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 30)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
            } else {
                Button(action: onContinue) {
                    HStack {
                        Text("Devam Et")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 30)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
            }
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
            
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}