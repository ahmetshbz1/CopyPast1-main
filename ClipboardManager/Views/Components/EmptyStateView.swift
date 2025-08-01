import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 70))
                .foregroundColor(.blue.opacity(0.6))
                .padding(.bottom, 10)
                .shadow(color: .blue.opacity(0.1), radius: 10, x: 0, y: 5)
            
            Text("Henüz Kopyalanan Metin Yok")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Herhangi bir metni kopyaladığınızda\notomatik olarak burada listelenecek")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}