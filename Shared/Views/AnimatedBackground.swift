import SwiftUI

struct AnimatedBackground: View {
    @State private var animateBackground = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: animateBackground ? geometry.size.width * 0.3 : -geometry.size.width * 0.3,
                            y: animateBackground ? geometry.size.height * 0.2 : -geometry.size.height * 0.2)
                    .blur(radius: 60)
                
                Circle()
                    .fill(Color.purple.opacity(0.08))
                    .frame(width: geometry.size.width * 0.8)
                    .offset(x: animateBackground ? -geometry.size.width * 0.2 : geometry.size.width * 0.2,
                            y: animateBackground ? -geometry.size.height * 0.3 : geometry.size.height * 0.3)
                    .blur(radius: 60)
            }
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                    animateBackground.toggle()
                }
            }
        }
        .ignoresSafeArea()
    }
}